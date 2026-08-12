# Downloads Edge Functions

This folder contains all Supabase Edge Functions for the downloads feature.

Each function lives in its own subfolder with an `index.ts` entrypoint and a dedicated README describing inputs, outputs, and required behavior.

Functions:
- `validate-course-access` — check user enrollment/access for a lesson or course
- `video-info` — fetch YouTube video metadata and available formats from the Replit-backed video API
- `log-download-attempt` — store analytics after a successful download

See each function subfolder for contract details.
