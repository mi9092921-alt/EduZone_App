.PHONY: run-dev run-staging build-prod gen-l10n gen-code analyze check-a11y test clean

## ─── Development ───────────────────────────────────────────────────────

run-dev:
	flutter run --dart-define-from-file=.env

run-staging:
	flutter run --dart-define-from-file=.env.staging

## ─── Build ─────────────────────────────────────────────────────────────

build-prod:
	flutter build apk --release --dart-define-from-file=.env.prod

build-prod-aab:
	flutter build appbundle --release --dart-define-from-file=.env.prod

build-ios:
	flutter build ipa --release --dart-define-from-file=.env.prod

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
