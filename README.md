# Ordir

iOS companion that walks each player through a board game's turn order, step by step, and answers
rules questions with citations to the official rulebook and errata.

Launch games: Dune: War for Arrakis, Star Wars: Rebellion, War of the Ring (2nd Edition).

## Getting started

Requires Xcode 16 or later (the project uses folder-synced groups).

1. Open `Ordir.xcodeproj`.
2. Select the **Ordir** target → Signing & Capabilities → choose your Team. Change the bundle ID
   (`com.guibbscohen.ordir`) if you want a different one.
3. Run on an iPhone simulator or device (iOS 17+).

Any file added under `Ordir/` joins the app target automatically, with no project-file edits.

To ship builds to testers, see [TestFlight via Xcode Cloud](docs/testflight.md). The backend's one-time
setup (API key, rulebook loading, sign-in email, GitHub Pages) is in [Backend setup](docs/backend.md).

## Layout

| Path | What it is |
| --- | --- |
| `Ordir/App/` | App entry point, opening animation and home screen (mascot + games, unfinished ones "Coming soon") |
| `Ordir/Mascot/` | `OrdirMascotView` (animated logo), `OrdirThinkingIndicator` + spinner verbs |
| `Ordir/Games/` | `OrdirGame`, the launch games, and each game's turn script (`<game>.turnscript.json`) |
| `Ordir/TurnGuide/` | `TurnScript` model, `TurnGuideSession` (step state machine), `TurnGuideView` (pass-and-play screen) |
| `Sources/<game>/` | Where `tools/fetch_sources.py` downloads the official rulebook and FAQ PDFs (not stored in the repo) |
| `tools/validate_turn_scripts.py` | Checks every citation's excerpt appears on the cited PDF page, and every picture has its asset (runs in CI) |
| `OrdirTests/` | Unit tests: walks the Dune script for every expansion combination; checks filters, the turn loop, Back, and picture assets |
| `OrdirUITests/` | UI tap-through of the whole guide in the simulator (with all expansions on, screenshots every step before and after scrolling), and Xcode's accessibility audit on each kind of guide screen at default and largest text |
| `.github/workflows/` | `turn-scripts.yml` (Linux, every push: turn-script check and browser preview), `ios-build.yml` (macOS build + unit tests, pull requests), `ios-walkthrough.yml` (UI tests with screenshots, run by hand; its `tests` input picks e.g. `OrdirUITests/AccessibilityAuditTests`) |
| `supabase/` | Database migrations (rules text, questions, own-phone tables) and the `rules-answer` Edge Function |
| `Preview/index.html` | Browser preview of the guide (both play modes, rounds, battles); `tools/build_preview.py` builds it into `Preview/dist/` with the app's turn script and pictures, and `tools/test_preview.py` plays it in Chromium with axe-core and keyboard-focus checks (runs in CI). Online, it adds email-code sign-in, rules questions with cited answers, and own-phone tables; `preview-pages.yml` publishes it to GitHub Pages |
| `tools/crop_source_images.py` | Crops component pictures from the source PDFs into `Assets.xcassets/<game>/` |
| `Ordir/Assets.xcassets` | App icon, `AccentColor`, `Sparkle` (light/dark) |
| `Assets/ordir-logo.svg` | Source logo; `tools/svg_to_swift.py` regenerates the mascot paths from it |

## Status

| Piece | State |
| --- | --- |
| Xcode project, home screen, app icon | Done; first build pending on a Mac |
| Mascot (idle / speaking / thinking) and spinner verbs | Done; first build pending |
| Dune turn guide: setup, then rounds until someone wins, with a battle walkthrough; one phone (split screen or pass the phone) | Done; every step cites a rulebook page or FAQ entry and shows component pictures |
| Dune expansions: Desert War, Smugglers, The Spacing Guild | Done as optional modules picked before the guide starts |
| Accessibility: VoiceOver order and labels, Dynamic Type, focus in checklists; keyboard and screen readers in the preview | Done; audited by Xcode's accessibility audit and axe-core |
| Rules questions (Claude Opus 5.5, page citations) and own-phone tables | Backend and browser preview done; the app is next |
| Sign in with Apple | Waits for the Apple Developer account |

## Proposed architecture

**App:** SwiftUI, iOS 17+ (Observation, `TimelineView`/`Canvas` for the mascot). No third-party UI dependencies.

**Backend: Supabase** (already used across DevOcto), which covers every requirement with one service:

| Need | Supabase feature |
| --- | --- |
| Email, Google, Apple login | Auth (Sign in with Apple is required by App Store rules when Google login is offered) |
| Players joining one table, picking a side | `sessions` + `session_players` tables; join by short code or QR |
| "Harkonnen is on Placing Vehicles · 1:24" | Realtime broadcast + presence; the timer is computed from the step's `started_at` |
| Card, token, board images | Storage |
| Rulebook and errata search | Postgres + pgvector, one row per chunk with `source`, `page`, `errata_id` |

**Guided turns come from authored data, not from the model.** Each game is a versioned script:
phases → steps → which side acts → instructions, component images, and the rulebook page that backs
each step. The session is a server-side state machine over that script; "Done" advances it and
everyone's app updates live. This keeps the step order exact and auditable.

**Rules Q&A uses retrieval with mandatory citations.** A Supabase Edge Function retrieves the relevant
rulebook/errata chunks, sends them to Claude, and returns an answer that must cite page or errata ID.
If nothing relevant is retrieved, it says so instead of guessing. The API key never ships in the app.

## Credits

- Logo: "Magic Ball" by Ziyad Aljunaidi, from [Noun Project](https://thenounproject.com) (CC BY 3.0).
- Dune: War for Arrakis and its expansions are © CMON / Gale Force Nine / Legendary. Ordir cites their
  official rulebooks and FAQ by page and links to the publisher's PDFs; it is not affiliated with them.

## Open risks

- **Logo license.** `Assets/ordir-logo.svg` is "Magic Ball" by Ziyad Aljunaidi from Noun Project. The free
  tier is CC BY 3.0 and requires visible attribution; using it as an app icon without credit needs a
  paid Noun Project license. Stock icons also can't be trademarked exclusively.
- **Content rights.** Decision: rulebooks and rules imagery are treated as public. Every rules answer and
  component image must still cite its source (rulebook page or publisher errata).
