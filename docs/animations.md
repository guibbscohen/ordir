# Ordir animations

Every moment that moves, in the app and the browser preview: what plays, what Reduce Motion shows
instead, which engine draws it, and whether it exists yet.

## Principles

- **Motion explains state.** It shows where something came from, what changed or who acts next. No
  motion for decoration alone.
- **Timing:**
  - UI transitions take 200–400 ms.
  - Exits run at about 70% of their entrance.
  - Springs for anything the player touches. Nothing blocks input.
- **Reduce Motion:** always a fade (≤ 200 ms), a static frame, or Lottie's "reduced motion" marker.
  Never a slide, zoom or bounce.
- **The orb is Ordir's voice.** It has a face (two dot eyes, a one-line smile), idles, thinks, speaks and reacts. The orb itself stays procedural
  (`OrdirMascotView` Canvas; CSS in the preview), so it can change mode mid-animation.
- **Engines:**
  - SwiftUI and CSS for layout motion: transitions, presses, sheets, tabs.
  - **Lottie** for illustrated one-off moments (files designed in After Effects, exported as
    `.lottie`):
    - App: `LottieView`, installed via the small `lottie-spm` package.
    - Preview: lottie-web.
  - Lottie honours the system Reduce Motion setting by default by playing a marker named
    "reduced motion" (`ReducedMotionOption.systemReducedMotionToggle`).
- **Haptics (app only):** they go with motion, not instead of it.
  - Done: light impact.
  - Pass the turn: medium impact.
  - Checklist tick: selection.
  - Game over: success notification.

## Rundown

Status key:
- **Built** is in the app and the preview.
- **Partial** exists but is missing what the row describes.
- **New** doesn't exist yet.

### Opening

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| App launch | From iOS's black launch screen, the opening fades in from black (0.35 s), so no half-drawn frame flashes. The logo rests for 1.5 s first. On black, the orb (88 pt, with its face) comes out of a blur, sparkles popping; "Ordir" and the tagline rise, then the small "App by DevOcto" credit (logo on its left, 60% opacity); a deep blue and violet glow sits below. A glowing line draws itself from the orb down the screen. Inspired by Ripplix's "Happier" splash. | Orb and name, short fade, Home after 0.9 s | SwiftUI / CSS | Built |
| Opening → Home | One continuous camera move: the view glides down through the glow to Home, waiting one screen below; the line ends at Home's orb, which lights up. No cut or fade. | Crossfade | SwiftUI (Home slides with the same clock) / CSS (Web Animations) | Built |
| Arriving on Home | One gesture: the line drops into Home's orb from above (clear of "Ordir"), runs round its rim, the orb fills in under it, the sparkles pop and the face appears, then the line fades. "Ask me a rules question" is conjured under "Ordir" (blur to sharp) and a board-game quip (a new one each launch; tap the bubble for another) pops up in a speech bubble. Everything after the line arrives finishes within ~0.6 s. | Shown as is | SwiftUI (`OrdirMascotView(buildStart:)`) / CSS | Built (the app's Ask link comes with sign-in) |
| Richer opening (optional) | "Orb awakening": sparkles swirl in from the edges and ignite the orb with a soft glow pulse | Marker: orb already lit | Lottie | New (needs art) |

### Home

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| Tab switch (glass bar) | The selection pill slides to the new tab (spring); the icon gives a small bounce; the page crossfades in 150 ms | Instant pill, crossfade | SwiftUI / CSS | Built (preview) |
| Scrolling Home | The glass bar shrinks to a compact pill while scrolling down and comes back on scroll up, like Apple Music | Stays full size | SwiftUI / CSS | New |
| Game card press | Scales to 0.97 with a highlight, then springs back | Highlight only | SwiftUI / CSS | Built |
| Open a game | Cover art zooms into the setup screen's header | Crossfade | iOS 18 zoom transition / CSS view transition | New |
| Coming-soon tile tap | Gentle shake and an "On the way" toast | Toast only | SwiftUI / CSS | New |
| Orb, idle | Sparkles twinkle; the face blinks every ~4.6 s | Static | Canvas / CSS | Built |
| Orb tap → Ask | The orb pulses, then Ask grows out from it | Crossfade | SwiftUI / CSS | New |
| Tutorial (first launch, or from Account / Settings) | Opens over Home once the orb is built; each card slides in from the side it came from (Next from the right, Back from the left); a swipe turns the page; the dots follow | Fade between cards | SwiftUI (page TabView) / CSS | Built |
| Ordir Pro (Account / Settings card, or "See Ordir Pro" in the rules chat) | The Pro screen rises over the page like the other panels: plain Ordi next to the cooler Ordi in its glow-violet visor (sparkles twinkle, as on Home), the Free / Pro table and the plans, each marked Coming soon. Swipe down, Back or Escape closes it | Fade | SwiftUI sheet / CSS | Built |
| Swipe back (left to right) | Goes back like the Back button (setup to Home; closes the chat, a sheet, the menu, a picture or the checklist); the browser's Back does the same. Not in a running guide. Back on Home, the page is simply there again where it was (no arrival animation), focus on the game that was opened | Same, no motion added | System (navigation) / touch events | Built |
| Swipe down on a panel | The chat, a sheet, the Game menu, a picture or the checklist follows the finger down; past ~100 pt it closes, otherwise it springs back | No spring, snaps back | System sheets / SwiftUI drag (checklist) / CSS transform | Built |
| Home search and sort | Typing filters at once: the favourites and the full list give way to the matching games, with no motion; A–Z / Most recently added swaps the list order in place. Game rows shrink a little under the finger like the cards | Same, no press scale | SwiftUI / CSS | Built |

### Setup

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| Play mode pick | Radio dot scales in; the card border glows briefly | Instant | SwiftUI / CSS | Partial (instant) |
| Expansion switch | Thumb slides, track tints | Instant | System / CSS | Built |
| Start guide | Setup slides away; the first step rises in; the orb starts speaking | Fades | SwiftUI / CSS | Partial (rise only) |

### Turn guide

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| New step | Card rises 16 pt and fades in; the orb "speaks" for the length of the instruction | Fade | SwiftUI / CSS | Built |
| Leaving a step | The old card fades and lifts out before the new one rises (no hard cut) | Crossfade | SwiftUI / CSS | Built |
| Previous step | Card enters from above (the reverse direction), so going back feels different | Crossfade | SwiftUI / CSS | Built |
| Done press | Press scale, plus haptic | Haptic only | SwiftUI / CSS | Built (app haptic) |
| Turn-change checklist | Sheet rises; each tick draws its checkmark; when all are ticked, "Pass the turn" glows once | Instant ticks | SwiftUI / CSS (stroke) | Built |
| Pass the turn (split screen) | A spotlight sweeps from this half to the other; the waiting half's orb wakes and speaks | Fade | SwiftUI / CSS | New |
| Pass the phone (handoff) | A phone slides across a table toward the next player's side colour | Marker: still frame | Lottie | New (needs art) |
| Waiting | Orb "thinking"; the timer ticks | Static orb | Canvas / CSS | Built |
| Phase change (bar) | Phase name rolls up like a counter; progress dots fill | Instant | SwiftUI / CSS | Built (name roll) |
| New round | Short "Round 2" banner with a sparkle burst from the orb | Banner fades | Lottie | New (needs art) |
| Swap seats | The two halves trade places with a quick flip | Crossfade | SwiftUI / CSS | New (instant) |
| Picture tap | Thumbnail zooms to full size (shared element) and back | Crossfade | SwiftUI / CSS | Partial (overlay rise) |
| Mid-game event (e.g. Smugglers allied) | Event card pops in with a sparkle ring | Fade | SwiftUI / CSS | Partial (rise) |
| Start a battle | The bar tints and a pair of combat dice tumble in | Marker: dice at rest | Lottie | New (needs art) |
| Battle over → back to the turn | The battle view folds away to the Action turn | Fade | SwiftUI / CSS | Partial (instant) |
| Game over | Victory burst in the winner's colour (Atreides green, Harkonnen red); the orb glows | Marker: final frame | Lottie (colour via value provider) | New (needs art) |

### Own phones (tables)

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| Table created | The code's characters flip in one by one; "Copied" check on tap | Instant | SwiftUI / CSS | New |
| Waiting for the other player | Orb thinking; a seat dot pulses until they join | Static | Canvas / CSS | Partial (thinking orb) |
| The other phone moved | New step rises in; the table strip pulses once to show who moved | Fade | SwiftUI / CSS | Partial (rise) |
| Connection status | Live dot breathes; turns amber when offline | Static colour | SwiftUI / CSS | New |

### Rules questions

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| Ask sheet in a game | Slides up over that player's side with a spring; the backdrop dims | Fade | SwiftUI / CSS | Built (preview) |
| Game search | The list of games (cover and name) drops open under the search bar; typing filters it | Instant | SwiftUI / CSS | Built (preview) |
| Chat takes over | After asking, the game's chat rises over the whole screen; the question shows as a bubble at once | Fade | SwiftUI / CSS | Built (preview) |
| Checking the rules | Orb "thinking": eyes glance up, mouth goes flat | Static | Canvas / CSS | Built |
| Answer arrives | Orb switches to "speaking"; the answer rises; page chips stagger in (40 ms apart) | Fade | SwiftUI / CSS | Built (preview) |
| Error | Field shakes once; message fades in | Message only | SwiftUI / CSS | New |

### Sign-in

| Moment | Animation | Reduce Motion | Engine | Status |
| --- | --- | --- | --- | --- |
| Code sent | The email field slides away and the code field slides in | Crossfade | SwiftUI / CSS | New (instant) |
| Typing the code | Each digit box pops as it fills | Instant | SwiftUI / CSS | New |
| Signed in | Orb flashes a sparkle check | Static check | Lottie | New (needs art) |
| Wrong code | Code boxes shake | Message only | SwiftUI / CSS | New |

## Lottie files to commission

Each file must meet these specs:
- `.lottie`, under 60 KB.
- Drawn on true black.
- Has a "reduced motion" marker.
- Its colour layers are named so the app can tint them (orb white, sparkle blue `#9EC7FF`, faction colours).

1. `orb-awakening`: optional opening, ~1.2 s.
2. `pass-the-phone`: handoff loop, ~2 s.
3. `round-start`: sparkle burst, ~0.8 s.
4. `battle-dice`: two dice tumble and settle, ~1 s.
5. `victory`: burst tinted to the winner, ~1.5 s.
6. `signed-in`: sparkle check, ~0.6 s.

## Suggested order

1. **No new art needed:**
   - Tab pill slide, card press, step exit and back direction.
   - Checkmark draw, phase label roll, sheet spring.
   - Answer stagger and the speaking orb on answers.
   - Haptics.
2. **Shared-element moves:** opening → Home orb, card → setup zoom, picture zoom.
3. **Lottie set:** once the six files above exist. Add Lottie (`lottie-spm`) to the app at that point,
   not before.
