#!/usr/bin/env python3
"""Extract each page of a game's official sources into SQL for the rules_pages table.

The rules-answer Edge Function reads these pages to answer questions and cites them by page. The
text is the publisher's, so it is written to build/ (gitignored), never to the repo. Run from the
repo root after tools/fetch_sources.py:

    python3 tools/rules_corpus.py            # writes build/rules_corpus/<source>.sql
    psql "$SUPABASE_DB_URL" -f build/rules_corpus/rulebook.sql   # or run each file in the SQL editor

Each file replaces that source's pages, so re-running after a new PDF version is safe. The PDFs'
SHA-256 must match the turn script (the same check tools/fetch_sources.py makes).
"""
import hashlib
import json
import pathlib
import re
import sys

from pypdf import PdfReader

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "rules_corpus"


def page_text(page):
    text = page.extract_text() or ""
    # Keep line breaks (they separate headings and list items); drop trailing spaces and blank runs.
    text = "\n".join(line.rstrip() for line in text.splitlines())
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def sql_string(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    scripts = sorted((ROOT / "Ordir" / "Games").rglob("*.turnscript.json"))
    if not scripts:
        sys.exit("No turn scripts found.")
    OUT.mkdir(parents=True, exist_ok=True)
    for path in scripts:
        script = json.loads(path.read_text())
        game = script["game"]
        for source in script["sources"]:
            pdf = ROOT / source["file"]
            if not pdf.exists():
                sys.exit(f"{source['file']} missing, run tools/fetch_sources.py")
            digest = hashlib.sha256(pdf.read_bytes()).hexdigest()
            if digest != source["sha256"]:
                sys.exit(f"{source['file']}: SHA-256 {digest} does not match the turn script")
            pages = [page_text(page) for page in PdfReader(pdf).pages]
            rows = ",\n".join(
                f"  ({sql_string(game)}, {sql_string(source['id'])}, {number}, {sql_string(text)}, {sql_string(digest)})"
                for number, text in enumerate(pages, 1)
                if text
            )
            sql = (
                f"-- {source['title']} ({len(pages)} pages), from {source['url']}\n"
                "begin;\n"
                f"delete from public.rules_pages where game = {sql_string(game)} and source = {sql_string(source['id'])};\n"
                "insert into public.rules_pages (game, source, page, text, source_sha256) values\n"
                f"{rows};\n"
                "commit;\n"
            )
            out = OUT / f"{game}-{source['id']}.sql"
            out.write_text(sql)
            print(f"{out.relative_to(ROOT)}: {len(pages)} pages, {sum(map(len, pages)):,} characters")


if __name__ == "__main__":
    main()
