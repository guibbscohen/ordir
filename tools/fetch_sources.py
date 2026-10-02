#!/usr/bin/env python3
"""Download the official source PDFs every turn script cites, and check them against their SHA-256.

The PDFs are the publishers' files, so they are not stored in this repo. Each turn script lists
them under "sources" (url, file, sha256); this puts them at "file". Run from the repo root before
tools/validate_turn_scripts.py or tools/crop_source_images.py:

    python3 tools/fetch_sources.py

Standard library only. Exits non-zero if a download fails or a file doesn't match its checksum,
which would mean the publisher changed it: re-check the citations before updating the sha256.
"""
import hashlib
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
                    print(f"FAIL  {source['file']}: {error}")
                    failed = True
                    continue
            if sha256(path) == source["sha256"]:
                print(f"ok    {source['file']}")
            else:
                print(f"FAIL  {source['file']}: checksum differs; the publisher may have changed it")
                failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
