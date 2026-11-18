# Remote Gaming roadmap

## P1.3 — Canonical identity reconciliation and private dummy-player sessions

### Auth and reconciliation

- Use Auth email and password for real people through OIDC. An unenrolled Remote Gaming member can sign in with a password. An enrolled member uses their voluntary second factor. Preserve the assurance policies of other clients and sensitive Auth operations.
- Map the stable Auth issuer and subject to a Remote Gaming profile with an audited reconciliation process. Inventory all 16 recovered users and preserve each local profile ID, player affiliation, and historical association. Keep uncertain matches pending.
- Investigate `jim` and `radio` using trusted account evidence and owner confirmation. If evidence confirms a shared canonical identity, preserve both historical attributions and establish an explicit profile-link policy before changing access. Record the evidence and authorization for each decision.
- Replace independent real-user password sign-in after verified recovery and reconciliation. Keep Auth membership and permissions application-specific. Use separate application databases, credentials, and deployment lifecycles.

### Private experimental sessions

- Allow authorized real users to create private experiments outside the public lobby. Persist the session purpose and carry it through frame history, replay, and analytical projections.
- Issue expiring, revocable browser access scoped to one dummy player in one experiment. Support separate browser profiles and incognito windows without email accounts. Dummy players cannot become Auth accounts, use real-person sessions, or inherit access to other tables.
- Keep gameplay, authorized table-captain observations, and the resulting history available inside the experiment. Exclude experiments from ordinary leaderboards and aggregates by default.

### Verification

Test identity linking and conflicts, historical memberships, Remote Gaming-only and multi-application users, voluntary MFA, cross-application assurance, dummy credential expiry and revocation, hidden hands, isolated multi-browser gameplay, and statistical separation.

## P1.4 — Frame-by-frame replay and experimental branching

- Add stepwise forward and backward replay for authorized viewers of completed and in-progress sessions. Build viewer-specific projections from ordered frames and retain hidden-information rules at each replay position.
- Create private branches from supported deterministic checkpoints. Record the parent session, fork frame, rule version, and provenance. Keep the source's state and frames intact and give branches independent gameplay and durable frame histories.
- Show branch lineage and classify branches as experiments in queries, projections, and statistics. Clearly mark legacy sessions with incomplete replay data.
- Test cursor stability, deterministic reconstruction, fork isolation, independent continuation, hidden-information boundaries, and ordinary-statistics exclusion.

Production activation and any reconciliation involving real accounts require separate authorization. Preserve the existing recovery artifacts and historical records.
