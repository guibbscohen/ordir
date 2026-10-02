# Backend setup (Supabase project "Ordir")

The database, the `rules-answer` Edge Function and the table functions are already deployed
(`supabase/`). These one-time steps need your accounts.

## Rules questions

1. **Anthropic API key.** Supabase → Edge Functions → Secrets → add `ANTHROPIC_API_KEY`. The key stays
   in Supabase; the app and the preview never see it.
2. **Load the rulebooks.**
   - GitHub → Settings → Secrets and variables → Actions → New repository secret `SUPABASE_DB_URL`.
   - Value: Supabase → Connect → **Session pooler** connection string, with your database password
     filled in. GitHub's runners can't reach the direct connection, which is IPv6-only.
   - Then Actions → **Rules corpus** → Run workflow. Run it again whenever a source PDF changes.

## Sign-in emails

3. **Show the code in the email.** Supabase → Authentication → Emails → Templates. Both show
   `{{ .Token }}`, the sign-in code (8 digits, set under Email OTP Length); their orb image is served with the preview on GitHub Pages.
   - **Confirm signup** (someone's first code): `docs/email/welcome-code.html`, subject
     `Welcome to Ordir: here's your code`.
   - **Magic Link** (every sign-in after that): `docs/email/sign-in-code.html`, subject
     `Your Ordir code is here!`.
4. **Let friends sign in.** Supabase's built-in email only reaches members of your Supabase
   organization, a few times an hour, so Ordir sends through Resend (domain `ordir.devocto.com`, verified).
   - Resend → API Keys: a key with sending access to that domain.
   - Supabase → Authentication → Emails → SMTP Settings: host `smtp.resend.com`, port `465`, username
     `resend`, password the API key, sender `no-reply@ordir.devocto.com`, name `Ordir`.
   - Authentication → Rate Limits: raise the email limit (e.g. 30 an hour).

## Online preview

5. **GitHub Pages.** GitHub → Settings → Pages → Build and deployment → Source: **GitHub Actions**.
   - The **Preview on GitHub Pages** workflow then publishes the preview whenever `main` changes it.
   - The address is `https://guibbscohen.github.io/ordir/`.

## What's where

- `supabase/migrations/`: tables and functions, applied in order.
  - `rules_pages`: source text; only the function reads it.
  - `rules_questions`: each player's questions. Players read their own rows; the preview groups them into
    one chat per game ("Your chats" on the Ask tab).
  - `profiles`, `game_tables` and `table_players`: own-phone tables.
  - `peek_table(code)`: before joining, the table's game, expansions and taken sides (signed-in players only).
- `supabase/functions/rules-answer/`: answers a question with Claude Opus 5.5, citing source pages.
  Signed-in players only, 30 questions a day. With `followUp: true` it reads the player's last 3 questions
  on that game from the past 6 hours (from `rules_questions`, never from the client) as earlier turns.
  Deployed with JWT verification off: it checks the player's token itself, and `{ keepWarm: true }` needs none.
- Rules cache: each game's base rules stay in Claude's 1-hour prompt cache, shared by every player,
  language and expansion set (the answer language goes after the question, not in the system prompt).
  The `rules-keep-warm` cron job (every 10 minutes) calls `rules-answer` with `{ keepWarm: true }`, which
  re-reads (max_tokens 0) the rules of any game unread for 45 minutes; `claim_rules_cache_warm` lets each
  game through at most once per 45 minutes. All seven games' base rules cost about $1.25 a day to keep warm.
  To pause it: `select cron.unschedule('rules-keep-warm');`.
- `tools/rules_corpus.py` and `.github/workflows/rules-corpus.yml`: extract the official PDFs page by
  page and load them.
