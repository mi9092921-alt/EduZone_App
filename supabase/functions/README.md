# Downloads Edge Functions

This folder contains all Supabase Edge Functions for the project (moved from `supabase/downloads/functions/` — the downloads-specific functions now live alongside the rest).

Each function lives in its own subfolder with an `index.ts` entrypoint; several also have a dedicated README describing inputs, outputs, and required behavior.

Functions:
`create-user` — admin-only: create an auth user + matching `public.users` profile row
- `get-lesson-content` — resolve a lesson's signed video/caption URLs after a server-side access check
- `bulk-action` — admin-only: enqueue a bulk operation (see `bulk-worker`)
- `bulk-worker` — background worker that processes queued bulk operations
- `bulk-export` / `export-report` — admin-only: generate data exports/reports

See each function subfolder for contract details, and `supabase/deploy_functions.ps1` to deploy all of them.
