# P1.2 private Modern Art staging

This procedure installs a separate systemd service at `127.0.0.1:3013` with its own application account, release directory, signing key, database and database role. The account allowlist contains three disposable staging players. Recovered users remain in the copied database for integrity checks and cannot sign in through staging. Auth integration and browser-controlled dummy identities belong to P1.3. This rehearsal requires no Auth repository, service or database changes.

Read-only inspection found free port 3013, installed application Ruby and Node under `/opt/remote-gaming`, and `staging.radioactivita.com` resolving to `88.99.245.24`. The current Caddyfile imports individual files from `/etc/caddy/sites`. Recheck before any authorized install. Use Bash throughout and stop on unexpected output. These commands require separate deployment authorization.

## Transfer and build

From the workspace, set `release` to the reviewed staging commit and transfer a tracked archive.

```bash
set -euo pipefail
release=REVIEWED_STAGING_COMMIT_SHA
git archive --format=tar.gz -o "/tmp/remote-gaming-staging-$release.tar.gz" "$release"
shasum -a 256 "/tmp/remote-gaming-staging-$release.tar.gz"
scp "/tmp/remote-gaming-staging-$release.tar.gz" harvj:
ssh harvj
```

On Hetzner, set the same SHA and compare the transferred digest with the local digest. Confirm absent service, role, DB, and path. Check that the loopback address and port are free.

```bash
set -euo pipefail
release=REVIEWED_STAGING_COMMIT_SHA
[[ $release =~ ^[a-f0-9]{40}$ ]]
base=/var/www/remote-gaming-staging
stage="$base/releases/$release"
sha256sum "$HOME/remote-gaming-staging-$release.tar.gz"
test -z "$(ss -H -ltn 'sport = :3013')"
if getent passwd remote_gaming_staging; then exit 1; fi
test -z "$(sudo -u postgres psql -XAtc "SELECT rolname FROM pg_roles WHERE rolname='remote_gaming_staging'")"
test -z "$(sudo -u postgres psql -XAtc "SELECT datname FROM pg_database WHERE datname='remote_gaming_staging'")"
sudo test ! -e "$base"
sudo test ! -e /etc/remote-gaming-staging
sudo test ! -e /etc/systemd/system/remote-gaming-staging.service
sudo useradd --system --user-group --create-home --home-dir /var/lib/remote-gaming-staging \
  --shell /usr/sbin/nologin remote_gaming_staging
sudo install -d -m 0755 "$base" "$base/releases" "$base/shared" /etc/remote-gaming-staging
sudo install -d -m 0755 -o remote_gaming_staging -g remote_gaming_staging "$stage"
sudo install -d -m 0750 -o remote_gaming_staging -g remote_gaming_staging "$base/shared/storage"
sudo tar -xzf "$HOME/remote-gaming-staging-$release.tar.gz" --no-same-owner -C "$stage"
sudo chown -R remote_gaming_staging:remote_gaming_staging "$stage"
sudo -H -u remote_gaming_staging "$stage/deploy/build-release"
sudo chown -R root:root "$stage"
sudo install -d -m 0750 -o remote_gaming_staging -g remote_gaming_staging "$stage/tmp" "$stage/log"
sudo chown -R remote_gaming_staging:remote_gaming_staging "$stage/tmp"
sudo ln -s "$base/shared/storage" "$stage/storage"
```

## Database and service

Create the dedicated role and database. Use `openssl rand -hex 32` for the database password and `openssl rand -hex 64` for the independent Rails signing key. Set the password in an interactive `sudo -u postgres psql -X` session using `SET password_encryption = 'scram-sha-256';` and `\password remote_gaming_staging`. Use `sudoedit` to fill in the two placeholders in the protected environment file. Keep those credentials separate from the later edge and gameplay credentials.

```bash
sudo -u postgres psql -X -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE remote_gaming_staging LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE DATABASE remote_gaming_staging OWNER remote_gaming_staging TEMPLATE template0;
REVOKE ALL ON DATABASE remote_gaming_staging FROM PUBLIC;
SQL
sudo install -m 0600 "$stage/deploy/staging.env.example" /etc/remote-gaming-staging/application.env
sudoedit /etc/remote-gaming-staging/application.env

backup=/srv/backups/remote-gaming/linode-recovery
sudo sha256sum -c <<CHECKSUMS
f950e20fd4ad76c055a3d63923f73c196135a8b0fac3e893857f0ff3cce85bf5  $backup/gameng_production.dump
9350df4327547cdc7f7bbd1230949b0a003116b8ab86ce780c5a145e3a714247  $backup/postgresql_globals.sql
CHECKSUMS
sudo bash -euo pipefail -c 'cat "$1" | runuser -u postgres -- pg_restore -d remote_gaming_staging --role=remote_gaming_staging --no-owner --no-privileges --single-transaction --exit-on-error' bash "$backup/gameng_production.dump"

umask 077
audit=$(mktemp -d "$HOME/remote-gaming-staging.XXXXXX")
rg_stage() {
  sudo systemd-run --quiet --wait --collect --pipe \
    -p User=remote_gaming_staging -p Group=remote_gaming_staging \
    -p "WorkingDirectory=$stage" -p EnvironmentFile=/etc/remote-gaming-staging/application.env \
    /opt/remote-gaming/ruby/bin/bundle exec rails "$@"
}
sudo -u postgres psql -XqAt -d remote_gaming_staging < "$stage/deploy/recovery-integrity.sql" > "$audit/before"
rg_stage runner 'abort "Wrong database or role" unless User.connection.select_rows("SELECT current_database(), current_user") == [["remote_gaming_staging", "remote_gaming_staging"]]'
rg_stage db:migrate
rg_stage db:migrate:status
sudo -u postgres psql -XqAt -d remote_gaming_staging < "$stage/deploy/recovery-integrity.sql" > "$audit/after"
diff -u "$audit/before" "$audit/after"
rg_stage runner deploy/staging-accounts.rb > "$audit/staging-accounts"
sudo install -m 0644 "$stage/deploy/remote-gaming-staging.service" /etc/systemd/system/remote-gaming-staging.service
sudo ln -s "$stage" "$base/current"
sudo systemd-analyze verify /etc/systemd/system/remote-gaming-staging.service
sudo systemctl daemon-reload
sudo systemctl enable --now remote-gaming-staging.service
for attempt in {1..20}; do
  if curl -fsS -H 'Host: staging.radioactivita.com' http://127.0.0.1:3013/up >/dev/null 2>&1; then break; fi
  sleep 1
done
PUMA_URL=http://127.0.0.1:3013 "$stage/deploy/staging-smoke"
```

The verified original archive is the pre-migration recovery source. The copied database is disposable. The globals SQL stays archived. Compare fingerprints before adding staging accounts. Keep the generated staging-password file private and deliver individual credentials through an approved channel. The Rails environment rejects other database names and roles at startup. Puma stays single-process so its async Action Cable adapter sees all gameplay broadcasts.

## Review and activate the HTTPS edge

Verify current DNS, live Caddy configuration versus the on-disk config, and baseline responses and service start identities for existing sites including Arkham. Inspect active upstream connections and wait for a quiet window. A Caddy reload can close existing WebSockets. The reviewed change is one additional import and a dedicated staging site with Basic authentication on every path, including assets and `/cable`. The site obtains its own named certificate through Caddy's normal HTTPS configuration.

Use `/usr/bin/caddy hash-password` interactively for a new, high-entropy edge password and record the bcrypt output. Populate a single line `staging_operator BCRYPT_HASH` via `sudoedit`. Caddy strips the Basic authorization header before proxying. Separate browser profiles should sign in to the edge first, then use different Rails staging accounts.

```bash
sudo install -d -m 0750 -o root -g caddy /etc/caddy/remote-gaming-staging
sudo install -m 0640 -o root -g caddy /dev/null /etc/caddy/remote-gaming-staging/credentials.caddy
sudoedit /etc/caddy/remote-gaming-staging/credentials.caddy
sudo test ! -e /etc/caddy/sites/remote-gaming-staging.caddy
sudo install -m 0644 "$stage/deploy/Caddyfile.staging" /etc/caddy/sites/remote-gaming-staging.caddy
saved="/etc/caddy/Caddyfile.before-rg-staging-$(date -u +%Y%m%dT%H%M%SZ)"
sudo cp -a /etc/caddy/Caddyfile "$saved"
sudo cp -a "$saved" /etc/caddy/Caddyfile.rg-staging.candidate
printf '\nimport sites/remote-gaming-staging.caddy\n' | sudo tee -a /etc/caddy/Caddyfile.rg-staging.candidate >/dev/null
sudo diff -u "$saved" /etc/caddy/Caddyfile.rg-staging.candidate || test "$?" = 1
sudo -u caddy /usr/bin/caddy adapt --adapter caddyfile --config /etc/caddy/Caddyfile.rg-staging.candidate |
  python3 "$stage/deploy/check-caddy-routing.py" --staging
sudo -u caddy /usr/bin/caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile.rg-staging.candidate

# After separate authorization, live config comparison and quiet-window checks.
sudo cmp "$saved" /etc/caddy/Caddyfile
sudo cp -a /etc/caddy/Caddyfile.rg-staging.candidate /etc/caddy/.Caddyfile.rg-staging.next
sudo mv -Tf /etc/caddy/.Caddyfile.rg-staging.next /etc/caddy/Caddyfile
sudo systemctl reload caddy

# Point to a private netrc containing: machine staging.radioactivita.com login staging_operator password EDGE_PASSWORD
STAGING_NETRC="$audit/edge.netrc" "$stage/deploy/staging-smoke"
```

The edge smoke checks every required auth boundary over trusted HTTPS before any gameplay. In three independent profiles, reach `https://staging.radioactivita.com/`, sign in with the distinct staging accounts, create and share a private staging game URL and complete all four seasons. Verify the waiting roster and turn changes without manual refresh, same-origin WSS connection and reconnect, rejected wrong-player actions, captain notes and corrections, final scores, and server-side replay equality. Confirm the existing application responses and PIDs against the baseline.

## Rollback and subsequent releases

If the reload rejects the change, restore the saved on-disk Caddyfile immediately. To remove working staging access, compare the current file against the backup. If other changes occurred since cutover, stage a candidate that removes only the staging import. Validate the rollback candidate and reload Caddy in an approved quiet window. Then stop only the staging app.

```bash
# Use this form only if the current shared file is still the approved staging candidate.
sudo cmp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.rg-staging.candidate
sudo -u caddy /usr/bin/caddy validate --adapter caddyfile --config "$saved"
sudo cp -a "$saved" /etc/caddy/.Caddyfile.rg-staging.rollback
sudo mv -Tf /etc/caddy/.Caddyfile.rg-staging.rollback /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl disable --now remote-gaming-staging.service
```

Keep the original recovery files, staging database and previous release for investigation. For a staging-only code rollback, atomically repoint the staging `current` symlink to a compatible release, restart only `remote-gaming-staging.service`, and rerun the smoke and browser checks. Keep the staging edge blocked if the selected release lacks the staging guard. Later rebuilds should verify a fresh disposable restore from the original archive. Public hostnames and the live production role and database require no changes for this procedure.

## Local rehearsal

The PostgreSQL 16 migration matched all historical table and sequence fingerprints. The Rails suite completed a full three-player Modern Art game, including a captain report and correction, final scores and deterministic replay. A separate local production-mode rehearsal verified authenticated HTTPS through Caddy 2.11.1 and live Action Cable updates, joining, starting and reconnecting across three browser profiles. The local proxy used an internal certificate and a loopback port.

The candidate adapted against a live Hetzner Caddyfile read, preserving the existing Remote Gaming and Arkham routes. The production Remote Gaming database grants connect and other database privileges only to its own role. Named public certificate issuance, systemd activation on Hetzner, and the hosted browser playthrough are pending the authorized staging deployment.
