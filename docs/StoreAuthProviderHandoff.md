# Store Auth Provider Handoff

Date: 2026-05-12

Status: Local contract ready. Real Apple/Google provider credentials, store
review accounts, and app-store console settings remain external release tasks.

## Scope

This runbook covers the production handoff for upgrading guest accounts to
Apple/Google identities across iOS, Android, and H5.

It covers:

- Backend strict OIDC provider verification.
- Apple and Google client ID environment contracts.
- Native/H5 callback and bundle/package alignment.
- Store review evidence.
- Stop conditions for public alpha auth release.

## Non-Negotiables

- Do not commit Apple private keys, Google client secrets, service account JSON,
  OAuth refresh tokens, store API tokens, production admin tokens, or DSNs.
- Do not log identity tokens, authorization codes, refresh tokens, or provider
  subjects in plaintext logs.
- Production provider verification must use `oidc_jwt`, not the local `claimed`
  verifier.
- Guest upgrade must preserve `player_id` so wallet, housing, creator packages,
  inventory, mail, and trade state stay attached to the same account.
- Store review credentials and screenshots stay in the release evidence folder,
  not in source control.

## Existing Backend Contract

The backend endpoint is:

```text
POST /auth/upgrade
```

Supported providers:

- `apple`
- `google`

Production verifier:

```bash
export PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt
export PSW_APPLE_CLIENT_IDS="<apple-service-id-or-bundle-id>[,<apple-client-id>...]"
export PSW_GOOGLE_CLIENT_IDS="<google-ios-or-android-or-web-client-id>[,<google-client-id>...]"
```

The verifier checks provider JWKS signature, issuer, audience, expiry, subject,
and rejects a client-supplied `provider_subject` if it does not match the
verified token subject.

## Local Gate Before Store Auth Release

Run these from the repository root before enabling store auth in a release
candidate:

```bash
scripts/check_store_auth_provider_handoff.sh
scripts/run_backend_e2e.sh
scripts/run_project_category_v2_gate.sh
```

Expected local result:

- `check_store_auth_provider_handoff.sh` passes in default mode with real
  provider env unset.
- `check_store_auth_provider_handoff.sh` proves strict mode fails closed when
  provider env is absent.
- `run_backend_e2e.sh` keeps the guest account upgrade route covered.
- `run_project_category_v2_gate.sh` executes the store auth handoff check as
  part of `auth_profile`.

## Strict Provider Handoff

On the release machine:

```bash
export PSW_STORE_AUTH_PROVIDER_REQUIRED=1
export PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt
export PSW_APPLE_CLIENT_IDS="<apple-service-id-or-bundle-id>[,<apple-client-id>...]"
export PSW_GOOGLE_CLIENT_IDS="<google-ios-or-android-or-web-client-id>[,<google-client-id>...]"
scripts/check_store_auth_provider_handoff.sh
```

Acceptance:

- `PSW_AUTH_PROVIDER_VERIFICATION` is exactly `oidc_jwt`.
- Apple and Google client ID lists are non-empty and do not contain placeholders.
- `backend/configs/production.yaml` keeps provider client ID lists empty so
  real values must arrive from the environment.
- `backend/deploy/pixel-social-world.env.example` documents the required env
  names with placeholders only.
- `backend/internal/config/validation.go` still fails strict production config
  without Apple and Google client IDs.

## Apple Checklist

- Apple Developer app identifier matches the committed iOS bundle id:
  `com.pixelsocialworld.app`.
- Sign in with Apple capability is enabled for the app identifier.
- Service ID or bundle ID used by the backend is present in
  `PSW_APPLE_CLIENT_IDS`.
- The iOS client sends the Apple identity token to `/auth/upgrade`.
- The backend is reachable over HTTPS from the release build.
- Store review notes explain that guest login is available and Apple account
  binding preserves existing progress.

## Google Checklist

- Google Play package name matches the committed Android package:
  `com.pixelsocialworld.app`.
- OAuth client IDs for Android and any H5/web auth shell are present in
  `PSW_GOOGLE_CLIENT_IDS`.
- SHA-1/SHA-256 certificate fingerprints for the release signing key are
  registered in Google Cloud / Play Console.
- The Android client sends the Google ID token to `/auth/upgrade`.
- Store review notes explain that guest login is available and Google account
  binding preserves existing progress.

## Review Evidence

For every public alpha candidate, keep a local evidence folder under
`.tools/store-auth-handoff/<date-or-commit>/` with:

- Build commit SHA.
- `scripts/check_store_auth_provider_handoff.sh` output.
- `scripts/run_backend_e2e.sh` output.
- `scripts/run_project_category_v2_gate.sh` output.
- iOS Apple upgrade screenshot/video and backend response summary.
- Android Google upgrade screenshot/video and backend response summary.
- H5 upgrade screenshot/video if a web provider shell is enabled.
- Store review test account notes and privacy notes.

Do not put identity tokens, authorization codes, client secrets, private keys,
admin tokens, or DSNs in the evidence folder.

## Stop Conditions

Stop the store auth release flow immediately when any of these occur:

- Strict provider handoff fails.
- Production config uses `claimed` provider verification.
- Apple or Google audience/client ID lists are empty or contain placeholders.
- Guest upgrade changes `player_id`.
- Duplicate provider links do not return conflict.
- Token verifier cannot reach provider JWKS over production egress.
- Provider identity tokens, auth codes, subjects, or secrets appear in logs.
- Store review requires a data handling change not reflected in docs or backend
  behavior.

Rollback target is the last commit where:

```bash
scripts/check_store_auth_provider_handoff.sh
scripts/run_backend_e2e.sh
scripts/run_project_category_v2_gate.sh
```

all passed.
