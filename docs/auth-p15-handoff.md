# Auth handoff for Remote Gaming P1.5

## Production owner registration

Register a production OIDC confidential web client for Remote Gaming on the Auth issuer `https://auth.harvj.com`. Assign and return the exact client ID through the protected operator handoff. Keep the staging client, memberships, and assurance policy independent.

| Setting | Required value |
| --- | --- |
| App entry | `https://gaming.harvj.com/admin/auth` |
| Registered callback | `https://gaming.harvj.com/auth/callback` exactly |
| OIDC issuer | `https://auth.harvj.com` |
| Scope and flow | `openid`, authorization code, PKCE `S256` |
| Token endpoint client authentication | `client_secret_basic` |
| ID-token signature | `RS256`, verified against the issuer JWKS |
| ID-token claims | Exact registered client ID as the sole audience. Include stable `sub`, `iss`, `iat`, `exp`, echoed `nonce`, and `acr`. If `azp` is present, it must match the client ID. |
| Assurance | Preserve optional MFA. Remote Gaming accepts `urn:harvj:assurance:password` and `urn:harvj:assurance:mfa`. |
| Membership | The owner’s verified Auth account is the sole approved initial member. |

Confirm the stable production subject of that account for this client. Deliver the registration metadata, client secret, exact production subject, and an auditable production evidence reference through the approved protected operator channel. If browser interaction is necessary, the owner completes the normal Auth flow. Keep secrets, codes, and tokens out of this handoff and logs.

The Remote Gaming operator verifies production profile `jim`, ID 1, and its 83 player associations. Use the existing reconciliation operation against the production database with the attested issuer, subject, and evidence. The application requires an active identity on that profile and its latest link decision to match the configured production evidence. The Auth sign-in callback cannot create or replace a production link. A staging link is not production evidence.

Keep `REMOTE_GAMING_PRODUCTION_REPLAY` off. Once production owner registration and reconciliation have been verified and activation is approved, configure the production `REMOTE_GAMING_OIDC_*` client settings, `REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_SUBJECT`, and `REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_EVIDENCE`. Enable `REMOTE_GAMING_HISTORICAL_ADMIN=1` and verify owner sign-in, logout, expiry, and rejection of other accounts. Staging must have no invitation-provider or transactional email credentials.

## Future invitation integration

Return a separate contract for review before implementing invitation delivery. Define the Auth-side action, production client authorization, owner confirmation and idempotency, provider invitation identifier, issuance and expiry timestamps, retry and revocation semantics, and how Remote Gaming verifies acceptance and the stable Auth issuer and subject tied to that exact invitation. Specify which response or event carries the auditable acceptance evidence and how the consumer verifies it.

The consumer must fail closed in staging and correlate authenticated acceptance to the prepared production claim and its exact historical profile. It must reject expired, unrelated, or replayed evidence and keep the resulting link and decision auditable. A submitted or matching email never authorizes an account link. Current preparation stores only a draft and explicit confirmation. Delivery and acceptance processing remain disabled.
