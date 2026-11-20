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

The issuer setting selects OIDC and disables the legacy login POST. Keep the Caddy access gate. Leaving the variables unset retains the existing isolated staging-account flow, and private experiments remain unavailable in that mode. Local OIDC sessions last at most eight hours. Remote Gaming logout revokes its local session, including permissions on existing Cable connections, and clears the browser cookie. Auth has no advertised RP-initiated logout endpoint. The application logout is `DELETE https://modern-art.staging.radioactivita.com/logout` and returns to the local `/login`. No provider logout callback or post-logout redirect needs registration. Use the Auth account controls for provider-wide logout, client membership removal, or grant revocation. Removing membership at Auth blocks new Remote Gaming logins. To end existing Remote Gaming sessions immediately, revoke the affected `AuthLogin` rows in Remote Gaming through an approved operator change.

The Auth handoff must confirm the confidential staging client ID, registered callback, selected assurance policy, approved memberships, and secret delivery through the existing secret channel. Public discovery confirms the endpoint URLs only. It cannot verify client registration or policy. Keep the candidate unpublished and the deployed staging version unchanged until the registration and policy are verified and the dependency review has passed. Confirm actual ID-token claims and browser behavior in a live staging integration test after authorization. Use a password-only member, a voluntarily enrolled member, and a member of an unrelated high-assurance client. Confirm the low-assurance sign-in cannot acquire that client's grant. No provider configuration changed during implementation.

## Historical identity reconciliation

The application owner confirmed ownership of the recovered `jim` profile. The approved target is the existing Remote Gaming user ID **1**, with **83** player records. Preserve the user row, every player row, and all associated sessions and history. Approval of ownership does not establish the OIDC subject. The other 15 recovered profiles have no approved links. The recovery has no `radio` profile and the archived shared role establishes no identity association.

Ask the separate Auth operator to verify the owner's authentication using the registered staging client. Obtain an attestation for the exact signed response's `iss`, `sub`, and client audience after validation of signature, issuer, audience, nonce, and expiry. Record the approved evidence reference for that attestation and the owner's confirmation. Use a secure handoff for the subject and no raw token in a ticket, log, or shell history. Email and usernames are not proof of an OIDC subject. Keep the link pending until evidence is available.

After verifying profile ID 1 and its 83 player records on the isolated database, run the reconciliation helper with the approved staging application environment. Supply the verified subject and evidence reference through the approved operator environment.

```bash
RG_PROFILE_ID=1 RG_LINK_OPERATION=link bin/rails runner deploy/oidc-link-profile.rb
```

Set `RG_VERIFIED_SUBJECT` to the attested subject and `RG_EVIDENCE_REFERENCE` to the approved case. The same issuer, subject, profile, and action can be repeated safely. A conflicting subject requires separate review. To reverse the decision, use `RG_LINK_OPERATION=revoke` with the same profile and verified subject and a new approved evidence reference. Revocation retains the association and decision history, disables login, and ends Remote Gaming logins for the link. An approved relink can reactivate the same pair. The helper writes only identity data and does not update user, player, session, or frame rows.

After migrating the disposable restore, run `bin/rails runner deploy/check-historical-sessions.rb` to verify that all 104 recovered sessions still render read-only for existing members. Compare the historical fingerprints using the deployment runbook.


## Private experiments and rollback

Create a private experiment from the Modern Art lobby. The creator joins as captain, can issue one-time codes for dummy seats before play begins, and can rotate or revoke them at any stage. Enter a code through the dedicated access form in a separate browser profile. Codes are displayed on a non-cacheable page with no third-party scripts, travel in the POST body, and are consumed once. The code and the issued browser access expire eight hours after issuance. Rotation and revocation invalidate previous browser access and prevent further Cable delivery. A dummy's local profile is an internal seat identity with no password, email, or Auth account.

Private tables are listed separately for their creator and excluded from ordinary statistics and badge inputs. Frame checkpoints capture experiment ownership and seat kind, and attributed events record whether the actor was a person or dummy. Physical reports and corrections continue to use existing captain rules.

For a later authorized staging rollout, run `cap staging deploy:check` and then `APPROVED_COMMIT=REVIEWED_SHA ALLOW_MIGRATIONS=1 bundle exec cap staging deploy` with the isolated Auth variables still unset. Review the backup and historical fingerprints before enabling the Auth environment values and restarting only the staging service.

The Capistrano compatibility gate blocks rollback to a release recorded before the new migrations. Keep the pre-migration backup and exact historical fingerprint receipts. Use a compatible forward fix if needed. Do not run an older app against experimental data since its visibility rules predate experiments.

P1.4 should build viewer-specific replay projections from immutable snapshots, preserving the experimental flag and dummy attribution. Branch from explicitly supported checkpoints and provision fresh seat credentials independently from the parent.

## Owner-only staging cutover

Import the matching root-only client handoff and owner attestation into the staging service environment. Set `REMOTE_GAMING_OIDC_OWNER_SUBJECT` to the protected subject and `REMOTE_GAMING_OIDC_OWNER_EVIDENCE` to the attestation reference. The first successful signed owner callback links the approved subject to `jim` ID 1 after checking the historical player count. A revoked or conflicting link requires the operator reconciliation procedure. Staging also validates the owner allowlist on use of each local OIDC session.

The staging directory and Pandemic host redirect to protected paths on the Modern Art host. This lets the three entry points use the exact registered callback and a single host-only Secure, HttpOnly, SameSite=Lax cookie. Dummy access remains on the Modern Art host and works only for the issued seat. Local logout ends the Remote Gaming session and offers a link to sign in again through Auth.

Keep edge Basic Auth during verification. Run `deploy/staging-smoke` from loopback with `PUMA_URL` or through the protected edge with `STAGING_NETRC`. After a verified owner browser callback and access-control checks, use the shared Caddy lock for the staging-only edge cutover. Then run the same smoke script against public HTTPS with neither variable. If restoring a release with legacy staging access, restore the Basic Auth gate first.
