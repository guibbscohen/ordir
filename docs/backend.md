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

3. **Show the code in the email.** Supabase → Authentication → Emails → **Magic Link** template.
   Make sure it contains `{{ .Token }}`, for example: `Your Ordir code is {{ .Token }}`.
4. **Let friends sign in.** Supabase's built-in email only reaches members of your Supabase
   organization, a few times an hour.
   - Before inviting others, add a custom SMTP sender under Authentication → Emails → SMTP Settings.
   - A free Resend or Postmark account works.

## Online preview

5. **GitHub Pages.** GitHub → Settings → Pages → Build and deployment → Source: **GitHub Actions**.
   - The **Preview on GitHub Pages** workflow then publishes the preview whenever `main` changes it.
   - The address is `https://guibbscohen.github.io/ordir/`.

## What's where

- `supabase/migrations/`: tables and functions, applied in order.
  - `rules_pages`: source text; only the function reads it.
  - `rules_questions`: each player's questions.
  - `profiles`, `game_tables` and `table_players`: own-phone tables.
- `supabase/functions/rules-answer/`: answers a question with Claude Opus 5.5, citing source pages.
  Signed-in players only, 30 questions a day.
- `tools/rules_corpus.py` and `.github/workflows/rules-corpus.yml`: extract the official PDFs page by
  page and load them.
