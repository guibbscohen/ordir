# CLAUDE.md

Guidance for Claude Code in this repo. Read this and `.claude/MEMORY.md` at the start of every session and follow both.

## Standing preferences (memory)

@.claude/MEMORY.md

## External skill libraries — always consult

These five repos are cloned into `.claude/external-skills/` on every session start by the
SessionStart hook in `.claude/settings.json` (it runs `scripts/sync-external-skills.sh`):

| Repo | Folder | Use it for |
| --- | --- | --- |
| `anthropics/skills` | `anthropics__skills/skills/` | docx/pdf/pptx/xlsx, MCP servers, frontend design, webapp testing (Playwright), Claude API, skill creation, doc co-authoring, internal comms |
| `vercel-labs/agent-skills` | `vercel-labs__agent-skills/skills/` | React/Next.js best practices, composition patterns, view transitions, React Native, Vercel deploy/optimize, web-design and writing guidelines |
| `nextlevelbuilder/ui-ux-pro-max-skill` | `nextlevelbuilder__ui-ux-pro-max-skill/.claude/skills/` | UI/UX design intelligence, design systems/tokens, UI styling (shadcn/Tailwind), brand, banners, slides |
| `bencium/bencium-marketplace` | `bencium__bencium-marketplace/*/skills/` | UX designers (controlled/impact/innovative), design audit, typography, architecture mindset, adaptive communication, AEO, EU AI Act review, vanity-engineering review |
| `AccessLint/skills` | `AccessLint__skills/plugins/accesslint/skills/` | Accessibility (WCAG 2.2): scan, inspect, audit, fix, diff |

`.claude/external-skills/INDEX.md` lists every skill with its description and SKILL.md path.

### Required workflow on every task

1. **Check the index.** Before starting work, read `.claude/external-skills/INDEX.md` and pick every
   skill whose description matches the task (code, design, docs, deploy, review, writing, a11y, …).
2. **Read the matching SKILL.md files in full** (plus any reference files they point to) and follow
   them. When several apply, combine them; when they conflict, this repo's conventions and
   `.claude/MEMORY.md` win.
3. **State which skills you used** in your reply (one line), or say none applied.
4. **If the folder is missing or stale** (hook failed, fresh clone), run
   `scripts/sync-external-skills.sh` first. Never commit `.claude/external-skills/` — it is gitignored.

Typical matches for Ordir (SwiftUI iOS app, Supabase backend, Claude-powered rules Q&A):
- Any screen, component, or animation → `ui-ux-pro-max` (use `--stack swiftui`), `frontend-design`, `ui-typography`, `bencium-controlled-ux-designer`
- Accessibility (VoiceOver, Dynamic Type, Reduce Motion, contrast) → the AccessLint skills' WCAG checks, applied to native UI
- Architecture, sessions, data model → `human-architect-mindset`, `vanity-engineering-review`
- Rules Q&A, retrieval, prompts → `claude-api`
- In-app copy and step instructions → `writing-guidelines`, `adaptive-communication`
- Multiplayer/relationship features → `relationship-design`

## Recording user instructions

Whenever the user tells me how they want outputs, formatting, workflow, or adjustments done, I
append it to `.claude/MEMORY.md` (dated, one bullet, stated as a rule) in the same turn, commit it
with the rest of the work, and follow it from then on. If a new instruction contradicts an old one,
replace the old bullet rather than keeping both.

## Behavioral guidelines

Guidelines to reduce common LLM coding mistakes. They apply alongside everything above; where they
conflict, the repo-specific sections above and `.claude/MEMORY.md` win.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
