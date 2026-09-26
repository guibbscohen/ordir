# Ordir

iOS companion that walks each player through a board game's turn order, step by step, and answers
rules questions with citations to the official rulebook and errata.

Launch games: Dune: War for Arrakis, Star Wars: Rebellion, War of the Ring (2nd Edition).

## Status

| Piece | State |
| --- | --- |
| `Ordir/Mascot/OrdirMascotView.swift` | Written, not yet compiled. Geometry generated from `Assets/ordir-logo.svg` via `tools/svg_to_swift.py`. |
| `Ordir/Mascot/OrdirThinkingIndicator.swift` | Thinking mascot with rotating board game / nerd-culture spinner verbs (`OrdirSpinnerVerbs.swift`), themed per game. Not yet compiled. |
| Xcode project, auth, sessions, game data, rules Q&A | Not started |

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
