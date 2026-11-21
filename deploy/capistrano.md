# Remote Gaming Capistrano deployment

Capistrano uses the established `harvj` SSH alias and existing application runtimes, environment files, systemd units, and absolute SHA release symlinks. Confirm the alias resolves to the reviewed Hetzner host and keep strict host-key verification. The two stages share the read-only Ruby and Node binaries under `/opt/remote-gaming`.

| Stage | Release root | Database and role | Service | Loopback |
| --- | --- | --- | --- | --- |
| Production | `/var/www/remote-gaming` | `remote_gaming_production`, `remote_gaming` | `remote-gaming.service` | `3012` |
| Staging | `/var/www/remote-gaming-staging` | `remote_gaming_staging`, `remote_gaming_staging` | `remote-gaming-staging.service` | `3013` |

## One-time adoption

After deployment authorization, install the reviewed root-owned helper from the same clean commit used by the operator. Capistrano checks the helper digest before each remote operation. Repeat the reviewed installation when its source changes. The operator uses the existing administrative SSH and sudo access. Use /usr/local/sbin/remote-gaming-staging-deploy for staging and /usr/local/sbin/remote-gaming-deploy for production. The staging binary rejects production targets.

```bash
work=$(mktemp -d)
git show HEAD:deploy/remote-gaming-deploy > "$work/remote-gaming-deploy"
shasum -a 256 "$work/remote-gaming-deploy"
scp "$work/remote-gaming-deploy" harvj:remote-gaming-deploy.candidate
ssh harvj 'sha256sum "$HOME/remote-gaming-deploy.candidate"'
# Compare digests before installation.
ssh harvj 'sudo install -o root -g root -m 0755 "$HOME/remote-gaming-deploy.candidate" /usr/local/sbin/remote-gaming-deploy'
bundle exec cap production deploy:check
```

Production adoption uses the existing `current` symlink. Verify it is an absolute link to the existing P1.0 release within `/var/www/remote-gaming/releases`. The first successful deployment records this release as its rollback predecessor. Adopt the existing production database in place. The migration gate will require a reviewed maintenance run for P1.1's SessionFrame migration if production is still on P1.0. Preserve the original recovery dumps and confirm the operator has access to the existing backup procedures. Capistrano creates a separate verified pre-migration backup.

### Provision staging once

Use the audited runtime and named host described in the [private staging runbook](staging.md). From a clean checkout, transfer the two staged templates via `scp deploy/remote-gaming-staging.service deploy/staging.env.example harvj:`. On the server, verify the selected port, username and database are unused before creating anything.

```bash
test -z "$(ss -H -ltn 'sport = :3013')"
if getent passwd remote_gaming_staging; then exit 1; fi
sudo -u postgres psql -X -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE remote_gaming_staging LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE DATABASE remote_gaming_staging OWNER remote_gaming_staging TEMPLATE template0;
REVOKE ALL ON DATABASE remote_gaming_staging FROM PUBLIC;
SQL
sudo useradd --system --user-group --create-home --home-dir /var/lib/remote-gaming-staging --shell /usr/sbin/nologin remote_gaming_staging
sudo install -d -m 0755 /var/www/remote-gaming-staging/{releases,shared} /etc/remote-gaming-staging
sudo install -d -m 0750 -o remote_gaming_staging -g remote_gaming_staging /var/www/remote-gaming-staging/shared/storage
sudo install -m 0600 "$HOME/staging.env.example" /etc/remote-gaming-staging/application.env
sudoedit /etc/remote-gaming-staging/application.env
sudo install -m 0644 "$HOME/remote-gaming-staging.service" /etc/systemd/system/remote-gaming-staging.service
sudo systemctl daemon-reload
```

Use the staging runbook's database password and signing-key instructions with the staging role only. Run its SHA-256 checks and restore command to populate the disposable staging database from the original dump. The first Capistrano staging release can start with no `current` symlink. After it succeeds, create the three test accounts with the staging runbook's `rg_stage runner deploy/staging-accounts.rb` command and enable the staging service with `sudo systemctl enable remote-gaming-staging.service`. The staging Caddy import and public certificate require their own review, validation, and authorization. Obtain edge credentials and run the hosted browser checks before sharing staging.

## Deploy

Run from a clean checkout of local `main`, with the reviewed full SHA already published to GitHub `main`. Capistrano compares the exact SHA to the live remote and sends its Git archive. A dirty tree, unexpected origin, or unpublished SHA fails before deployment. Review exact-commit CI before approving the SHA.

```bash
bundle install
export APPROVED_COMMIT=REVIEWED_FULL_SHA
bundle exec cap production deploy
bundle exec cap staging deploy
```

Run only the intended stage. Static task loading is available through `bundle exec cap staging deploy:config`. The reviewed helper locks the stage, verifies the upload checksum, builds locked Ruby and Node dependencies and assets as the app user, checks the database identity and production route gate, and validates a custom-format database backup and its checksum. It preserves each existing release directory.

Pending migrations require explicit approval in a maintenance window. Reuse the reviewed commit and set `ALLOW_MIGRATIONS=1` for that invocation.

```bash
APPROVED_COMMIT=REVIEWED_FULL_SHA ALLOW_MIGRATIONS=1 bundle exec cap staging deploy
# Use the production command only after its separate review and maintenance approval.
APPROVED_COMMIT=REVIEWED_FULL_SHA ALLOW_MIGRATIONS=1 bundle exec cap production deploy
```

For a migration the helper stops only the selected app before the backup, verifies the history fingerprints after migrating, switches `current` atomically, and restarts that service. This release's migration workflow requires preserved historical rows and sequence values. Review changes to the fingerprint procedure before approving a future data-changing migration. Successful rollout requires the selected loopback smoke checks. Use the [production runbook](README.md) or [staging runbook](staging.md) afterward for public HTTPS, Action Cable, and browser checks. Caddy and the other systemd services are outside this workflow.

## Promote the same revision

Stage the exact reviewed GitHub main SHA first. Record its CI result, installed helper digest, backup verification, migration ledger, and hosted acceptance. Rehearse a production backup restore and the exact migration on a disposable copy. Compare historical rows, SessionFrames and sequence values before and after. Check both production route configurations using the candidate. Keep public replay disabled until its separate Auth registration and access review are complete.

Once staging acceptance and the production checks pass, request approval for that exact SHA and production maintenance window. Promote in that window using a clean checkout of the same GitHub main revision. Recheck the active production baseline and schema ledger, then run:

```bash
bundle exec cap production deploy:check
APPROVED_COMMIT=VERIFIED_STAGING_SHA ALLOW_MIGRATIONS=1 bundle exec cap production deploy
./deploy/smoke
```

Use `ALLOW_MIGRATIONS=1` only when the approved rollout has a pending migration. The helper verifies the backup before migration and compares data fingerprints before switching the release. Confirm the active SHA and migration ledger afterward. Verify the public directory and confirm that replay, dummy management, branching, gameplay and Cable routes are unavailable under the default production configuration. Record the before and after releases and preserve the migration backup.

For P1.4, the only pending migration from the v0.3.0 production ledger is `20261120000001`. After it runs, the helper rejects a code rollback to a predecessor recorded against the old ledger. Use a reviewed forward fix or a separately approved isolated restore and cutover. Reversing the migration on an untouched rehearsal copy demonstrates reversibility of the schema change. A live reversal after branches are created would discard lineage metadata.

## Rollback and failure recovery

Review the immediately previous release SHA recorded in `current/.remote-gaming-previous` on the selected target. From a clean operator checkout:

```bash
APPROVED_COMMIT=REVIEWED_PREVIOUS_SHA bundle exec cap production deploy:rollback
APPROVED_COMMIT=REVIEWED_PREVIOUS_SHA bundle exec cap staging deploy:rollback
```

The helper checks the target is the recorded predecessor and the applied migration ledger still matches the ledger under which that release ran. If compatible, it changes only the selected symlink and service, then runs the stage smoke test. The ledger check assumes schema changes go through Rails migrations. Review out-of-band DDL before approving rollback. A first staging release has no predecessor.

A changed ledger or unresolved migration attempt blocks code rollback. The helper records a migration attempt before running it and clears the marker after a healthy deployment. This protects against partially applied nontransactional migrations whose versions may be absent from the ledger. If there is no verified compatible release, the helper leaves the selected service stopped and retains the backup, release, and database. Prefer a reviewed compatible forward fix. Any database restore is a separate operation into a new isolated database, with write-loss assessment and integrity verification before switching. There is no automatic migration reversal or database overwrite.

Inspect the selected journal and the root-only backup directory after any failure. If `.migration-in-progress` exists under the selected release root, inspect the database and migration status, then clear that marker only after a compatible forward recovery has been reviewed. If retrying the same SHA, first verify it is neither `current` nor a recorded rollback predecessor, then move only that inactive candidate directory aside, outside `releases`. Keep verified backups and rollback releases according to the existing retention procedure. An interrupted task may leave an inactive candidate or a partial backup for investigation.

### Application Shell verification

Install the reviewed Infrastructure runtime using its published contract and pin the reviewed Infrastructure source revision. Place `application_shell_gate.py`, `application_shell_registry_cache.py`, and `application_shell_renewal.py` in `/usr/local/lib/application-shell/lib`. Install its `deploy/keys/application-shell-publisher*.pem` under `/usr/local/lib/application-shell/deploy/keys`. Install this application's `deploy/refresh-shell-registry` at `/usr/local/lib/application-shell/refresh-remote-gaming-registry`. All installed files and their directories must be root-owned and inaccessible to application writers. Install the registry service and timer under `/etc/systemd/system`. After `daemon-reload`, start the respective service and enable its timer using instance `staging` or `production`. Check the service journal and its state directory before accepting the environment. The timer normally refreshes every five minutes with jitter and retries on the next interval. A failed refresh leaves the last verified snapshot in place. Each environment has its own root-owned state and Rails performs no publication network requests.

Set `APPROVED_ARTIFACT_SHA256` to the reviewed archive digest for each stage. Production additionally requires `APPLICATION_SHELL_REVIEW` and `APPLICATION_SHELL_STATE` for the exact reviewed commit and a durable local pointer checkpoint. Use the Infrastructure `application-shell-preflight` executable, supplying its path via `APPLICATION_SHELL_PREFLIGHT` if it is not on PATH. A failure stops deployment before contacting the production host. Keep ordinary rollback and recovery on the app-owned path.
