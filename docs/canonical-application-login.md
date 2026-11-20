# Remote Gaming application sign-in

The public landing pages are usable without a local or Auth session. **Log in** enters the current host’s `/login`. The sign-in origin is selected before writing browser state.

| Environment | Entry hostnames | Registered callback |
| --- | --- | --- |
| Production | `radioactivita.com`, `gaming.harvj.com` | `https://gaming.harvj.com/auth/callback` |
| Private staging | `staging.radioactivita.com`, `modern-art.staging.radioactivita.com`, `pandemic.staging.radioactivita.com` | `https://modern-art.staging.radioactivita.com/auth/callback` |

Each environment needs its own enabled first-party confidential client at `https://auth.harvj.com`. Auth should map the exact client ID to `remote-gaming` presentation and the application entry path `/login`. The application needs the independently approved client ID, secret and exact callback. The public Modern Art and Pandemic status hosts also use the production sign-in origin. The production alias enters the canonical host before state creation and uses its host-only application session. Staging aliases enter the same independently isolated staging origin. Access to private staging is restricted to the attested owner.

The consumer uses OpenID Connect Authorization Code with PKCE S256, query response mode (the code-flow default), `openid`, and `client_secret_basic`. It checks trusted HTTPS discovery endpoints, RS256 ID-token signatures, exact issuer and audience, nonce, issue and expiry times, and the approved password or MFA assurance claim. There are no theme parameters. When Auth requires credentials or MFA, Auth owns those screens.

Login attempts are stored in PostgreSQL and bound to a random browser-session value. Valid callbacks consume the matching transaction once. Successful sign-in rotates the browser session, so any sibling transaction from the previous browser binding must be started again. A callback error is terminal and shows an explicit retry. The local session is bounded by the approved `openid` access token lifetime, up to five minutes. The token is encrypted at rest and never placed in the browser cookie. An active introspection result is cached for up to 20 seconds per process. After that window protected access fails closed if revalidation is unavailable. Logout removes local access before attempting revocation through Auth. No refresh token or offline scope is requested.

Public replay, gameplay and invitation sending retain their existing gates. Administrative access still requires the separate approved production owner attestation and local audit record. See the [Auth handoff](auth-p15-handoff.md).

This release adds the claim table and the login-attempt and grant-storage migration. Pre-migration backups and historical fingerprint verification remain required. Sessions from earlier releases require a fresh sign-in after deployment. Ordinary Capistrano rollback across the changed ledger is blocked.

## Production owner activation

An already attested production owner can complete the first production login with `REMOTE_GAMING_PRODUCTION_OWNER_BOOTSTRAP=1` and the approved production subject and evidence configured. Keep the administration and replay switches off. After signed-token and active-grant verification, the callback checks the subject against the production attestation and reconciles only the existing `jim` profile with 83 player associations. A conflicting or revoked identity blocks reconciliation. The callback records the existing identity audit decision in the same transaction as the link.

Verify the browser callback and recorded decision before removing the bootstrap switch and enabling historical administration. Production setup never uses the staging attestation. Routine sign-in uses the audited existing link.
