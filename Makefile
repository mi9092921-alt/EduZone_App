.PHONY: run-dev build-prod build-prod-aab build-ios gen-l10n gen-code analyze check-a11y check-architecture check-provider-cycles check-session-invalidation check-rtl check-design-tokens check-performance check-memory-hygiene check-localizations check-auth-security check-logging-security check-config-security check-dependency-floor check-all test clean

## ─── Development ───────────────────────────────────────────────────────

run-dev:
	flutter run --dart-define-from-file=.env

## ─── Build ─────────────────────────────────────────────────────────────
# Release builds use the same single .env — flip the APP_ENV/SENTRY_DSN
# pair inside it to the production values before building for release.

# Android versionCode / security_incidents.app_build_number. Without an
# explicit --build-number every build reports the pubspec `+1` suffix (i.e.
# "1"), so incident rows from different APKs cannot be told apart. Defaults to
# the commit count (monotonic per branch); override with
# `make build-prod BUILD_NUMBER=123`.
BUILD_NUMBER ?= $(shell git rev-list --count HEAD)

build-prod:
	flutter build apk --release --dart-define-from-file=.env --build-number=$(BUILD_NUMBER)

build-prod-aab:
	flutter build appbundle --release --dart-define-from-file=.env --build-number=$(BUILD_NUMBER)

# iOS CFBundleVersion: mirrors the Android rule above. Without an explicit
# --build-number every IPA carries the pubspec `+1` suffix, so App Store
# Connect rejects successive uploads with "CFBundleVersion must be higher"
# (IOS-BUILD-NUMBER, 2026-09-25). Same BUILD_NUMBER default/override.
build-ios:
	flutter build ipa --release --dart-define-from-file=.env --build-number=$(BUILD_NUMBER)

## ─── Code Generation ──────────────────────────────────────────────────

gen-l10n:
	flutter gen-l10n

gen-code:
	dart run build_runner build --delete-conflicting-outputs

gen-watch:
	dart run build_runner watch --delete-conflicting-outputs

## ─── Quality ──────────────────────────────────────────────────────────

analyze:
	flutter analyze

check-a11y:
	@python3 tool/check_a11y.py

check-architecture:
	@python3 tool/check_architecture.py --strict

check-provider-cycles:
	@python3 tool/check_provider_cycles.py

check-session-invalidation:
	@python3 tool/check_session_invalidation.py --strict

check-rtl:
	@python3 tool/check_rtl.py

check-design-tokens:
	@python3 tool/check_design_tokens.py

check-performance:
	@python3 tool/check_performance.py

check-memory-hygiene:
	@python3 tool/check_memory_hygiene.py

check-localizations:
	@python3 tool/check_localizations.py

check-auth-security:
	@python3 tool/check_auth_security.py --strict

check-logging-security:
	@python3 tool/check_logging_security.py --strict

check-config-security:
	@python3 tool/check_config_security.py --strict

check-dependency-floor:
	@python3 tool/check_dependency_floor.py

check-all: check-a11y check-architecture check-provider-cycles check-session-invalidation check-rtl check-design-tokens check-performance check-memory-hygiene check-localizations check-auth-security check-logging-security check-config-security check-dependency-floor

test:
	flutter test --coverage

lint-fix:
	dart fix --apply

## ─── Utilities ────────────────────────────────────────────────────────

clean:
	flutter clean
	flutter pub get
	flutter gen-l10n

deps:
	flutter pub get

outdated:
	flutter pub outdated

audit:
	flutter pub audit
