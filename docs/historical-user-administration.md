# Historical user administration

Administration uses the production database on `gaming.harvj.com`. After the production Auth client and owner link have been independently approved and configured, sign in at `https://gaming.harvj.com/admin/auth`. Set `REMOTE_GAMING_HISTORICAL_ADMIN=1` and configure `REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_SUBJECT` with the verified production subject and `REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_EVIDENCE` with the approved production evidence reference. The production confidential Auth client must use `https://gaming.harvj.com/auth/callback`. The local Auth identity for profile 1 (`jim`) must already be linked through audited reconciliation. Its latest identity decision must be a link with the configured evidence reference. Administration works with public replay and gameplay disabled. Ordinary players, anonymous browsers, and dummy-player sessions have no administrative access.

Staging has no historical administration routes and uses the non-delivering Action Mailer test adapter with deliveries disabled. Keep transactional email and invitation-provider credentials out of staging. Any future invitation integration must reject staging before contacting Auth or a mail provider.

The roster uses the 16 profile IDs present in the recovered production database, including profiles with no player associations. It displays the original ID, username, display name, and recorded player associations by game. Counts include removed player records on ordinary sessions and exclude private experiments. The Auth status distinguishes unlinked profiles, active links, and revoked links. Profile details show the reconciliation evidence and decision history.

For an unlinked profile, **Save proposal** records an address locally. **Prepare invitation** requires a separate checkbox confirmation of the current proposal. Changing the proposal clears that confirmation. A stale form cannot confirm a newer address. A previously linked profile requires identity reconciliation even if its link has been revoked.

Prepared claims have no delivery or expiry dates. The schema can record a provider reference, issuance, expiry, acceptance, and the corresponding audited identity-link decision. Those transitions have no routes or provider integration in this release. Approval of the Auth contract must precede any sending, delivery retries, or processing of acceptance. A future link must rely on verified Auth issuer and subject tied to the exact invitation and profile, with an auditable reconciliation decision. An email proposal or email match is insufficient evidence.

The additive migration creates an independent claim table and leaves recovered users, identity links, player associations, and game history intact. The recovery fingerprint continues to cover historical tables and excludes the new administrative table and sequence.

## Production rollout

The code can be deployed with `REMOTE_GAMING_HISTORICAL_ADMIN` unset and production replay disabled. The one pending migration, `20261120000002`, only creates the claim table, its indexes, foreign keys, and lifecycle constraints. Use the verified Capistrano backup and old-data fingerprints before enabling the migration. Once it runs, the previous release's ledger differs, and Capistrano rejects ordinary rollback to it. Retain the pre-migration dump. Use a reviewed forward fix or a separately approved restore into an isolated database and controlled cutover if recovery is required.

Activation depends on the [production Auth handoff](auth-p15-handoff.md). Deployment and activation are separate operator decisions.
