# P1.3 identity and private experiments

P1.3 keeps the production directory and its gameplay route gate. Test the release on private staging with a disposable restored database before requesting any production activation.

## Auth registration and cutover

In the separate Auth project, review and register a distinct confidential staging client. Use client authentication `client_secret_basic`, Authorization Code, S256 PKCE, the `openid` scope, and the exact redirect URI `https://modern-art.staging.radioactivita.com/auth/callback`. Keep the staging client audience unique. Do not register wildcard callbacks or request refresh tokens. Approve active memberships in this client for the verified test accounts only.

Set Auth's `AUTH_REMOTE_GAMING_CLIENT_ID` to this exact registry ID on a release that implements the documented application-specific assurance policy. That policy allows password assurance for an unenrolled member and prompts for MFA for an enrolled member. Preserve `AUTH_MFA_REQUIRED_CLIENT_IDS` and keep high-assurance registrations independent. If Auth needs simultaneous optional-assurance registrations for staging and production, review support for a list of eligible IDs in the Auth project before activating the second client. This consumer requires an RS256 ID token with the exact issuer and sole audience, subject, nonce, expiry, issued-at time, and either `urn:harvj:assurance:password` or `urn:harvj:assurance:mfa`. Its local session carries the achieved assurance and does not grant access to another Auth client.

Set these Remote Gaming process variables in the independent stage environment after the additive migrations are applied and the approved profiles are linked:

```dotenv
REMOTE_GAMING_OIDC_ISSUER=https://auth.harvj.com
REMOTE_GAMING_OIDC_CLIENT_ID=APPROVED_STAGING_ID
REMOTE_GAMING_OIDC_CLIENT_SECRET=PRIVATE_STAGING_CLIENT_SECRET
REMOTE_GAMING_OIDC_REDIRECT_URI=https://modern-art.staging.radioactivita.com/auth/callback
```

The issuer setting selects OIDC and disables the legacy login POST. Keep the Caddy access gate. Leaving the variables unset retains the existing isolated staging-account flow, and private experiments remain unavailable in that mode. Local OIDC sessions last at most eight hours. Remote Gaming logout revokes its local session, including permissions on existing Cable connections, and clears the browser cookie. Auth has no advertised RP-initiated logout endpoint. Use the Auth account controls for provider-wide logout, client membership removal, or grant revocation. Removing membership at Auth blocks new Remote Gaming logins. To end existing Remote Gaming sessions immediately, revoke the affected `AuthLogin` rows in Remote Gaming through an approved operator change.

Confirm provider registration, enabled memberships, actual ID-token claims, and browser behavior in a live staging integration test. Use a password-only member, a voluntarily enrolled member, and a member of an unrelated high-assurance client. Confirm the low-assurance sign-in cannot acquire that client's grant. No provider configuration changed during implementation.

## Historical identity reconciliation

The migration adds a one-to-one mapping from the stable issuer and subject to the existing integer Remote Gaming profile ID. Never match by username, email, role assignment, or display name alone. The operator must verify profile ownership and confirm the canonical subject through trusted Auth-side evidence. Record an approved case or ticket identifier as the evidence reference. Keep sensitive evidence in the approved record system. Avoid putting PII, credentials, or OAuth tokens in the reference.

For each approved association, run the following in the dedicated staging app environment first. For a new person, provision a distinct Remote Gaming profile through an approved operational workflow before linking it.

```bash
RG_PROFILE_ID=LOCAL_USER_ID RG_VERIFIED_SUBJECT=AUTH_SUBJECT RG_EVIDENCE_REFERENCE=APPROVAL_REFERENCE \
  bin/rails runner deploy/oidc-link-profile.rb
```

Recheck each of the 16 original profile IDs, their historical player rows, and their expected login status before a real-user cutover. After migrating the disposable restore, run `bin/rails runner deploy/check-historical-sessions.rb` to verify that each of the 104 recovered tables still renders read-only for an existing member. This check uses a read-only database transaction. Unresolved users remain preserved with no Auth association. The disposable recovery contains 16 users and 104 sessions. It contains the `jim` profile (ID 1, 83 player rows) and no row with username `radio`. The archive's Modern Art rules assign the same Tokyo role to `jim` and `radio`. The seed identifies `jim` by name and provides no canonical subject for either account. The shared role is insufficient evidence of identity equivalence. If later verified to represent one person, preserve both profile IDs and adjudicate access to the second historical attribution before changing the one-to-one policy.

## Private experiments and rollback

Create a private experiment from the Modern Art lobby. The creator joins as captain, can issue one-time codes for dummy seats before play begins, and can rotate or revoke them at any stage. Enter a code through the dedicated access form in a separate browser profile. Codes are displayed on a non-cacheable page with no third-party scripts, travel in the POST body, and are consumed once. The code and the issued browser access expire eight hours after issuance. Rotation and revocation invalidate previous browser access and prevent further Cable delivery. A dummy's local profile is an internal seat identity with no password, email, or Auth account.

Private tables are listed separately for their creator and excluded from ordinary statistics and badge inputs. Frame checkpoints capture experiment ownership and seat kind, and attributed events record whether the actor was a person or dummy. Physical reports and corrections continue to use existing captain rules.

For a later authorized staging rollout, run `cap staging deploy:check` and then `APPROVED_COMMIT=REVIEWED_SHA ALLOW_MIGRATIONS=1 bundle exec cap staging deploy` with the isolated Auth variables still unset. Review the backup and historical fingerprints before enabling the Auth environment values and restarting only the staging service.

The Capistrano compatibility gate blocks rollback to a release recorded before the new migrations. Keep the pre-migration backup and exact historical fingerprint receipts. Use a compatible forward fix if needed. Do not run an older app against experimental data since its visibility rules predate experiments.

P1.4 should build viewer-specific replay projections from immutable snapshots, preserving the experimental flag and dummy attribution. Branch from explicitly supported checkpoints and provision fresh seat credentials independently from the parent.
