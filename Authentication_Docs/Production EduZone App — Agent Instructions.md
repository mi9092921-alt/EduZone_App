# Production EduZone App — Engineering Instructions

## 1. Mission

Your mission is to transform the existing `EduZone_App` repository into a genuinely production-ready mobile application suitable for a controlled public release.

Repository:

`https://github.com/mi9092921-alt/EduZone_App.git`

The target is NOT merely "a Flutter app that builds".

The target is a release-grade product with:

- stable architecture
- high reliability
- strong security
- predictable state management
- robust networking and backend integration
- resilient offline behavior
- production-grade error handling
- accessibility
- localization
- acceptable performance
- comprehensive automated testing
- trustworthy CI/CD
- reproducible Android builds
- reproducible iOS builds
- production observability
- safe release and rollback procedures

Treat the repository as an existing software product under hardening, not as a greenfield project.

---

# 2. Core Operating Principle

Before changing code, understand the existing system.

NEVER blindly rewrite an existing subsystem simply because a different implementation looks cleaner.

Preserve correct existing behavior unless there is a concrete production reason to change it.

Every significant change must answer:

1. What is currently wrong?
2. What is the production impact?
3. What is the smallest safe architectural change?
4. How will the change be tested?
5. How will regression be prevented?

Prefer incremental hardening over large uncontrolled rewrites.

---

# 3. Repository Reality

The repository already contains a structured Flutter application with, among other components:

- `lib/app`
- `lib/core`
- `lib/design_system`
- `lib/features`
- `lib/shared`
- `lib/main.dart`

The project currently uses technologies including:

- Flutter
- Dart
- Riverpod
- Riverpod code generation
- GoRouter
- Freezed
- JSON serialization
- Supabase
- Firebase Messaging
- Sentry
- secure storage
- SQLite
- Dio / HTTP
- media playback
- WebView
- device integrity/security tooling
- screen protection
- background downloads
- encryption-related packages

The repository also already contains GitHub Actions workflows including:

- `.github/workflows/ci.yml`
- `.github/workflows/deploy.yml`
- `.github/workflows/update-goldens.yml`

Do NOT assume these are production-correct merely because they exist.

Inspect them and validate their actual behavior.

---

# 4. Zero-Assumption Rule

Never assume:

- a feature works because its code exists
- a test is useful because the test file exists
- CI is correct because a workflow exists
- security is sufficient because a security package is installed
- authentication is secure because Supabase Auth is used
- encryption is secure because AES/encryption libraries are present
- RLS is correctly configured because Supabase is used
- iOS is ready because an `ios/` directory exists
- Android is release-ready because `android/` builds
- a dependency is necessary because it is declared
- an architecture is correct because it is documented in README
- documentation matches implementation
- an implementation is production-safe without evidence

Verify everything.

---

# 5. Mandatory First Phase — Repository Audit

Before making substantial modifications, perform a complete production audit.

Inspect at minimum:

- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `lib/`
- `test/`
- `integration_test/`
- `android/`
- `ios/`
- `assets/`
- `.github/`
- environment configuration
- Supabase-related configuration
- localization
- security-sensitive files
- build/signing configuration
- release configuration
- existing documentation

Also inspect:

- generated files
- code generation setup
- dependency graph
- providers
- repositories
- services
- navigation
- authentication flow
- startup/bootstrap flow
- error handling
- networking
- caching
- persistence
- background tasks
- video/download subsystems
- security controls
- notification subsystem

Produce an internal audit model before beginning major implementation.

---

# 6. Architecture Rules

The application must maintain a clear separation of responsibilities.

Target architectural boundaries:

- presentation
- application/state management
- domain/business logic where appropriate
- data/repositories
- infrastructure/core services

Feature modules must remain isolated.

Do NOT introduce random cross-feature imports.

Do NOT move business logic into widgets.

Do NOT put database/network/storage code directly inside UI screens.

Do NOT make global singletons the default solution.

Use dependency injection and Riverpod appropriately.

Keep:

- UI state
- domain state
- remote state
- persistence
- side effects

conceptually separated.

Avoid unnecessary abstraction.

Do not create interfaces, wrappers, repositories, services, or factories solely for architectural appearance.

---

# 7. State Management Rules

Riverpod is the primary state management mechanism.

Every provider must have:

- a clearly defined responsibility
- predictable lifecycle
- explicit loading state
- explicit error state where appropriate
- correct invalidation strategy
- safe disposal behavior
- no hidden global mutable state

Avoid:

- provider misuse
- unnecessary rebuilds
- circular dependencies
- state duplication
- manually synchronized state
- side effects inside build methods
- network calls triggered accidentally by widget rebuilds

Audit provider families, autoDispose behavior, caching, refresh behavior, and race conditions.

---

# 8. Authentication and Authorization

Authentication must be treated as security-critical infrastructure.

Verify:

- login
- logout
- session restoration
- token expiration
- refresh-token behavior
- token invalidation
- account deactivation
- device binding
- unauthorized requests
- revoked sessions
- maintenance mode
- startup authentication state
- navigation guards
- session race conditions

Never trust client-side role checks as the security boundary.

Authorization must ultimately be enforced server-side.

The client should fail safely when authorization state is unknown.

Do not expose sensitive credentials, service-role keys, secrets, private signing keys, or privileged tokens in the Flutter application.

---

# 9. Supabase and Backend Security

Treat Supabase as a security boundary.

Audit:

- RLS
- policies
- RPC functions
- Edge Functions
- database queries
- role restrictions
- tenant isolation
- token validation
- session invalidation
- storage policies
- realtime authorization
- input validation
- error leakage

The client must never assume that hiding a UI element provides authorization.

Any sensitive operation must be validated server-side.

Do not leak database schema details, authentication internals, credentials, or sensitive backend errors to end users.

---

# 10. Secrets and Configuration

Strictly separate:

- public configuration
- build-time configuration
- runtime configuration
- secrets

Never hard-code secrets.

Never commit:

- private keys
- signing credentials
- service-role credentials
- real production secrets
- API secrets
- private certificates unless intentionally public and required

Check Git history as well as current files for accidental secret exposure.

Treat `.env.example` and security example files as documentation/configuration templates, not secret storage.

---

# 11. Security Hardening

Perform a real application security review.

Audit:

- secure storage
- screenshots
- screen recording
- rooted/jailbroken devices
- emulator detection
- SSL/TLS handling
- certificate validation
- certificate pinning if actually required
- WebView security
- URL handling
- deep links
- intent handling
- exported Android components
- network security configuration
- backup policies
- logging
- crash reporting
- sensitive data in logs
- clipboard exposure
- local database protection
- offline files
- downloaded media
- cache directories
- temporary files
- authentication tokens
- device binding

Do not implement security controls merely for marketing terminology.

Each control must have a clear threat model.

---

# 12. Offline and Download Security

Offline content is security-sensitive.

Audit the entire lifecycle:

1. entitlement validation
2. download authorization
3. download initialization
4. file creation
5. encryption
6. local metadata
7. integrity validation
8. playback
9. expiration
10. revocation
11. deletion
12. device binding
13. corrupted-download recovery
14. interrupted-download recovery
15. storage cleanup

Do not claim DRM unless the implementation actually provides DRM guarantees.

Client-side encryption is not equivalent to hardware-backed DRM.

Document the actual security boundary honestly.

---

# 13. Networking Reliability

All network operations must handle:

- timeout
- no connectivity
- DNS failure
- server error
- rate limiting
- expired authentication
- malformed server response
- unexpected JSON
- partial response
- cancellation
- duplicate request
- race conditions

Implement consistent:

- request timeout strategy
- retry policy
- exponential backoff where justified
- cancellation
- error mapping
- logging
- observability

Never retry non-idempotent operations blindly.

Never retry authentication or payment-like operations without analyzing idempotency.

---

# 14. Error Handling

Every production-critical operation must have explicit failure behavior.

Users should receive useful, localized, safe errors.

Developers should receive detailed diagnostic information through logging/observability.

Never expose raw exceptions, stack traces, SQL errors, backend internals, or credentials to users.

Use typed/domain-level error handling where beneficial.

Avoid catch-all exception handlers that silently discard failures.

Never use:

```dart
catch (_) {}
```

for important business operations without a documented reason.

---

# 15. Logging and Observability

Production logs must be useful without leaking secrets.

Audit:

- authentication events
- network failures
- critical state transitions
- download failures
- playback failures
- startup failures
- background-task failures
- unexpected exceptions

Do not log:

- passwords
- tokens
- refresh tokens
- private keys
- sensitive personal data
- complete authorization headers
- raw sensitive backend payloads

Sentry or equivalent observability must be configured correctly for production.

Verify:

- release/version tagging
- environment tagging
- stack traces
- breadcrumbs
- user identification policy
- privacy
- sampling
- crash grouping

---

# 16. Testing Strategy

Do not optimize for test count.

Optimize for confidence.

The final test strategy should cover:

### Unit Tests

Business logic, utilities, serializers, repositories, services, security-critical logic, state transitions.

### Widget Tests

Critical widgets and user interactions.

### Integration Tests

Critical end-to-end flows.

At minimum validate:

- application startup
- authentication
- session restoration
- logout
- navigation guards
- course loading
- course details
- lesson playback flow
- progress tracking
- notifications
- download flow
- offline access where applicable
- error states
- retry behavior
- localization
- RTL
- accessibility

### Regression Tests

Every production bug discovered during the project should result in a regression test when practical.

---

# 17. Accessibility

Accessibility is a production requirement.

Audit:

- semantic labels
- `Semantics`
- tappable target sizes
- text scaling
- contrast
- focus order
- focus traversal
- keyboard navigation where applicable
- screen reader behavior
- dynamic text
- localization effects
- RTL behavior

Do not limit accessibility checks to `IconButton.tooltip`.

Create actual widget-level accessibility tests.

Test with realistic `MediaQuery.textScaler` values.

The application must remain usable under increased text size.

---

# 18. UI and Design-System Rules

The design system must remain centralized.

Do not scatter arbitrary:

- colors
- text styles
- radii
- spacing
- durations
- shadows

throughout feature widgets.

Prefer existing design tokens.

Maintain:

- Material 3 consistency
- RTL correctness
- Arabic typography
- English typography
- light mode
- dark mode
- responsive layouts
- loading states
- empty states
- error states

Do not redesign screens simply for aesthetic preference unless there is a documented UX or production reason.

---

# 19. Performance

Performance work must be evidence-driven.

Measure before optimizing.

Audit:

- unnecessary widget rebuilds
- provider rebuilds
- expensive build methods
- image memory
- cache behavior
- list/grid rendering
- scrolling
- animations
- startup time
- network requests
- database queries
- disk I/O
- background tasks
- video playback
- download performance

Avoid premature micro-optimizations.

Do not sacrifice maintainability for negligible gains.

---

# 20. Memory and Resource Safety

Look for:

- stream leaks
- controller leaks
- listeners that are never removed
- timers that survive disposed widgets
- unbounded caches
- uncancelled requests
- background workers without cleanup
- media controllers that are not disposed
- WebViews that remain alive unnecessarily

Every long-lived resource must have a clear lifecycle.

---

# 21. Navigation

GoRouter must be treated as application infrastructure.

Audit:

- authenticated routes
- unauthenticated routes
- redirects
- deep links
- invalid routes
- back navigation
- nested navigation
- state restoration
- session changes during navigation

Avoid redirect loops.

Ensure navigation remains deterministic when authentication state changes asynchronously.

---

# 22. Localization

Support both:

- Arabic
- English

Verify:

- generated localization files
- missing translations
- fallback behavior
- RTL
- LTR
- pluralization
- date formatting
- number formatting
- text overflow
- dynamic text length

Never hard-code user-facing strings in production widgets when they belong in localization.

---

# 23. Android Production Readiness

Audit the entire Android release configuration.

Verify:

- package/application ID
- namespace
- min SDK
- target SDK
- compile SDK
- Gradle
- Android Gradle Plugin
- Java/Kotlin compatibility
- release build type
- R8/minification
- resource shrinking
- ProGuard/R8 rules
- signing
- manifest
- exported components
- permissions
- backup rules
- network security
- cleartext traffic
- notification behavior
- deep links
- app links
- splash screen
- adaptive icon
- versionCode/versionName

Validate an actual release build.

Debug builds are insufficient evidence.

---

# 24. iOS Production Readiness

Audit:

- deployment target
- bundle identifier
- signing
- provisioning
- entitlements
- Info.plist
- permissions
- ATS
- background modes
- push notifications
- keychain behavior
- deep links
- URL schemes
- capabilities
- privacy manifests
- release configuration

Validate an actual release/archive configuration where the environment allows it.

Do not claim iOS readiness based only on source inspection.

---

# 25. CI/CD

Existing GitHub Actions must be audited rather than assumed correct.

CI should enforce, as appropriate:

- dependency resolution
- formatting
- static analysis
- code generation checks
- unit tests
- widget tests
- integration tests
- golden tests where used
- security checks
- build validation
- Android release build validation
- iOS validation where runner/environment permits
- artifact generation
- version validation

Failures must fail the pipeline.

Do not create "green" workflows that ignore failing commands.

Do not use:

```bash
|| true
```

to hide meaningful failures.

---

# 26. Reproducible Builds

Builds should be deterministic as far as reasonably possible.

Pin critical tool versions.

Document:

- Flutter version
- Dart version
- Java version
- Android toolchain
- Xcode requirements
- package constraints
- build commands

Avoid depending on undocumented local machine state.

---

# 27. Dependency Management

Audit every dependency.

For each dependency ask:

- Is it actually used?
- Is it required in production?
- Is it redundant?
- Is it maintained?
- Does it introduce security or build risk?
- Is a platform-specific alternative required?
- Is its version compatible with the current Flutter/Dart toolchain?

Do not upgrade every dependency blindly.

Prefer controlled upgrades with tests.

Remove unused dependencies only after confirming they are genuinely unused.

---

# 28. Code Generation

Verify:

- Riverpod generation
- Freezed generation
- JSON serialization
- localization generation

Generated artifacts must remain synchronized with source.

CI should detect stale generated code.

Do not manually edit generated files unless the generator workflow explicitly requires it.

---

# 29. Database and Persistence

Audit:

- SQLite schema
- migrations
- corruption handling
- initialization
- concurrent access
- transactions
- cleanup
- cache invalidation
- encryption requirements
- schema versioning

Never assume local storage is trustworthy.

All persisted state should have corruption/recovery behavior where practical.

---

# 30. Background Tasks

Audit WorkManager/background download/background notification behavior.

Consider:

- application termination
- device reboot
- network loss
- battery restrictions
- duplicate execution
- cancellation
- retries
- corrupted state
- concurrent work
- expiration
- cleanup

Background operations must be idempotent wherever possible.

---

# 31. Production State Machine

Treat the project as a sequence of gated milestones.

Suggested progression:

P0 — Repository and architecture audit

P1 — Build/toolchain stabilization

P2 — Architecture and dependency hardening

P3 — Authentication/session hardening

P4 — Data/network reliability

P5 — Security hardening

P6 — Offline/download hardening

P7 — UI/accessibility/localization

P8 — Performance

P9 — Unit/widget/integration/regression testing

P10 — CI/CD hardening

P11 — Android release validation

P12 — iOS release validation

P13 — Observability and operational readiness

P14 — Final production release audit

Do not proceed to the next major milestone while critical blockers remain unresolved.

---

# 32. Severity Model

Classify findings as:

CRITICAL
Blocks production release.

HIGH
Must be fixed before public release unless explicitly accepted as a risk.

MEDIUM
Should be fixed before release where practical.

LOW
Improvement that does not materially block release.

Do not inflate severity to create unnecessary work.

Do not downgrade security or data-integrity issues merely because they are inconvenient.

---

# 33. Definition of Done

A task is NOT complete because:

- code compiles
- analyzer passes
- a test was added
- a workflow exists
- a feature appears to work manually

A task is complete only when:

1. implementation is correct
2. regression risk is addressed
3. tests exist where appropriate
4. static analysis passes
5. formatting passes
6. generated files are synchronized
7. documentation/configuration is updated when needed
8. security implications are considered
9. failure behavior is validated
10. CI behavior is validated where applicable

---

# 34. Change Discipline

For every modification:

- prefer the smallest safe diff
- preserve unrelated behavior
- avoid unnecessary refactoring
- avoid mass file rewrites
- explain architectural impact internally
- add/update tests
- verify affected flows

Do not modify unrelated files merely to make a patch look cleaner.

---

# 35. No Fake Completion

Never report:

- "production ready"
- "secure"
- "fully tested"
- "iOS ready"
- "release ready"

unless there is objective evidence.

Use precise language such as:

- verified
- partially verified
- statically inspected
- test-covered
- blocked by environment
- not yet verified

Distinguish clearly between:

`verified`

and

`assumed`.

---

# 36. Environment Constraints

When a required verification cannot be executed because of missing tools, credentials, hardware, OS, Apple signing environment, network access, emulator/device availability, or external services:

Do NOT fabricate results.

Instead:

1. identify exactly what could not be verified
2. perform all alternative static/local validation available
3. explain the remaining verification gap
4. make the project fail-safe where possible
5. provide the exact command/procedure required for final verification

---

# 37. Documentation Integrity

Documentation must reflect the actual implementation.

Audit:

- README
- architecture documentation
- environment documentation
- deployment documentation
- release instructions
- security documentation
- testing instructions

Do not leave documentation claiming features that do not exist.

Do not document planned functionality as implemented.

---

# 38. Git Discipline

Use small, logically isolated commits.

Recommended categories:

- `build:`
- `ci:`
- `fix:`
- `feat:`
- `refactor:`
- `perf:`
- `security:`
- `test:`
- `docs:`
- `chore:`

Do not mix unrelated concerns in the same commit.

Never commit secrets.

Never rewrite public history unless explicitly required.

---

# 39. PR Discipline

Every substantial change should be reviewable.

A PR should clearly state:

- problem
- root cause
- implementation
- tests
- risk
- migration considerations
- production impact

Avoid huge PRs that combine unrelated architectural work.

---

# 40. Agent Behavior

Act as a senior:

- Flutter engineer
- Dart engineer
- application architect
- security engineer
- QA engineer
- DevOps/CI engineer

Do not behave like a generic code generator.

Before implementing a solution, inspect surrounding code and its dependencies.

When modifying one subsystem, check its callers and consumers.

When fixing a bug, investigate the root cause instead of patching only the visible symptom.

Prefer evidence over assumptions.

---

# 41. Required Reporting After Each Major Phase

Report:

### Current State

What is currently working.

### Findings

What was discovered.

### Changes

What was modified.

### Verification

What commands/tests/builds passed.

### Remaining Risks

What remains unresolved.

### Release Impact

Whether the application moved closer to or away from production readiness.

Never hide remaining blockers.

---

# 42. Final Production Gate

Do not declare EduZone production-ready until the following are explicitly verified:

- clean dependency resolution
- clean formatting
- clean static analysis
- generated code synchronized
- unit tests passing
- widget tests passing
- critical integration tests passing
- accessibility validation passing
- localization validation passing
- authentication/session flows verified
- Supabase security verified
- production error handling verified
- no known critical security issue
- no known critical data-integrity issue
- Android release build verified
- release signing configuration verified
- iOS release configuration verified
- CI/CD verified
- crash reporting verified
- logging/privacy reviewed
- performance baseline established
- rollback/release procedure documented

Anything not verified must remain explicitly marked as unverified.

---

# 43. Ultimate Goal

The final objective is not to maximize the amount of code changed.

The objective is to produce a stable, secure, maintainable, testable, observable, and releasable EduZone application whose production readiness can be demonstrated with evidence.

Quality over quantity.

Evidence over assumptions.

Incremental hardening over uncontrolled rewrites.

Production correctness over superficial completion.