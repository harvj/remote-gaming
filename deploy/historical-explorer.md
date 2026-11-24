# Modern Art historical explorer

`REMOTE_GAMING_HISTORICAL_EXPLORER=1` enables the explorer. Production uses `https://modern-art.radioactivita.com/`. Staging uses `/history` on its Modern Art host and keeps the owner lobby at `/`. The environments have separate service configuration. A disabled feature or invalid approval map publishes no records.

Set `REMOTE_GAMING_PUBLIC_HISTORICAL_SESSIONS` to a JSON object keyed by explicitly approved session identifier. Each value is an array of approved fields. For example, a disposable staging fixture may use `{"explorer-fixture":["names","badges","final_cash","hands","history"]}`.

| Approval | Public fields |
| --- | --- |
| Session identifier | Completion date, seat labels and recorded winner status |
| `names` | Player display names |
| `badges` | Role flags, badge values and historical badge dates. Requires `names`. |
| `final_cash` | Recorded final totals and corresponding score badge |
| `hands` | Card faces and counts from recorded completed hands |
| `history` | Recorded played paintings and available action, observation and correction labels with frame references |

The public projection never serves an in-progress frame, the undealt deck, discarded and unplayed cards, raw observation or correction payloads, internal account identifiers, or private profile data. It does not supply an interactive replay endpoint. Recorded frame provenance and private staging replay stay available through their existing authorization paths. Only ordinary completed Modern Art sessions qualify. Private, branched, practice, digital testing and dummy-seat tables are excluded even when named in the map.

Before activation, review the exact production allowlist and approved fields, verify DNS and TLS for the new hostname, test against the signed Shell publication, and check that public gameplay, practice, experiment and invitation routes stay closed. Leave the production opt-in disabled until that review is approved. Remove a session's entry and reload the application configuration to unpublish it. Public explorer responses are marked `no-store`.
