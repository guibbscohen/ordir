#!/usr/bin/env python3
"""Play the built browser preview (Preview/dist) in headless Chromium, like the app's UI walkthrough.

Three games, each opened from Home (after the opening animation, Skip, or Enter) and played into
round 2, then ended from the Game menu:
- one phone on the table, base game, with a two-round battle;
- one phone on the table, every expansion, marking the Smugglers alliance;
- pass the phone, base game.
Fails on any page error, failed request or step that doesn't advance. Accessibility is checked on
the way: axe-core (WCAG 2.2 AA and best practices) scans each kind of screen once per game, focus
must land on each new step and dialog, and Escape must close the Game menu. Run from the repo root
after tools/build_preview.py:

    python3 tools/test_preview.py

Needs Playwright and axe (`pip install playwright axe-playwright-python`, then
`python -m playwright install chromium`, or set CHROMIUM_PATH to an installed Chromium).
"""
import functools
import http.server
import os
import pathlib
import sys
import threading

from axe_playwright_python.sync_playwright import Axe
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "Preview" / "dist"
LABEL = ".phase-label:not(.mirror)"
AXE = Axe()
AXE_RULES = {"runOnly": {"type": "tag", "values": ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"]}}


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


class Accessibility:
    """Scans each kind of screen once per game with axe and records every violation."""

    def __init__(self, page, problems):
        self.page, self.problems, self.seen = page, problems, set()

    def scan(self, kind, settle=400):
        if kind in self.seen:
            return
        self.seen.add(kind)
        self.page.wait_for_timeout(settle)  # let the screen's fade-in finish so colours are final
        for violation in AXE.run(self.page, options=AXE_RULES).response["violations"]:
            targets = ", ".join(" ".join(map(str, node["target"])) for node in violation["nodes"][:3])
            self.problems.append(f"a11y on {kind}: {violation['id']} ({violation['help']}) at {targets}")


def focused(page, selector):
    return page.evaluate("(sel) => !!document.activeElement && document.activeElement.matches(sel)", selector)


def tap_if(page, selector):
    """Taps the first visible match, if any."""
    element = page.query_selector(selector)
    if element and element.is_visible():
        element.click()
        return True
    return False


def fight_battle(page, a11y):
    page.click("[data-act=battle]")
    a11y.scan("battle")
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


def play(page, url, problems, mode="table", expansions=(), fights_battle=False, game="dune", script="duneWarForArrakis", marks=False):
    a11y = Accessibility(page, problems)
    page.goto(url)
    page.wait_for_selector(".intro")
    if mode == "pass":
        page.keyboard.press("Enter")  # skip the opening from the keyboard
    elif expansions:
        page.click(".intro .skip")
    else:
        a11y.scan("opening", settle=1250)  # once its text has faded in; then let it play out
    page.wait_for_selector(".intro", state="detached", timeout=8000)
    page.wait_for_selector(f"[data-act=game-{game}]:not([disabled])")
    check(focused(page, ".pane h1"), "focus did not move to Home's heading")
    check(page.query_selector(f".game img[src='img/{script}/cover.jpg']"), f"{game}'s card has no cover art")
    a11y.scan("home")
    if expansions:
        # The orb opens Ask full screen; the glass bar switches tabs and keeps focus on the tab.
        page.click("[data-act=orb-ask]")
        check(focused(page, ".pane h1") and "Ask a rules question" in page.text_content(".pane h1"), "the orb did not open Ask")
        page.click("[data-act=tab-join]")
        check(focused(page, "[data-act=tab-join]") and page.query_selector("[data-act=tab-join][aria-current=page]"), "the Join tab did not open")
        a11y.scan("join tab", settle=1500)
        page.click("[data-act=tab-games]")
    page.click(f"[data-act=game-{game}]")
    page.wait_for_selector("[data-act=start]")
    a11y.scan("setup picker")
    if mode == "pass":
        page.click("[data-act=home]")
        check(page.query_selector(f"[data-act=game-{game}]"), "Games did not go back to Home")
        page.click(f"[data-act=game-{game}]")
    if mode == "pass":
        page.click("[data-mode=pass]")
    for expansion in expansions:
        page.click(f"label[for=exp-{expansion}]")
        check(page.is_checked(f"#exp-{expansion}"), f"{expansion} did not switch on")
    page.click("[data-act=start]")
    check(focused(page, ".title"), "focus did not move to the first step's title")
    if expansions:
        # The step's orb opens a short ask sheet; Escape closes it and returns to the orb.
        page.click(".near [data-act=ask-here], .half [data-act=ask-here] >> nth=0")
        check(focused(page, ".sheet h2"), "the step's orb did not open the ask sheet")
        a11y.scan("ask sheet", settle=1500)
        page.keyboard.press("Escape")
        check(not page.query_selector(".sheet") and focused(page, "[data-act=ask-here]"), "Escape did not close the ask sheet")

    steps = turns_in_loop = handoffs = 0
    fought = marked = False
    while "Round 2" not in label(page):
        steps += 1
        check(steps < 250, f"never reached round 2 (stuck on {label(page)})")
        if page.query_selector("[data-act=handoff-ready]"):
            a11y.scan("handoff")
        if tap_if(page, "[data-act=handoff-ready]"):
            handoffs += 1
            continue
        if tap_if(page, "[data-act=event-done]"):
            continue
        if marks and not marked and tap_if(page, "[data-mark]"):
            marked = True
            continue
        before = label(page)
        a11y.scan("step")
        end = page.query_selector("[data-act=end-loop]")
        if fights_battle and not fought and end and page.query_selector("[data-act=battle]"):
            fought = True
            fight_battle(page, a11y)
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
            check(focused(page, '[role="dialog"] h2'), f"focus did not move to the checklist on {before}")
            a11y.scan("turn-change checklist")
            check(tap_if(page, "[data-act=pass]"), f"no turn-change checklist on {before}")
        check(label(page) != before or page.query_selector("[data-act=handoff-ready]"), f"Done did not advance past {before}")
        check(focused(page, ".title, .handoff h2"), f"focus did not move to the step after {before}")

    page.click("[data-act=menu]")
    check(focused(page, ".menu h2"), "focus did not move to the Game menu")
    a11y.scan("game menu")
    page.keyboard.press("Escape")
    check(not page.query_selector(".menu"), "Escape did not close the Game menu")
    check(focused(page, "[data-act=menu]"), "focus did not return to the Game menu button")
    page.click("[data-act=menu]")
    page.click("[data-winner] >> nth=0")
    check("Game over" in page.text_content("#phone"), "game did not end")
    a11y.scan("game over")
    if fights_battle:
        check(fought, "never offered to start a battle")
    if marks:
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
        ("table, every expansion", dict(expansions=("desertWar", "smugglers", "spacingGuild"), marks=True)),
        ("pass the phone, base game", dict(mode="pass")),
        ("Rebellion: table, Rise of the Empire, with combat", dict(game="starWarsRebellion", script="starWarsRebellion",
                                                                   expansions=("riseOfTheEmpire",), fights_battle=True)),
        ("Rebellion: pass the phone, base game", dict(mode="pass", game="starWarsRebellion", script="starWarsRebellion")),
        ("War of the Ring: table, both expansions, with a battle", dict(game="warOfTheRing2E", script="warOfTheRing2E",
                                                                     expansions=("lordsOfMiddleEarth", "warriorsOfMiddleEarth"), fights_battle=True)),
        ("War of the Ring: pass the phone, base game", dict(mode="pass", game="warOfTheRing2E", script="warOfTheRing2E")),
    ]
    failed = False
    with sync_playwright() as p:
        # CHROMIUM_PATH points at an installed Chromium when Playwright's own build isn't there;
        # CHROMIUM_ARGS adds flags (e.g. --ignore-certificate-errors behind a TLS-inspecting proxy).
        browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH") or None,
                                    args=os.environ.get("CHROMIUM_ARGS", "").split())
        for number, (name, options) in enumerate(games, 1):
            page = browser.new_page(viewport={"width": 430, "height": 900})
            problems = []
            page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
            page.on("requestfailed", lambda r: problems.append(f"request failed: {r.url}"))
            page.on("response", lambda r: r.status >= 400 and problems.append(f"HTTP {r.status}: {r.url}"))
            try:
                steps = play(page, url, problems, **options)
                check(not problems, "; ".join(dict.fromkeys(problems)))
                print(f"ok   {name}: {steps} steps into round 2, then Game over; no accessibility issues")
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
