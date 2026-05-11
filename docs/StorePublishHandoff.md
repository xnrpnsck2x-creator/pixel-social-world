# App Store and Google Play Publish Handoff

Date: 2026-05-12

Status: Local publish contract ready. Actual App Store Connect and Google Play
Console upload remains a release-machine task because store accounts, upload
keys, provisioning data, and service credentials must stay outside this
repository.

## Official Sources Checked

- Apple App Store submission overview: https://developer.apple.com/app-store/submitting/
- Apple upcoming upload requirements: https://developer.apple.com/news/upcoming-requirements/
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Store Connect screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple app privacy details: https://developer.apple.com/help/app-store-connect/manage-app-privacy
- Google Android App Bundle guide: https://developer.android.com/guide/app-bundle
- Google Play target API requirements: https://support.google.com/googleplay/android-developer/answer/11926878
- Google Play Data safety form: https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play app content setup: https://support.google.com/googleplay/android-developer/answer/9859455
- Google Play user-generated content policy: https://support.google.com/googleplay/android-developer/answer/9876937

## Scope

This handoff covers the last local gate before:

- Apple TestFlight and App Store submission.
- Google Play internal, closed, and production tracks.

The local project can prove package identity, native export hygiene, no committed
secrets, release-readiness scripts, store branding assets, and policy evidence
requirements. It cannot honestly prove final upload until the external store
accounts, signing credentials, and store console forms exist.

## Non-Negotiables

- Do not commit Apple Team ID, signing identity, provisioning profile UUID,
  provisioning profile specifier, App Store Connect API keys, `.p8` keys,
  Google Play service-account JSON, Android upload keystores, keystore aliases,
  keystore passwords, store tokens, review demo passwords, backend DSNs, or
  admin tokens.
- Keep App Store Connect API credentials, Google Play service accounts, Android
  upload keys, Apple distribution certificates, provisioning profiles, and
  reviewer credentials outside the repository.
- Store privacy-policy URLs must be HTTPS.
- User-generated content review notes must describe reporting, blocking,
  moderation, and abusive-content handling.
- A failed publish handoff gate means stop the upload flow.

## Local Gate

Run before any store upload attempt:

```bash
scripts/check_store_publish_handoff.sh
scripts/check_native_release_handoff.sh
scripts/run_project_category_v2_gate.sh
```

The store gate validates:

- iOS release readiness stays no-secret by default.
- Android APK release readiness stays available for device/debug handoff.
- Android Play AAB readiness passes through the dedicated `Android Play AAB`
  preset.
- Store publish metadata and policy evidence are documented.
- Strict publish mode fails closed when external store values are absent.

## Apple App Store / TestFlight Handoff

Current release package identity:

- Bundle identifier: `com.pixelsocialworld.app`
- Marketing version: `0.1.0`
- Build number: `1`
- Target family: iPhone
- App icon: `res://assets/branding/generated/app_icon_forest_dawn_v1_1024.png`
- Launch splash: Image 2 derived PNGs under `assets/branding/generated/`

Required release-machine state:

```bash
export IOS_TEAM_ID="<apple-team-id>"
export IOS_BUNDLE_ID="com.pixelsocialworld.app"
export IOS_CODE_SIGN_IDENTITY_RELEASE="<apple-distribution-identity>"
export IOS_PROVISIONING_PROFILE_UUID_RELEASE="<profile-uuid>"
export IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE="<profile-specifier>"
export PSW_IOS_RELEASE_SIGNING_REQUIRED=1
```

Required store-console evidence:

- Full Xcode is installed for the current Apple upload requirement. As of this
  2026-05-12 handoff, uploaded apps must be built with Xcode 26 and the iOS 26 SDK
  family requirement from Apple upcoming requirements.
- App Store Connect app record exists for `com.pixelsocialworld.app`.
- App privacy answers are complete, including account, identifier, contact,
  user content, diagnostics, and moderation-related data where applicable.
- Age rating is complete.
- Review notes include guest login, Apple/Google account upgrade path, how to
  find chat/report/block/moderation features, and any test account details.
- Screenshots are captured for the required iPhone display sizes in the current
  App Store Connect screenshot specification.
- TestFlight true-device smoke passes: launch, landscape orientation, guest
  login, main city movement, chat/private input, report/block path, Trade Market
  post/cancel, housing placement, fishing reward, and clean console/crash scan.

Strict publish env:

```bash
export PSW_STORE_PUBLISH_REQUIRED=1
export PSW_APPLE_CONNECT_APP_ID="<numeric-app-id>"
export PSW_APPLE_PRIVACY_POLICY_URL="https://example.com/privacy"
export PSW_APPLE_REVIEW_CONTACT_EMAIL="review@example.com"
export PSW_APPLE_APP_PRIVACY_READY=1
export PSW_APPLE_AGE_RATING_READY=1
export PSW_APPLE_REVIEW_NOTES_READY=1
export PSW_APPLE_TESTFLIGHT_READY=1
```

## Google Play Handoff

Current release package identity:

- Package name: `com.pixelsocialworld.app`
- Version name: `0.1.0`
- Version code: `1`
- APK debug/device export path: `builds/android/pixel_social_world.apk`
- Play upload export path: `builds/android/pixel_social_world.aab`
- Play upload preset: `Android Play AAB`
- Target API: 35
- Required permissions: Internet and network state.

Google Play upload path:

- Use Android App Bundle for the first Play release path.
- Keep the APK preset for local/debug/device handoff.
- Keep the upload keystore outside the repository.

Required release-machine state:

```bash
export ANDROID_RELEASE_KEYSTORE="/absolute/path/outside/repo/pixel-social-world-release.keystore"
export ANDROID_RELEASE_KEYSTORE_USER="<release-alias>"
export ANDROID_RELEASE_KEYSTORE_PASSWORD="<store-password>"
export ANDROID_RELEASE_KEY_PASSWORD="<key-password>"
export PSW_ANDROID_RELEASE_SIGNING_REQUIRED=1
export PSW_ANDROID_RELEASE_FORMAT=aab
```

Required store-console evidence:

- Play Console app exists for `com.pixelsocialworld.app`.
- Android App Bundle upload succeeds for the signed `pixel_social_world.aab`.
- Target API requirement is met for the current Play policy window.
- Data safety form is complete.
- App access section explains login/reviewer access.
- Content rating questionnaire is complete.
- Target audience and content settings are complete.
- Ads declaration is complete.
- Privacy policy URL is HTTPS.
- User-generated content policy evidence covers reports, blocking, moderation,
  admin action audit, creator package review, and abusive-content handling.
- Internal testing smoke passes. Closed testing evidence is required if the
  current Play developer account must complete closed testing before production
  access.

Strict publish env:

```bash
export PSW_STORE_PUBLISH_REQUIRED=1
export PSW_GOOGLE_PLAY_APP_ID="com.pixelsocialworld.app"
export PSW_GOOGLE_PRIVACY_POLICY_URL="https://example.com/privacy"
export PSW_GOOGLE_DATA_SAFETY_READY=1
export PSW_GOOGLE_CONTENT_RATING_READY=1
export PSW_GOOGLE_TARGET_AUDIENCE_READY=1
export PSW_GOOGLE_APP_ACCESS_READY=1
export PSW_GOOGLE_CLOSED_TESTING_READY=1
```

## Evidence Manifest

For every store release candidate, keep local evidence under:

```text
.tools/store-publish-handoff/<date-or-commit>/
```

Required contents:

- Commit SHA.
- `scripts/check_store_publish_handoff.sh` output.
- `scripts/check_native_release_handoff.sh` output.
- `scripts/run_project_category_v2_gate.sh` output.
- iOS strict release readiness output.
- Android strict AAB readiness output.
- Signed artifact names, versions, build numbers, and checksums.
- App Store Connect product-page and privacy screenshots.
- Google Play app-content, Data safety, and track screenshots.
- TestFlight or Play internal/closed testing notes.
- iOS and Android true-device smoke screenshots or videos.
- Crash/log scan summaries.

Do not place store API keys, service-account JSON, upload keystores, passwords,
provisioning profiles, certificates, or reviewer credentials in this evidence
folder.

## Stop Conditions

Stop the store flow when any of these happen:

- `scripts/check_store_publish_handoff.sh` fails.
- `scripts/check_native_release_handoff.sh` fails.
- Strict iOS signing readiness fails.
- Strict Android AAB signing readiness fails.
- Store privacy, Data safety, content rating, app access, or target audience
  forms are incomplete.
- UGC moderation evidence is unclear.
- Review notes cannot explain guest login, account upgrade, report/block, chat,
  creator review, Trade Market, housing, or fishing routes.
- True-device smoke finds crash, ANR, Godot script error, backend auth failure,
  WebSocket presence failure, broken keyboard entry, or failed economy route.
- Any store credential or signing secret appears in committed files.

Rollback target is the last commit where:

```bash
scripts/check_store_publish_handoff.sh
scripts/check_native_release_handoff.sh
scripts/run_project_category_v2_gate.sh
```

all passed.
