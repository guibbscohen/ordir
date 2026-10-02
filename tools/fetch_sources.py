#!/usr/bin/env python3
"""Download the official source PDFs every turn script cites, and check them against their SHA-256.

The PDFs are the publishers' files, so they are not stored in this repo. Each turn script lists
them under "sources" (url, file, sha256); this puts them at "file". Run from the repo root before
tools/validate_turn_scripts.py or tools/crop_source_images.py:

    python3 tools/fetch_sources.py

Standard library only. Exits non-zero if a download fails or a file doesn't match its checksum,
which would mean the publisher changed it: re-check the citations before updating the sha256.

With SUPABASE_SOURCES_KEY set (CI has it as a secret), a private copy in the Ordir project's "sources"
storage bucket backs the publishers up: a file their site can't serve comes from the bucket instead
(still checked against its SHA-256), and any verified file the bucket lacks is copied into it. The
bucket is private, so the PDFs are never published.
"""
import hashlib
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


# The private backup of the sources: the Ordir project's "sources" storage bucket (see the docstring).
MIRROR = "https://dhaeqyvdjkhbedqsnqzj.supabase.co/storage/v1/object/sources/"
MIRROR_KEY = os.environ.get("SUPABASE_SOURCES_KEY", "").strip()


def mirror_request(file, method="GET", data=None):
    """A request for one source in the bucket, by its path under Sources/."""
    headers = {"apikey": MIRROR_KEY}
    if not MIRROR_KEY.startswith("sb_"):  # a legacy service_role JWT also goes in Authorization
        headers["Authorization"] = f"Bearer {MIRROR_KEY}"
    if data is not None:
        headers.update({"Content-Type": "application/pdf", "x-upsert": "true"})
    name = urllib.parse.quote(file.removeprefix("Sources/"))
    return urllib.request.Request(MIRROR + name, data=data, headers=headers, method=method)


def from_mirror(file):
    with urllib.request.urlopen(mirror_request(file), timeout=60) as response:
        return response.read()


def to_mirror(file, path):
    """Copies a verified file into the bucket unless it's already there."""
    try:
        urllib.request.urlopen(mirror_request(file, "HEAD"), timeout=30).close()
        return
    except urllib.error.HTTPError as error:
        if error.code not in (400, 404):
            raise
    urllib.request.urlopen(mirror_request(file, "POST", path.read_bytes()), timeout=120).close()
    print(f"saved {file} to the private backup", flush=True)


# Sites that failed every attempt this run: their other files fail at once rather than each waiting it out.
unreachable = set()


def download(url, waits=(5, 15)):
    """The file at url, trying again after each wait: a publisher's site is sometimes briefly unreachable.
    Each attempt gives up after 30 s, so a site that hangs can't run the check past its time limit."""
    host = urllib.parse.urlsplit(url).hostname
    if host in unreachable:
        raise OSError(f"{host} was unreachable earlier in this run")
    # Some publisher sites refuse Python's default user agent.
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Ordir source fetch)"})
    for wait in (*waits, None):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except OSError as error:
            if wait is None:
                unreachable.add(host)
                raise
            print(f"retry {url} in {wait} s ({error})", flush=True)
            time.sleep(wait)


def main():
    failed = False
    for script in sorted((ROOT / "Ordir" / "Games").rglob("*.turnscript.json")):
        for source in json.loads(script.read_text())["sources"]:
            path = ROOT / source["file"]
            if not path.exists() or sha256(path) != source["sha256"]:
                path.parent.mkdir(parents=True, exist_ok=True)
                print(f"fetch {source['url']}", flush=True)
                try:
                    path.write_bytes(download(source["url"]))
                except OSError as error:
                    if not MIRROR_KEY:
                        print(f"FAIL  {source['file']}: {error}")
                        failed = True
                        continue
                    print(f"from the private backup: {source['file']} ({error})", flush=True)
                    try:
                        path.write_bytes(from_mirror(source["file"]))
                    except OSError as mirror_error:
                        print(f"FAIL  {source['file']}: {error}; the backup: {mirror_error}")
                        failed = True
                        continue
            if sha256(path) == source["sha256"]:
                print(f"ok    {source['file']}")
                if MIRROR_KEY:
                    try:
                        to_mirror(source["file"], path)
                    except OSError as error:  # the backup is a convenience; never fail the check over it
                        print(f"note  couldn't save {source['file']} to the private backup: {error}")
            else:
                print(f"FAIL  {source['file']}: checksum differs; the publisher may have changed it")
                failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
