# Remote Gaming P1.0 deployment

P1.0 serves the same public directory at `radioactivita.com` and `gaming.harvj.com`. Modern Art and Pandemic have status pages and are listed as **Not yet available**. Arkham is an external link to the running independent application. Production serves no legacy login, session, player, or Action Cable routes. Development and test still load those routes.

## Verified Hetzner baseline

Read-only inspection of `harvj` (SSH alias for `admin@88.99.245.24`) found:

- `caddy.service` runs `/usr/bin/caddy` v2.11.1 with `/etc/caddy/Caddyfile`. The binary has no DNS provider module. The live file has an exact `arkham.radioactivita.com` site and other independent sites. Arkham returned HTTPS 200.
- `arkham.service` is owned by `deploy` and runs under `/var/www/arkham/current`. Its upstream is `unix//var/www/arkham/shared/tmp/sockets/puma.sock`. Keep its complete Caddy block, including static files and headers.
- `postgresql@16-main.service` listens on loopback 5432 and supports TCP SCRAM. Port 3012 was clear at inspection and is reserved here for Remote Gaming. Recheck at deploy time.
- All five production names and a test subdomain resolved to `88.99.245.24`. Check A and AAAA results again before enabling Caddy.
- Ruby 3.4.8 is installed for `deploy` under its home directory. The admin shell has no Ruby or Node on PATH. This deployment uses an app-specific runtime under `/opt/remote-gaming` and a dedicated OS account. Arkham's Ruby remains in its own deployment.

## 1. Publish and transfer the reviewed commit

Run locally from the repository after authorizing the push. Set `release` to the full reviewed P1.0 commit SHA if your HEAD has moved. `git archive` packages tracked files at that SHA and excludes local edits, untracked files, and database artifacts.

```bash
release=$(git rev-parse HEAD)
git show --stat "$release"
git push origin "$release:refs/heads/main"
git archive --format=tar.gz --output="/tmp/remote-gaming-$release.tar.gz" "$release"
scp "/tmp/remote-gaming-$release.tar.gz" harvj:
ssh harvj
```

## 2. Prepare and build the release

Use Bash on Hetzner. Reuse the same value of `release` on the server. Confirm the service, database, and role names are free on first deployment. Existing Remote Gaming deployments should use the update procedure below.

```bash
set -euo pipefail
release=PASTE_REVIEWED_FULL_COMMIT_SHA
[[ $release =~ ^[a-f0-9]{40}$ ]]
base=/var/www/remote-gaming
stage="$base/releases/$release"
ss -H -ltn 'sport = :3012'
systemctl cat remote-gaming.service || true
getent passwd remote_gaming || true
sudo -u postgres psql -X -c "SELECT rolname FROM pg_roles WHERE rolname = 'remote_gaming'"
sudo -u postgres psql -X -c "SELECT datname FROM pg_database WHERE datname = 'remote_gaming_production'"
```

Provision a trusted standalone Ruby **3.4.8** distribution under `/opt/remote-gaming/ruby`, including Bundler **4.0.6**, and a trusted Linux Node **22** distribution (22.12 or newer) under `/opt/remote-gaming/node`, including npm. Use verified upstream artifacts or an internal runtime build for this host's architecture. Install build tools and PostgreSQL client/development libraries if needed through the host's reviewed maintenance process. Keep both runtime prefixes root-owned and readable/executable by the service user. Confirm them before continuing:

```bash
export PATH=/opt/remote-gaming/ruby/bin:/opt/remote-gaming/node/bin:/usr/bin:/bin
ruby -v
bundle _4.0.6_ --version
node -v
npm --version
pg_restore --version

sudo useradd --system --user-group --create-home --home-dir /var/lib/remote-gaming \
  --shell /usr/sbin/nologin remote_gaming
sudo install -d -m 0755 "$base" "$base/releases" "$base/shared"
sudo install -d -o remote_gaming -g remote_gaming -m 0750 "$base/shared/storage"
sudo install -d -m 0755 /etc/remote-gaming
sudo mkdir "$stage"
sudo tar -xzf "$HOME/remote-gaming-$release.tar.gz" --no-same-owner -C "$stage"
sudo chown -R remote_gaming:remote_gaming "$stage"
sudo -u remote_gaming -H "$stage/deploy/build-release"
sudo chown -R root:root "$stage"
sudo install -d -o remote_gaming -g remote_gaming -m 0750 "$stage/tmp" "$stage/log"
sudo chown -R remote_gaming:remote_gaming "$stage/tmp"
sudo ln -s "$base/shared/storage" "$stage/storage"
sudo install -m 0644 "$stage/config/game_directory.yml" /etc/remote-gaming/game_directory.yml
sudo install -m 0600 "$stage/deploy/application.env.example" /etc/remote-gaming/application.env
```

The build uses the lockfiles and a temporary Rails signing key. The service reads its runtime environment separately. Generate a 32-byte hex database password and a separate 64-byte hex Rails secret with `openssl rand -hex 32` and `openssl rand -hex 64` in a secure session. Use the same database password in PostgreSQL and the root-owned environment file. Existing encrypted Rails credentials are optional for the directory. If a later release uses them, supply its matching key via the protected environment file.

## 3. Restore the immutable recovery artifact

Inspect privileged role instructions locally or in a restricted shell. The globals file contains role creation and attributes for legacy `deploy` and superuser `postgres`, including a legacy password verifier. Leave it archived. Verify these known SHA-256 values before restoring:

```bash
backup=/srv/backups/remote-gaming/linode-recovery
sudo sha256sum -c <<EOF_CHECKSUMS
f950e20fd4ad76c055a3d63923f73c196135a8b0fac3e893857f0ff3cce85bf5  $backup/gameng_production.dump
9350df4327547cdc7f7bbd1230949b0a003116b8ab86ce780c5a145e3a714247  $backup/postgresql_globals.sql
EOF_CHECKSUMS
sudo pg_restore --list "$backup/gameng_production.dump"
sudo -u postgres psql -X -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE remote_gaming LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
SET password_encryption = 'scram-sha-256';
\password remote_gaming
CREATE DATABASE remote_gaming_production OWNER remote_gaming TEMPLATE template0;
REVOKE CONNECT, TEMPORARY ON DATABASE remote_gaming_production FROM PUBLIC;
SQL
sudoedit /etc/remote-gaming/application.env

sudo sh -c 'cat "$1" | runuser -u postgres -- pg_restore --dbname=remote_gaming_production --role=remote_gaming --no-owner --no-privileges --single-transaction --exit-on-error' sh "$backup/gameng_production.dump"
sudo -u postgres psql -X -d remote_gaming_production -c "
  SELECT (SELECT count(*) FROM users) AS users,
         (SELECT count(*) FROM game_sessions) AS sessions,
         (SELECT count(*) FROM pg_tables WHERE schemaname='public') AS tables;"
```

Expect **16 users, 104 sessions, and 14 tables**. The dump uses PostgreSQL 12.2 custom format. A fresh local PostgreSQL 14 restore matched those counts and the three migrations below ran against it. Hetzner's PostgreSQL 16 restore remains a manual gate. Keep both original files under restricted access and retain an off-host copy. If a restore fails, inspect the error and establish that the dedicated target is empty before retrying. Use a fresh dedicated database if there is any uncertainty.

Run Rails tasks as the service account using the same EnvironmentFile as Puma. Run the fingerprint SQL as database administrator with output stored under your private home directory. This checks all 12 historical payload tables and their sequence values. Row hashes include historical IDs, relationship columns, and timestamps. The comparison excludes Rails migration metadata and the two new columns.

```bash
umask 077
db=remote_gaming_production
audit=$(mktemp -d "$HOME/remote-gaming-audit.XXXXXX")
fingerprint() {
  sudo -u postgres psql -XqAt -d "$db" < "$stage/deploy/recovery-integrity.sql"
}
rg_task() {
  sudo systemd-run --quiet --wait --collect --pty \
    -p User=remote_gaming -p Group=remote_gaming \
    -p "WorkingDirectory=$stage" -p EnvironmentFile=/etc/remote-gaming/application.env \
    /opt/remote-gaming/ruby/bin/bundle exec rails "$@"
}
fingerprint > "$audit/before"
rg_task runner 'abort "Unexpected database or role" unless Game.connection.select_rows("SELECT current_database(), current_user") == [["remote_gaming_production", "remote_gaming"]]; GameDirectory.new'
rg_task db:migrate
rg_task db:migrate:status
rg_task zeitwerk:check
fingerprint > "$audit/after"
diff -u "$audit/before" "$audit/after"
sudo -u postgres psql -X -d "$db" -c 'SELECT id, key, slug FROM games ORDER BY id;'
```

Expected migrations add nullable `games.slug`, its unique index, and nullable `players.removed_at`, then fill missing slugs for `modern_art` and `pandemic` in place. Historical game IDs 1 and 2 should remain assigned to `modern_art` and `pandemic`, with slugs `modernart` and `pandemic`. Older migration versions appear as `NO FILE` because Rails 8 starts from their already-restored schema. All three local March 2026 migrations should be `up`. Halt on any fingerprint discrepancy. Never use `db:setup`, `db:schema:load`, `db:seed`, or `db:reset` on a recovered or live database.

## 4. Start Puma and verify it on loopback

```bash
sudo install -m 0644 "$stage/deploy/remote-gaming.service" /etc/systemd/system/remote-gaming.service
sudo ln -s "$stage" "$base/current"
sudo systemctl daemon-reload
sudo systemctl enable --now remote-gaming.service
sudo systemctl --no-pager status remote-gaming.service
PUMA_URL=http://127.0.0.1:3012 "$stage/deploy/smoke"
sudo journalctl -u remote-gaming.service -n 75 --no-pager
```

The service binds only to loopback, logs to the journal, and retries failure up to five starts within two minutes. Rails trusts the edge for TLS termination and sets HTTPS-related response protections. `/up` checks Rails boot, and `/ready` also queries the restored primary database. The smoke test checks both hostnames, game pages, compiled assets, and that legacy gameplay endpoints are outside the public production routes.

## 5. Review and apply the Caddy change

Start with `Caddyfile.named`. Caddy can obtain individual HTTPS certificates for the four known names using its standard ACME challenges. Preserve the existing Arkham site and every other Caddy block. Capture service PIDs and representative HTTPS responses before and after the cutover. This first integration requires a reviewed **graceful Caddy reload**. Rollouts behind the installed proxy require only restarting Remote Gaming.

```bash
systemctl show -p Id -p MainPID caddy arkham auth muzeum-web muzeum-worker postgresql@16-main
curl -fsSL -o /dev/null -w 'Arkham %{http_code}\n' https://arkham.radioactivita.com/
proxy_backup="/etc/caddy/Caddyfile.before-remote-gaming-$(date -u +%Y%m%dT%H%M%SZ)"
sudo cp -a /etc/caddy/Caddyfile "$proxy_backup"
sudo install -d -m 0755 /etc/caddy/remote-gaming
sudo install -m 0644 "$stage/deploy/Caddyfile.named" /etc/caddy/remote-gaming/sites.caddy
sudo cp -a "$proxy_backup" /etc/caddy/Caddyfile.remote-gaming.candidate
printf '\nimport /etc/caddy/remote-gaming/sites.caddy\n' |
  sudo tee -a /etc/caddy/Caddyfile.remote-gaming.candidate >/dev/null
sudo diff -u "$proxy_backup" /etc/caddy/Caddyfile.remote-gaming.candidate || test "$?" = 1
sudo -u caddy /usr/bin/caddy adapt --adapter caddyfile --config /etc/caddy/Caddyfile.remote-gaming.candidate |
  python3 "$stage/deploy/check-caddy-routing.py"
sudo -u caddy /usr/bin/caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile.remote-gaming.candidate

# Execute after reviewing the diff and confirming DNS, Puma and Arkham baseline probes.
sudo cp -a /etc/caddy/Caddyfile.remote-gaming.candidate /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo journalctl -u caddy -n 75 --no-pager
"$stage/deploy/smoke"
systemctl show -p Id -p MainPID caddy arkham auth muzeum-web muzeum-worker postgresql@16-main
```

Check that the first visit from a browser loads Svelte and shows accessible headings, focus states, and the Arkham link. Confirm the four public hosts have valid certificates, Arkham still serves its own UI or login, and other baseline sites still respond. A PID change in an unrelated service warrants investigation.

### Wildcard HTTPS and adding games

Wildcard DNS is already present. `*.radioactivita.com` covers a single label and needs ACME DNS-01. The apex and the separate `gaming.harvj.com` hostname still use their individual certificates. For registry-only onboarding of new first-party subdomains, switch to `Caddyfile.wildcard` after establishing wildcard renewal. This candidate also retains the exact Arkham site. The wildcard path explicitly rejects Arkham if that request ever reaches the fallback. The adapted Caddy route checker accepts `--wildcard`.

The upstream `github.com/caddy-dns/namecheap` module supports DNS-01 via a custom Caddy build. Namecheap requires API access and an allowlisted public IPv4 for the issuer. Its DNS update API replaces the host record set, so export the zone and coordinate DNS changes while testing issuance and renewal. Stage with ACME's staging CA before issuing the live certificate. [Namecheap Caddy module](https://github.com/caddy-dns/namecheap), [Namecheap API access](https://www.namecheap.com/support/api/intro/), [Namecheap DNS replacement semantics](https://www.namecheap.com/support/api/methods/domains-dns/set-hosts/), [Caddy wildcard configuration](https://caddyserver.com/docs/caddyfile/patterns).

Keep the stock shared Caddy binary. One supported integration is an independently managed DNS-01 issuer that renews the wildcard PEM and installs it at the paths in `Caddyfile.wildcard`. Restrict the key to root and the Caddy service group and stage the updated pair before validating and gracefully reloading the shared Caddy config. The renewal job and its reload need approval in the wildcard rollout plan. Verify live certificate expiry, renewal monitoring, and rollback to the named config before switching. Run the same candidate adaptation and validation workflow with `--wildcard` on the checker and `WILDCARD_TLS=1 "$stage/deploy/smoke"` after cutover. A custom shared Caddy binary would require a separate reviewed upgrade plan with version and module pins, a staged build, regression checks for other sites, and a binary and config rollback.

Edit `/etc/remote-gaming/game_directory.yml` atomically to register a game. Use a single DNS label as the key, a title, a description, and a boolean `available`. An omitted destination defaults to the game subdomain. Supply an absolute HTTPS destination for independently deployed games. The app reads this file on requests, so a validated catalog update takes effect without a restart. P1.0 game subdomains serve status pages. Enable a playable link only after separately verifying the destination. With named certificates, adding a new first-party hostname also requires a Caddy site address and graceful reload. Adding a link to an independent HTTPS app requires only the registry edit.

The existing `games` records hold gameplay keys, slugs, and player limits. They have no descriptions, launch status, or external destinations. The separate catalog keeps external applications out of the historical gameplay tables. A future catalog table can import this YAML, keep optional references to `games.id`, enforce unique hostnames, and support audited publishing without recreating historical games.

## Updates, backups, and rollback

Stage later releases in new SHA directories using the transfer and build commands. Keep the original environment, registry, and shared storage. Back up the dedicated database before migration, record the previous release, and run the new release's migrations before switching only when they are compatible with the running release. For incompatible migrations, stop only Remote Gaming and plan a maintenance window.

```bash
previous=$(readlink -f "$base/current")
backup_dir=/srv/backups/remote-gaming/releases
snapshot="$backup_dir/remote_gaming_production-$(date -u +%Y%m%dT%H%M%SZ).dump"
sudo install -d -m 0700 "$backup_dir"
sudo bash -c 'umask 077; runuser -u postgres -- pg_dump --format=custom --dbname=remote_gaming_production > "$1.partial" && pg_restore --list "$1.partial" >/dev/null && mv "$1.partial" "$1"' bash "$snapshot"
sudo sha256sum "$snapshot"

# After migration and review. Both symlinks are on the same filesystem.
sudo ln -s "$stage" "$base/current.next"
sudo mv -Tf "$base/current.next" "$base/current"
sudo systemctl restart remote-gaming.service
PUMA_URL=http://127.0.0.1:3012 "$stage/deploy/smoke"
"$stage/deploy/smoke"
```

Keep encrypted off-host copies of database dumps, shared storage, environment material, and the directory registry with controlled retention. For a restore drill or database rollback, create a new dedicated database owned by `remote_gaming` using the restore procedure above with a new target name. Restore the chosen snapshot into it, run the appropriate release's migration and integrity checks there, and update only Remote Gaming's `DATABASE_URL` after verifying it. Keep the previous database and account for writes since the backup before switching. Back up and restore storage from the corresponding point in time if it contains application data.

For an application rollback with compatible schema, atomically repoint `current` to `$previous` using the symlink procedure above, restart only `remote-gaming.service`, and rerun the smoke tests. This release's migration is additive. Keep the slug assignments and retained data in place. For a first deployment rollback, revert the edge first using the preserved Caddyfile, then stop only Remote Gaming:

```bash
sudo -u caddy /usr/bin/caddy validate --adapter caddyfile --config "$proxy_backup"
sudo cp -a "$proxy_backup" /etc/caddy/Caddyfile
sudo systemctl reload caddy
curl -fsSL -o /dev/null -w 'Arkham %{http_code}\n' https://arkham.radioactivita.com/
sudo systemctl disable --now remote-gaming.service
```

For a later wildcard rollback, restore the saved named `sites.caddy`, validate the combined file, and gracefully reload Caddy. No application or PostgreSQL restart is required for the proxy rollback.
