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

## Layout

| Path | What it is |
| --- | --- |
| `Ordir/App/` | App entry point and home screen (mascot + game list) |
| `Ordir/Mascot/` | `OrdirMascotView` (animated logo), `OrdirThinkingIndicator` + spinner verbs |
| `Ordir/Games/` | `OrdirGame`, the launch games |
| `Ordir/Assets.xcassets` | App icon, `AccentColor`, `Sparkle` (light/dark) |
| `Assets/ordir-logo.svg` | Source logo; `tools/svg_to_swift.py` regenerates the mascot paths from it |

## Status

| Piece | State |
| --- | --- |
| Xcode project, home screen, app icon | Done; first build pending on a Mac |
| Mascot (idle / speaking / thinking) and spinner verbs | Done; first build pending |
| Auth, sessions, turn scripts, rules Q&A | Not started |

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

## Open risks

- **Logo license.** `Assets/ordir-logo.svg` is "Magic Ball" by Ziyad Aljunaidi from Noun Project. The free
  tier is CC BY 3.0 and requires visible attribution; using it as an app icon without credit needs a
  paid Noun Project license. Stock icons also can't be trademarked exclusively.
- **Content rights.** Decision: rulebooks and rules imagery are treated as public. Every rules answer and
  component image must still cite its source (rulebook page or publisher errata).
