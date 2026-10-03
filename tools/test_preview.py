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
import base64
import functools
import http.server
import json
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


def play(page, url, problems, mode="table", expansions=(), fights_battle=False, game="dune", script="duneWarForArrakis", marks=False,
         loop_taps=2):
    """Plays into round 2. Inside a looping phase it taps Done `loop_taps` times before ending the loop (games without
    fixed sides have several steps per turn, so they need more to go round the table)."""
    game_button = f"[data-act=game-{game}]:visible"
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
    page.wait_for_selector(f"{game_button}:not([disabled])")
    check(focused(page, ".pane h1"), "focus did not move to Home's heading")
    check(page.query_selector(f":is(.game, .game-row) img[src='img/{script}/cover.jpg']"), f"{game} has no cover art on Home")
    a11y.scan("home")
    if expansions:
        # The orb opens Ask full screen; the glass bar switches tabs and keeps focus on the tab.
        page.click("[data-act=orb-ask]")
        check(focused(page, ".pane h1") and "Ask a rules question" in page.text_content(".pane h1"), "the orb did not open Ask")
        page.click("[data-act=tab-join]")
        check(focused(page, "[data-act=tab-join]") and page.query_selector("[data-act=tab-join][aria-current=page]"), "the Join tab did not open")
        a11y.scan("join tab", settle=1500)
        page.click("[data-act=tab-games]")
    page.click(game_button)
    page.wait_for_selector("[data-act=start]")
    a11y.scan("setup picker")
    if mode == "pass":
        page.click("[data-act=home]")
        check(page.query_selector(game_button), "Games did not go back to Home")
        page.click(game_button)
    if mode == "pass":
        page.click("[data-mode=pass]")
    for expansion in expansions:
        page.click(f"label[for=exp-{expansion}]")
        check(page.is_checked(f"#exp-{expansion}"), f"{expansion} did not switch on")
    page.click("[data-act=start]")
    # What Ordir does (setup, then every turn), with Skip setup; these runs start with setup.
    check(focused(page, ".guide-intro h1") and page.query_selector("[data-act=intro-skip]"), "the guide's intro did not show")
    if not expansions and mode == "table":
        a11y.scan("guide intro")
    page.click("[data-act=intro-setup]")
    check(focused(page, ".title"), "focus did not move to the first step's title")
    if expansions:
        # The step's orb opens a short ask sheet; Escape closes it and returns to the orb.
        page.click(".near [data-act=ask-here], .half [data-act=ask-here] >> nth=0")
        check(focused(page, ".sheet h2"), "the step's orb did not open the ask sheet")
        a11y.scan("ask sheet", settle=1500)
        page.keyboard.press("Escape")
        check(not page.query_selector(".sheet") and focused(page, "[data-act=ask-here]"), "Escape did not close the ask sheet")

    steps = turns_in_loop = handoffs = checklists = 0
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
        if end and turns_in_loop >= loop_taps:
            check(script != "duneWarForArrakis" or "Next: Desert hazards" in end.text_content(),
                  f"leaving the Action turns does not say what comes next: {end.text_content()}")
            end.click()
            turns_in_loop = 0
        else:
            if end:
                turns_in_loop += 1
            page.click("[data-act=done] >> nth=0")
        # Turns stop at the "Before you pass the turn" checklist (on the turn's last step).
        if end and page.query_selector("[data-act=pass]"):
            checklists += 1
            check(focused(page, '[role="dialog"] h2'), f"focus did not move to the checklist on {before}")
            a11y.scan("turn-change checklist")
            check(tap_if(page, "[data-act=pass]"), f"the checklist on {before} did not pass the turn")
        check(label(page) != before or page.query_selector("[data-act=handoff-ready]"), f"Done did not advance past {before}")
        check(focused(page, ".title, .handoff h2"), f"focus did not move to the step after {before}")

    check(checklists > 0, "no turn ever showed the turn-change checklist")
    page.click("[data-act=menu]")
    check(focused(page, ".menu h2"), "focus did not move to the Game menu")
    check(page.query_selector("[data-act=next-phase]") and "Next:" in page.text_content("[data-act=next-phase]"),
          "the Game menu cannot skip to the next phase")
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
        check(marked, "never offered to mark a game state from a step")
    if mode == "pass":
        check(handoffs > 5, "pass-the-phone play never asked to pass the phone")
    return steps


def swipe(page, x0, y0, x1, y1, steps=8):
    """A one-finger swipe, as touch events (needs a touch-enabled page)."""
    cdp = page.context.new_cdp_session(page)
    point = lambda x, y: [{"x": x, "y": y}]
    cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": point(x0, y0)})
    for i in range(1, steps + 1):
        cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": point(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)})
    cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
    cdp.detach()
    page.wait_for_timeout(350)


def tour_gestures_languages(page, url, problems):
    """First visit: the tutorial (buttons, swipes, Escape, replay from Account); swipe-back and browser Back;
    swipe-down closing a picture; no swipe-back in a running guide; switching to Portuguese and Spanish."""
    a11y = Accessibility(page, problems)
    # Offline for this test: a sign-in library still loading can stall the emulated touches.
    page.route("**/cdn.jsdelivr.net/npm/@supabase/**", lambda route: route.abort())
    page.goto(url)
    page.keyboard.press("Enter")
    page.wait_for_selector(".overlay.tour", timeout=6000)
    check(focused(page, ".tour h2"), "focus did not move to the tutorial")
    a11y.scan("tutorial")
    step = lambda: page.text_content(".tour .hint")
    page.click("[data-act=tour-next]")
    check("2 of" in step(), "Next did not turn the tutorial's page")
    swipe(page, 330, 500, 90, 500)
    check("3 of" in step(), "a right-to-left swipe did not turn the page")
    swipe(page, 90, 500, 330, 500)
    check("2 of" in step(), "a left-to-right swipe did not go back a page")
    page.click("[data-act=tour-skip]")
    check(not page.query_selector(".overlay.tour"), "Skip did not close the tutorial")
    page.reload()
    page.keyboard.press("Enter")
    page.wait_for_selector("[data-act=game-dune]:visible:not([disabled])")
    page.wait_for_timeout(1800)
    check(not page.query_selector(".overlay.tour"), "the tutorial came back after it was skipped")
    page.click("[data-act=tab-account]")
    page.click("[data-act=tutorial]")
    check(page.query_selector(".overlay.tour"), "Account did not replay the tutorial")
    page.keyboard.press("Escape")
    check(not page.query_selector(".overlay.tour") and focused(page, "[data-act=tutorial]"), "Escape did not close the tutorial back to its button")

    # Coming back to Home lands where the player left off, not at the top.
    page.click("[data-act=tab-games]")
    # Scroll and redraw in the same moment (as when a game's guide finishes loading): the place must survive.
    page.evaluate("document.querySelector('.home > .scroll').scrollTop = 2000; render()")
    page.wait_for_timeout(100)
    before = page.evaluate("document.querySelector('.home > .scroll').scrollTop")
    page.click("#home-browse [data-act=game-knarr]")
    page.wait_for_selector("[data-act=start]")
    swipe(page, 60, 500, 330, 520)
    page.wait_for_selector("#home-browse")
    after = page.evaluate("document.querySelector('.home > .scroll').scrollTop")
    check(before > 300 and abs(after - before) < 2, f"Home went back to {after}px instead of {before}px")
    check(not page.query_selector(".pane.home.enter"), "coming back to Home replayed its arrival animation")
    check(focused(page, "#home-browse .game-row[data-act=game-knarr]"), "focus did not return to the game that was opened")
    page.wait_for_timeout(400)
    later = page.evaluate("document.querySelector('.home > .scroll').scrollTop")
    check(abs(later - before) < 2, f"Home drifted to {later}px after coming back")
    page.evaluate("document.querySelector('.home > .scroll').scrollTop = 0")

    # Swipe-back and the browser's Back leave a game's setup; a running guide ignores swipe-back.
    page.click("[data-act=tab-games]")
    page.click("[data-act=game-dune]:visible")
    page.wait_for_selector("[data-act=start]")
    swipe(page, 60, 500, 330, 520)
    check(page.query_selector("[data-act=game-dune]:visible"), "swiping right did not go back to Home")
    page.click("[data-act=game-dune]:visible")
    page.wait_for_selector("[data-act=start]")
    page.go_back()
    page.wait_for_selector("[data-act=game-dune]:visible")
    page.click("[data-act=game-dune]:visible")
    page.click("[data-mode=pass]")
    page.click("[data-act=start]")
    # The guide's intro: swiping back returns to the setup picker; Skip setup goes straight to round 1.
    page.wait_for_selector("[data-act=intro-skip]")
    swipe(page, 60, 500, 330, 520)
    page.wait_for_selector("[data-act=start]")
    page.click("[data-act=start]")
    page.click("[data-act=intro-skip]")
    page.wait_for_selector(".title, [data-act=handoff-ready]")
    check("Round 1" in page.text_content("#phone"), "Skip setup did not go straight to round 1")
    tap_if(page, "[data-act=handoff-ready]")  # round 1 may open with the phone passed to its first player
    page.wait_for_selector(".title")
    swipe(page, 60, 500, 330, 520)
    check(page.query_selector(".title"), "swiping right left a running guide")
    page.click("[data-enlarge] >> nth=0")
    page.wait_for_selector(".overlay.enlarged")
    swipe(page, 200, 300, 205, 600)
    check(not page.query_selector(".overlay.enlarged"), "swiping down did not close the picture")
    page.click("[data-act=menu]")
    page.click("[data-act=close]")
    page.click("[data-act=home]")

    # Home's search: typing lists only the matches; clearing brings back the favourites; the sort sticks.
    page.fill("#home-search", "bra")
    check(page.is_hidden("#home-browse"), "typing in the search did not hide the favourites")
    titles = [el.text_content() for el in page.query_selector_all("#home-results .game-row:visible strong")]
    check(titles == ["Brass: Birmingham"], f"searching for 'bra' listed {titles}")
    a11y.scan("home search")
    page.fill("#home-search", "")
    check(page.is_visible("#home-browse") and page.is_hidden("#home-results"), "clearing the search did not bring back Home")
    page.click("[data-act=sort-name]")
    titles = [el.text_content() for el in page.query_selector_all("#home-browse .game-row strong")]
    check(titles == sorted(titles), f"A–Z did not sort the games: {titles}")
    page.click("[data-act=sort-recent]")
    first = page.text_content("#home-browse .game-row strong")
    check(first == "Terraforming Mars", f"Most recently added starts with {first}")

    # Languages: Account switches them, and the choice sticks.
    for lang, account, games in (("pt-BR", "Conta", "Os favoritos do Ordi"), ("es-419", "Cuenta", "Los favoritos de Ordi")):
        page.click("[data-act=tab-account]")
        page.click(f"[data-lang={lang}]")
        page.wait_for_function(f"document.documentElement.lang === '{lang}'")
        check(account in page.text_content(".pane h1"), f"{lang}: Account is not translated")
        a11y.scan(f"account in {lang}")
        page.click("[data-act=tab-games]")
        check(games in page.text_content("#phone"), f"{lang}: Home is not translated")
    page.reload()
    page.keyboard.press("Enter")
    page.wait_for_selector("[data-act=game-dune]:visible:not([disabled])")
    check("Los favoritos de Ordi" in page.text_content("#phone"), "the language choice did not survive a reload")
    page.click("[data-act=tab-account]")
    page.click("[data-lang=en]")


# A stand-in for the backend: a signed-in player, a table that answers create_table and saves moves, and
# Realtime that never connects (the poll keeps quiet). Lets the own-phone screens run without a network.
FAKE_BACKEND = """
online.session = { user: { id: "me", is_anonymous: false, email: "player@example.com" }, access_token: "x" };
online.ready = true;
const row = { id: "t1", code: "ABC234", version: 1, state: {}, expansions: [] };
online.client = {
  rpc: async (name, args) => (name === "create_table" ? { data: { ...row, game: args.game, expansions: args.expansions }, error: null }
    : name === "advance_table" || name === "save_table" ? { data: { ...row, version: ++row.version, state: args.state }, error: null }
    : { data: null, error: { message: name } }),
  channel: () => ({ on() { return this; }, subscribe() { return this; } }),
  removeChannel() {},
  from: () => ({ select() { return this; }, eq() { return this; }, gt() { this.newer = true; return this; },
                 maybeSingle: async function () { return { data: this.newer ? null : { ...row, game: "knarr" } }; },
                 single: async () => ({ data: row }) }),
};
clientPromise = Promise.resolve(online.client);
"""


def own_phone_seats(page, url, problems):
    """Each on our own phone in a game without fixed sides: the lobby offers Player 1 to 4, and the table shows
    the player on turn's step with Done on every phone."""
    a11y = Accessibility(page, problems)
    page.route("**/cdn.jsdelivr.net/npm/@supabase/**", lambda route: route.abort())
    page.goto(url)
    page.keyboard.press("Enter")
    page.wait_for_selector("[data-act=game-knarr]:visible:not([disabled])")
    page.evaluate(FAKE_BACKEND)
    page.click("[data-act=game-knarr]:visible")
    page.click("[data-mode=own]")
    page.click("[data-act=start]")
    page.wait_for_selector("[data-side=seat4]")
    seats = [el.text_content().strip() for el in page.query_selector_all("[data-side]")]
    check(seats == ["Player 1", "Player 2", "Player 3", "Player 4"], f"the lobby offered {seats}")
    a11y.scan("own-phone lobby")
    check(page.locator(".how li").count() == 3, "the lobby does not explain how a table works")
    page.click("[data-side=seat3]")
    page.click("[data-act=table-create]")
    # The waiting room: the code to share and who has sat down, then the guide when the host starts it.
    page.wait_for_selector(".table-code")
    check(page.text_content(".table-code") == "ABC234" and focused(page, ".pane h1"), "the waiting room does not show the table's code")
    rows = [el.text_content() for el in page.query_selector_all(".seat-row")]
    check(len(rows) == 4 and "You" in rows[2] and "Waiting" in rows[0], f"the waiting room's seats read {rows}")
    a11y.scan("waiting room")
    page.click("[data-act=table-go]")
    page.click("[data-act=intro-setup]")
    page.wait_for_selector(".strip")
    check("You’re Player 3" in page.text_content(".strip"), "the table strip does not name the seat")
    check(page.query_selector("[data-act=done]"), "an own phone at a game without sides has no Done")
    # The phone restarts: Home offers the table again, and rejoining puts this player back on their seat.
    saved = page.evaluate("JSON.parse(localStorage.getItem('ordir-table'))")
    check(saved and saved["code"] == "ABC234" and saved["side"] == "seat3", f"the table was not remembered: {saved}")
    page.evaluate("leaveTable(); state.session = null; state.screen = 'home'; state.tab = 'games'; render()")  # as after a restart
    page.wait_for_selector("[data-act=table-rejoin]")
    a11y.scan("rejoin card")
    page.click("[data-act=table-rejoin]")
    page.wait_for_selector(".strip")
    check("You’re Player 3" in page.text_content(".strip"), "rejoining did not seat the player again")
    seats5 = page.evaluate("seatsOf(scripts.terraformingMars).map((x) => x.name)")
    check(seats5 == ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5"], f"Terraforming Mars seats {seats5}")
    a11y.scan("own-phone step")


def setup_scroll_and_invite(page, url, problems):
    """On a phone: picking a play mode brings the expansions up the screen, ticking an expansion never shifts the whole
    screen (Android Chrome scrolled the app frame to a hidden checkbox and left it stuck), and a table invite link
    opens Join a table with its code filled in."""
    page.goto(url)
    page.keyboard.press("Enter")
    page.locator("[data-act=game-dune]:visible").first.tap()
    page.wait_for_selector("[data-mode=own]")
    page.tap("[data-mode=pass]")
    page.wait_for_timeout(700)
    # Picking a play mode brings the expansions (the next question) up the screen, focus staying on the mode.
    heading, at_end = page.evaluate("(() => { const p = document.querySelector('.pane > .scroll'), r = document.querySelector('#expansions-title').getBoundingClientRect();"
                                    " return [r.top - p.getBoundingClientRect().top, p.scrollTop + p.clientHeight >= p.scrollHeight - 2]; })()")
    check(0 <= heading < 40 or (at_end and 0 <= heading < 200), f"the expansions heading sits {heading}px down after picking a mode")
    check(focused(page, "[data-mode=pass]"), "focus left the play mode")
    page.tap("label[for=exp-smugglers]")
    page.wait_for_timeout(200)
    frame = page.evaluate("document.querySelector('#phone').scrollTop")
    check(frame == 0 and page.is_checked("#exp-smugglers"), f"ticking an expansion shifted the screen by {frame}")
    page.goto(url + "?table=abc234")
    page.keyboard.press("Enter")
    page.wait_for_selector("[data-act=tab-join][aria-current=page], [data-act=tab-join][aria-selected=true]")
    page.wait_for_timeout(300)
    check("?table" not in page.url, "the invite code stayed in the address")


def tester_feedback(page, url, problems):
    """With tracking on (as on the hosted preview): a game's milestones, the rating, a rules-free bug report with a
    screenshot and the usage switch, checked against what Ordir sends to the backend (intercepted here)."""
    sent = {"events": [], "bug_reports": []}
    def capture(route):
        table = route.request.url.split("/rest/v1/")[1].split("?")[0]
        sent[table].extend(json.loads(route.request.post_data))
        route.fulfill(status=201, body="")
    page.add_init_script("window.ORDIR_TRACK = true")
    page.route("**/rest/v1/events", capture)
    page.route("**/rest/v1/bug_reports", capture)
    play(page, url, problems, mode="pass", game="knarr", script="knarr", loop_taps=15)
    a11y = Accessibility(page, problems)
    # Game over: four stars and a comment.
    page.click("[data-rate='4']")
    check(page.get_attribute("[data-rate='4']", "aria-pressed") == "true" and focused(page, "[data-rate='4']"), "the rating did not take")
    page.fill("#rate-text", "Clear steps")
    page.click("[data-act=rate-send]")
    check("Thanks for rating" in page.text_content("#phone"), "the rating was not acknowledged")
    page.evaluate("flushEvents()")
    names = [e["name"] for e in sent["events"]]
    for name in ("session_start", "opening", "screen_view", "game_open", "guide_start", "setup_done", "round_reached", "game_over", "rating"):
        check(name in names, f"no {name} event was sent (sent: {sorted(set(names))})")
    rating = next(e for e in sent["events"] if e["name"] == "rating")
    check(rating["props"] == {"game": "knarr", "stars": 4, "comment": "Clear steps", "mode": "pass", "rounds": 2}, f"the rating sent {rating['props']}")
    check(len({e["device_id"] for e in sent["events"]}) == 1 and len({e["session_id"] for e in sent["events"]}) == 1, "events did not share one device and session")
    # Account: report a problem, with a screenshot.
    page.click("[data-act=close]")
    page.click("[data-act=home]")
    page.click("[data-act=tab-account]")
    page.click("[data-act=report-open]")
    check(focused(page, "#report-title"), "focus did not move to the report form")
    a11y.scan("report form")
    page.click("[data-act=report-send]")
    check("Describe what happened first" in page.text_content(".report"), "an empty report was not stopped")
    page.fill("#report-text", "The opening flickered")
    shot = DIST / "test-shot.png"
    shot.write_bytes(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="))
    page.set_input_files("#report-shot", str(shot))
    page.wait_for_selector(".shot img")
    page.click("[data-act=report-send]")
    page.wait_for_selector("text=Your report reached the Ordir team")
    a11y.scan("report sent")
    report = sent["bug_reports"][0]
    check(report["description"] == "The opening flickered" and report["screenshot"].startswith("data:image/jpeg;base64,"), "the report lost its text or screenshot")
    check(report["context"]["view"] == "home-account" and report["context"]["recent"], f"the report's context is incomplete: {report['context']}")
    page.click(".report [data-act=report-close] >> nth=0")
    check(focused(page, "[data-act=report-open]"), "focus did not return to Report a problem")
    # Ordir Pro, coming soon: the card opens Free next to the cooler Ordi, nothing is for sale, Escape closes it.
    check("Free plan · 5 rules questions a month" in page.text_content(".pro-card"), "the Account card lost its free-plan line")
    page.click("[data-act=pro-open]")
    check(focused(page, "#pro-title"), "focus did not move to the Ordir Pro screen")
    check(page.locator(".pro .mascot.cool .visor").count() == 1, "the cooler Ordi has no shades")
    check(page.locator(".pro .plan .soon").count() == 3 and page.is_disabled(".pro-foot .primary"), "the plans are not all marked Coming soon")
    a11y.scan("Ordir Pro")
    page.keyboard.press("Escape")
    check(page.locator(".overlay.pro").count() == 0 and focused(page, "[data-act=pro-open]"), "Escape did not close Ordir Pro back to its card")
    with page.expect_request("**/rest/v1/events"):
        page.evaluate("flushEvents()")
    page.wait_for_timeout(200)
    check(any(e["name"] == "pro_open" and e["props"].get("from") == "account" for e in sent["events"]), "no pro_open event was sent")
    # Switching usage data off stops the events.
    page.click("label[for=share-usage]")
    before = len(sent["events"])
    page.click("[data-act=tab-games]")
    page.evaluate("flushEvents()")
    check(len(sent["events"]) == before, "events were still sent with usage data off")


def stale_copy_updates(page, url, problems):
    """A Home Screen app that opens an older cached copy finds the live build at launch and reloads into it, once."""
    live = (DIST / "index.html").read_text()
    loads = []
    def first_load_is_old(route):
        loads.append(route.request.url)
        if len(loads) == 1:  # the cached copy: the build before
            route.fulfill(status=200, content_type="text/html", body=live.replace('const BUILD = "', 'const BUILD = "old ', 1))
        else:
            route.continue_()
    page.route(url, first_load_is_old)
    navigations = []
    page.on("framenavigated", lambda frame: frame == page.main_frame and navigations.append(frame.url))
    page.goto(url)
    page.wait_for_function("() => performance.getEntriesByType('navigation')[0].type === 'reload'", timeout=5000)
    page.wait_for_timeout(800)  # the reloaded page checks again, finds the same build and stays
    check(page.evaluate("BUILD").split(" ")[0] != "old", "the page did not reload into the live build")
    check(len(navigations) == 2, f"expected the old copy and one reload, got {len(navigations)} page loads")


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
        ("Knarr: pass the phone round the table", dict(mode="pass", game="knarr", script="knarr", loop_taps=15)),
        ("Brass: table, marking the end of the Canal Era", dict(game="brassBirmingham", script="brassBirmingham", marks=True, loop_taps=6)),
        ("Dune: Imperium: table, every expansion", dict(game="duneImperium", script="duneImperium", loop_taps=4,
                                                        expansions=("riseOfIx", "immortality", "bloodlines"))),
        ("Dune: Imperium: pass the phone, base game", dict(mode="pass", game="duneImperium", script="duneImperium", loop_taps=6)),
        ("Terraforming Mars: pass the phone, base game", dict(mode="pass", game="terraformingMars", script="terraformingMars", loop_taps=5)),
        ("Terraforming Mars: table, every expansion and a map", dict(game="terraformingMars", script="terraformingMars", loop_taps=3,
                                                                    expansions=("prelude", "venusNext", "colonies", "turmoil", "hellasElysium"))),
    ]
    failed = False
    with sync_playwright() as p:
        # CHROMIUM_PATH points at an installed Chromium when Playwright's own build isn't there;
        # CHROMIUM_ARGS adds flags (e.g. --ignore-certificate-errors behind a TLS-inspecting proxy).
        browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH") or None,
                                    args=os.environ.get("CHROMIUM_ARGS", "").split())
        for number, (name, options) in enumerate(games, 1):
            page = browser.new_page(viewport={"width": 430, "height": 900})
            page.add_init_script("try { localStorage.setItem('ordir-tour-done', '1') } catch {}")  # tour_gestures_languages covers the tour
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
        # A phone with a touch screen, on its first visit.
        context = browser.new_context(viewport={"width": 390, "height": 844}, has_touch=True, is_mobile=True)
        page = context.new_page()
        problems = []
        page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
        page.on("response", lambda r: r.status >= 400 and problems.append(f"HTTP {r.status}: {r.url}"))
        try:
            tour_gestures_languages(page, url, problems)
            check(not problems, "; ".join(dict.fromkeys(problems)))
            print("ok   tutorial, gestures and languages; no accessibility issues")
        except Failed as error:
            failed = True
            page.screenshot(path=str(DIST / "failure-tour.png"))
            print(f"FAIL tutorial, gestures and languages: {error}")
        context.close()
        page = browser.new_page(viewport={"width": 430, "height": 900})
        page.add_init_script("try { localStorage.setItem('ordir-tour-done', '1') } catch {}")
        problems = []
        page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
        try:
            tester_feedback(page, url, problems)
            check(not problems, "; ".join(dict.fromkeys(problems)))
            print("ok   tester feedback: milestones, rating, bug report with a screenshot, Ordir Pro, usage switch; no accessibility issues")
        except Failed as error:
            failed = True
            page.screenshot(path=str(DIST / "failure-feedback.png"))
            print(f"FAIL tester feedback: {error}")
        page.close()
        page = browser.new_page(viewport={"width": 430, "height": 900})
        problems = []
        page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
        try:
            stale_copy_updates(page, url, problems)
            check(not problems, "; ".join(dict.fromkeys(problems)))
            print("ok   an older cached copy reloads into the live build, once")
        except Failed as error:
            failed = True
            print(f"FAIL an older cached copy reloads into the live build: {error}")
        page.close()
        page = browser.new_page(viewport={"width": 430, "height": 900})
        page.add_init_script("try { localStorage.setItem('ordir-tour-done', '1') } catch {}")
        problems = []
        page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
        try:
            own_phone_seats(page, url, problems)
            check(not problems, "; ".join(dict.fromkeys(problems)))
            print("ok   own phones at a game without sides: Player 1 to 4; no accessibility issues")
        except Failed as error:
            failed = True
            page.screenshot(path=str(DIST / "failure-own.png"))
            print(f"FAIL own phones at a game without sides: {error}")
        page.close()
        context = browser.new_context(viewport={"width": 360, "height": 740}, has_touch=True, is_mobile=True)
        page = context.new_page()
        page.add_init_script("try { localStorage.setItem('ordir-tour-done', '1') } catch {}")
        problems = []
        page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
        try:
            setup_scroll_and_invite(page, url, problems)
            check(not problems, "; ".join(dict.fromkeys(problems)))
            print("ok   picking a mode brings up the expansions, which never shift the screen; invite links open Join a table")
        except Failed as error:
            failed = True
            page.screenshot(path=str(DIST / "failure-setup.png"))
            print(f"FAIL setup scroll and invites: {error}")
        context.close()
        browser.close()
    server.shutdown()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
