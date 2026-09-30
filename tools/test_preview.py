#!/usr/bin/env python3
"""Play the built browser preview (Preview/dist) in headless Chromium, like the app's UI walkthrough.

Three games, each played into round 2 and then ended from the Game menu:
- one phone on the table, base game, with a two-round battle;
- one phone on the table, every expansion, marking the Smugglers alliance;
- pass the phone, base game.
Fails on any page error, failed request or step that doesn't advance. Run from the repo root after
tools/build_preview.py:

    python3 tools/test_preview.py

Needs Playwright (`pip install playwright`, then `python -m playwright install chromium`, or set
CHROMIUM_PATH to an installed Chromium).
"""
import functools
import http.server
import os
import pathlib
import sys
import threading

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "Preview" / "dist"
LABEL = ".phase-label:not(.mirror)"


class Failed(Exception):
    pass


def check(ok, message):
    if not ok:
        raise Failed(message)


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve():
    handler = functools.partial(QuietHandler, directory=DIST)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def label(page):
    return page.text_content(LABEL).strip()


def tap_if(page, selector):
    """Taps the first visible match, if any."""
    element = page.query_selector(selector)
    if element and element.is_visible():
        element.click()
        return True
    return False


def fight_battle(page):
    page.click("[data-act=battle]")
    combat_taps = 0
    for _ in range(80):
        if tap_if(page, ".done-pane [data-act=leave-battle]"):
            check(page.query_selector("[data-act=end-loop]"), "not back on the Action turn after the battle")
            return
        if tap_if(page, "[data-act=pass]"):
            continue
        end = page.query_selector("[data-act=end-loop]")
        # Six steps per combat round: play two rounds, then end the battle.
        if end and (combat_taps := combat_taps + 1) > 12:
            end.click()
            continue
        page.click("[data-act=done] >> nth=0")
    raise Failed("battle never finished")


def play(page, url, mode="table", expansions=(), fights_battle=False):
    page.goto(url)
    page.wait_for_selector("[data-act=start]")
    if mode == "pass":
        page.click("[data-mode=pass]")
    for expansion in expansions:
        page.click(f"label[for=exp-{expansion}]")
        check(page.is_checked(f"#exp-{expansion}"), f"{expansion} did not switch on")
    page.click("[data-act=start]")

    steps = turns_in_loop = handoffs = 0
    fought = marked = False
    while "Round 2" not in label(page):
        steps += 1
        check(steps < 250, f"never reached round 2 (stuck on {label(page)})")
        if tap_if(page, "[data-act=handoff-ready]"):
            handoffs += 1
            continue
        if tap_if(page, "[data-act=event-done]"):
            continue
        if expansions and not marked and tap_if(page, "[data-mark]"):
            marked = True
            continue
        before = label(page)
        end = page.query_selector("[data-act=end-loop]")
        if fights_battle and not fought and end and page.query_selector("[data-act=battle]"):
            fought = True
            fight_battle(page)
            continue
        if end and turns_in_loop >= 2:
            end.click()
            turns_in_loop = 0
        else:
            if end:
                turns_in_loop += 1
            page.click("[data-act=done] >> nth=0")
        # Action turns stop at the "Before you pass the turn" checklist.
        if end:
            check(tap_if(page, "[data-act=pass]"), f"no turn-change checklist on {before}")
        check(label(page) != before or page.query_selector("[data-act=handoff-ready]"), f"Done did not advance past {before}")

    page.click("[data-act=menu]")
    page.click("[data-winner=atreides]")
    check("Game over" in page.text_content("#phone"), "game did not end")
    if fights_battle:
        check(fought, "never offered to start a battle")
    if expansions:
        check(marked, "never offered to mark the Smugglers alliance")
    if mode == "pass":
        check(handoffs > 5, "pass-the-phone play never asked to pass the phone")
    return steps


def main():
    check_dist = DIST / "index.html"
    if not check_dist.exists():
        sys.exit("Preview/dist is missing, run tools/build_preview.py first.")
    server = serve()
    url = f"http://127.0.0.1:{server.server_address[1]}/index.html"
    games = [
        ("table, base game, with a battle", dict(fights_battle=True)),
        ("table, every expansion", dict(expansions=("desertWar", "smugglers", "spacingGuild"))),
        ("pass the phone, base game", dict(mode="pass")),
    ]
    failed = False
    with sync_playwright() as p:
        # CHROMIUM_PATH points at an installed Chromium when Playwright's own build isn't there.
        browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH") or None)
        for number, (name, options) in enumerate(games, 1):
            page = browser.new_page(viewport={"width": 430, "height": 900})
            problems = []
            page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
            page.on("requestfailed", lambda r: problems.append(f"request failed: {r.url}"))
            page.on("response", lambda r: r.status >= 400 and problems.append(f"HTTP {r.status}: {r.url}"))
            try:
                steps = play(page, url, **options)
                check(not problems, "; ".join(dict.fromkeys(problems)))
                print(f"ok   {name}: {steps} steps into round 2, then Game over")
            except Failed as error:
                failed = True
                page.screenshot(path=str(DIST / f"failure-{number}.png"))
                print(f"FAIL {name}: {error}")
            page.close()
        browser.close()
    server.shutdown()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
