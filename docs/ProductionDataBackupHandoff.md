# Production Data Backup Handoff

Date: 2026-05-12

Status: Public Alpha handoff contract v1. The local contract is gated; the
real backup destination and restore drill must be validated on the production
host before public alpha.

## Scope

Backups for the single-host MVP must cover the durable game state and the
creator content that cannot be reconstructed from Git:

- PostgreSQL: accounts, sessions, profiles, wallets, ledgers, inventory,
  housing layouts, private messages, mailbox rows, reports, admin audit,
  creator review state, creator payout rows, trade listings, and trade history.
- Creator package artifacts: `PSW_PACKAGE_ARTIFACT_DIR`, defaulting to
  `/var/lib/pixel-social-world/creator_packages`.
- Creator runtime installs: `PSW_PACKAGE_INSTALL_DIR`, defaulting to
  `/var/lib/pixel-social-world/creator_runtime`.
- Deployment manifest: release commit, binary checksums, config checksums, and
  the non-secret shape of `/etc/pixel-social-world/backend.env`.

Room chat is ephemeral and is not part of the backup target. Redis presence,
room membership, and minigame session TTL state are also disposable for MVP
recovery.

## Non-Negotiables

- Do not commit DB dumps, creator package archives, restore artifacts, DSNs,
  admin tokens, backup service keys, or encryption keys.
- Backups must be stored outside the repo and outside the live app directory.
- Backups must be encrypted at rest. `PSW_BACKUP_ENCRYPTION=none`,
  `plaintext`, or `disabled` is not acceptable for public alpha.
- PostgreSQL and creator package directories are one recovery set. Do not
  restore one without the other unless the incident commander explicitly
  accepts missing creator content.
- Run at least one restore drill into a disposable database and disposable
  package directories before public alpha.

## Required Environment

Strict handoff mode is enabled with:

```bash
PSW_PRODUCTION_BACKUP_REQUIRED=1
```

The release host must also provide:

```bash
PSW_POSTGRES_DSN=postgres://pixel:...@127.0.0.1:5432/pixel_social_world?sslmode=disable
PSW_PACKAGE_ARTIFACT_DIR=/var/lib/pixel-social-world/creator_packages
PSW_PACKAGE_INSTALL_DIR=/var/lib/pixel-social-world/creator_runtime
PSW_BACKUP_DESTINATION=/mnt/backups/pixel-social-world
PSW_BACKUP_ENCRYPTION=age
```

Keep these values in the host environment or in the operator shell. Do not add
real credentials to committed config files.

## Backup Runbook

1. Record the release commit:

   ```bash
   git rev-parse HEAD
   ```

2. Run the local contract:

   ```bash
   scripts/check_production_data_backup_handoff.sh
   ```

3. Run strict mode on the production host:

   ```bash
   PSW_PRODUCTION_BACKUP_REQUIRED=1 scripts/check_production_data_backup_handoff.sh
   ```

4. Create a PostgreSQL custom-format dump with `pg_dump`:

   ```bash
   pg_dump --format=custom --no-owner --no-acl "$PSW_POSTGRES_DSN" \
     > "$PSW_BACKUP_DESTINATION/postgres-$(date -u +%Y%m%dT%H%M%SZ).dump"
   ```

5. Archive creator package artifacts and runtime installs:

   ```bash
   tar -C "$(dirname "$PSW_PACKAGE_ARTIFACT_DIR")" -czf \
     "$PSW_BACKUP_DESTINATION/creator_packages-$(date -u +%Y%m%dT%H%M%SZ).tgz" \
     "$(basename "$PSW_PACKAGE_ARTIFACT_DIR")"

   tar -C "$(dirname "$PSW_PACKAGE_INSTALL_DIR")" -czf \
     "$PSW_BACKUP_DESTINATION/creator_runtime-$(date -u +%Y%m%dT%H%M%SZ).tgz" \
     "$(basename "$PSW_PACKAGE_INSTALL_DIR")"
   ```

6. Encrypt the backup set using the production-approved tool declared by
   `PSW_BACKUP_ENCRYPTION`.

7. Store evidence under:

   ```text
   .tools/production-data-backup-handoff/<release-commit>/
   ```

   Evidence may include command transcripts, object names, checksums, restore
   drill status, and screenshots. It must not include dumps, package archives,
   credentials, tokens, or private DSNs.

## Restore Drill

The minimum restore drill before public alpha:

1. Restore the PostgreSQL dump into a disposable database.
2. Extract creator package artifacts into a disposable artifact directory.
3. Extract creator runtime installs into a disposable runtime directory.
4. Launch the backend preflight against those disposable paths.
5. Verify:
   - guest login still works,
   - wallet/ledger reads work,
   - house layout reads work,
   - trade history audit reads work,
   - at least one published creator minigame package is visible,
   - LiveOps Debug Ops opens without touching player state.

Record the restore drill result in the evidence folder.

## Stop Conditions

Block public alpha if any of these are true:

- Strict backup handoff fails.
- Backup destination is inside the repo or inside `/opt/pixel-social-world`.
- Backup encryption is unset, `none`, `plaintext`, or `disabled`.
- The restore drill has not been run for the current release line.
- PostgreSQL dump exists but creator package directories were not backed up.
- Evidence contains raw dumps, package archives, credentials, tokens, or DSNs.
