# Downloads schema

This folder contains schema artifacts for the downloads feature.

Files:
- `01_tables.sql` — creates `video_cache` and `download_logs` tables
- `02_functions.sql` — intentionally empty since business logic lives in Supabase Edge Functions

Notes:
- `video_cache` stores cached video-info responses for 24 hours.
- `download_logs` stores analytics of successful download attempts.
- Cleanup of expired cache records should be handled with a scheduled task.
