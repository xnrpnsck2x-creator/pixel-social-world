# Security Policy

Pixel Social World is in public alpha preparation. Security reports are welcome, especially around authentication, creator package handling, minigame sandboxing, player data, economy integrity, moderation tools, and release signing.

## Supported Versions

Only the default branch is currently supported:

| Version | Supported |
| --- | --- |
| `main` | Yes |
| Local experimental branches | No |
| Unreleased binaries or local exports | No |

## Reporting A Vulnerability

Please do not open a public issue with exploit details, tokens, private data, or reproduction payloads.

Preferred path:

1. Use GitHub's private vulnerability reporting or repository security advisory flow if it is available on this repository.
2. Include a concise description, affected area, reproduction steps, expected impact, and any relevant commit/build information.
3. Avoid sharing real player data, production credentials, or destructive proof-of-concept payloads.

If private vulnerability reporting is not available, open a minimal public issue asking for a private security contact, without technical details.

## What To Report

Good security reports include:

- Authentication or session bypass
- Privilege escalation in admin, LiveOps, reviewer, moderation, or audit panels
- Minigame sandbox escape or access to nodes outside the sandbox
- Unsafe creator package upload, extraction, or runtime loading behavior
- Economy ledger manipulation, duplicate rewards, or trade integrity flaws
- Leaked secrets, signing keys, service account files, or production DSNs
- Data exposure involving player IDs, private messages, reports, inventory, housing, or creator artifacts
- Denial-of-service paths in WebSocket room sync, chat, package review, or upload handling

## Safe Testing Guidelines

Please:

- Test only against your own local checkout or accounts you control.
- Use dummy data and local credentials.
- Keep proof-of-concept payloads minimal and reversible.
- Do not run destructive load tests against production or public services.
- Do not attempt to access, retain, or exfiltrate real user data.

## Secrets And Credentials

Production secrets must remain external to the repository. This includes:

- `PSW_ADMIN_TOKEN`
- App Store Connect private keys
- Google Play service account JSON
- Android release keystores and passwords
- PostgreSQL and Redis production credentials
- LiveOps alert tokens
- OpenAI-compatible reviewer API keys

The repository includes a local hygiene check:

```bash
python3 scripts/check_secret_hygiene.py
```

If a secret is exposed, rotate it immediately and treat the old value as compromised.

## Response Expectations

For serious reports, the target response rhythm is:

- Initial acknowledgement: within 7 days
- Triage update: within 14 days
- Fix or mitigation plan: based on severity and release risk

This is a small project, so timelines may vary, but security issues that affect player data, authentication, creator package execution, or release signing take priority over ordinary feature work.
