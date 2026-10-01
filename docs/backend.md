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
   `{{ .Token }}`, the 6-digit code; their orb image is served with the preview on GitHub Pages.
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
  - `rules_questions`: each player's questions.
  - `profiles`, `game_tables` and `table_players`: own-phone tables.
  - `peek_table(code)`: before joining, the table's game, expansions and taken sides (signed-in players only).
- `supabase/functions/rules-answer/`: answers a question with Claude Opus 5.5, citing source pages.
  Signed-in players only, 30 questions a day.
- `tools/rules_corpus.py` and `.github/workflows/rules-corpus.yml`: extract the official PDFs page by
  page and load them.
