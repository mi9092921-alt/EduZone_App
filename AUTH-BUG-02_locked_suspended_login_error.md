# AUTH-BUG-02 — Restricted Login Showed a Generic Error

**Status:** Fixed. `git diff --check` passes. Flutter analysis and focused tests
were attempted but did not complete in this environment because the Flutter
toolchain hung without producing diagnostics.

## Symptom

When an account was locked, suspended, or banned, login displayed the generic
error instead of routing to the dedicated restricted screen.

## Root cause

`AuthNotifier.login()` previously performed these operations in this order:

```text
signInWithPassword → fetch users row → bind device → check_student_app_access()
```

The `users` profile query is subject to RLS. The self-read policy depends on a
valid active session, so restricted accounts could produce an empty result.
The client interpreted that empty result as a missing profile, signed out, and
surfaced a generic error before `check_student_app_access()` could classify the
account.

## Fix

The login flow now runs in this order:

```text
signInWithPassword → bind device → check_student_app_access() → fetch profile if allowed
```

`check_student_app_access()` is the security-boundary RPC responsible for
classifying restricted accounts. Profile loading occurs only after access is
confirmed. Therefore locked, suspended, and banned accounts can reach their
dedicated screens.

If access is allowed but the profile is genuinely missing, the app now logs the
condition, signs out locally, and reports `errorGeneric` explicitly.

## Files changed

- `lib/features/auth/data/datasources/auth_remote_ds.dart`
  - Login now performs Supabase authentication and telemetry only.
  - The profile query was removed from the authentication method.
- `lib/features/auth/domain/repositories/auth_repository.dart`
- `lib/features/auth/data/repositories/auth_repo_impl.dart`
- `lib/features/auth/domain/usecases/login_user.dart`
  - Login contracts now return `Future<void>`.
- `lib/features/auth/application/providers/auth_provider.dart`
  - Access is checked before fetching the profile.
  - Missing profiles after allowed access are handled explicitly.
- Auth tests were updated for the new contract and login ordering.

## Security rationale

No RLS policy was loosened. Reordering the client flow keeps restricted-account
classification behind the existing security-definer RPC and avoids widening
the `users` self-read policy used elsewhere in the app.

## Remaining risk

The unit tests mock the remote data source and therefore cannot reproduce the
real RLS filtering behavior. A future integration test against an RLS-faithful
database should cover locked, suspended, and banned login flows end to end.
