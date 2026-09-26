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
