# log-download-attempt

Supabase Edge Function that records a successful offline download attempt for analytics.

## Input

```json
{
  "lesson_id": "uuid",
  "quality": "720p",
  "access_expires_at": "2026-12-01T00:00:00Z"  // or null
}
```

## Output

```json
{ "success": true }
```

## Notes

- This function should be called only after the download has completed successfully.
- `access_expires_at` must be copied from the prior `validate-course-access` response.
- The function writes the record to `download_logs` for analytics, but must not block playback flow.
