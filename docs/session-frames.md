# SessionFrame and Modern Art

The archived Rails 6/Vue application (master at `bacccbe`) and the Rails 8 rebuild (P1.0 at `8254349`) both record a mix of domain actions and phase transitions. Historically a frame recorded an action, optional acting and affected players, a polymorphic subject, the session phase, a timestamp, and a previous-frame pointer. The linked subject was a live row. Card deals captured the card and recipient, but frames did not capture all turn, card, player, or score mutations or freeze their historical values. Some invalid player actions could emit rows. The archived Modern Art Ruby engine and the rebuilt engine use the same deck composition, season deal counts, fifth-card season advancement, and single-double fallback. Vue used phase prompts, player buttons, hands grouped by artist and auction type, a pass action, and end-of-game scores and play history.

## Replay contract

Version 1 histories begin with a creation checkpoint. A session row lock serializes commands, and a unique, contiguous per-session sequence orders frames independently of timestamps. The existing semantic actions remain separate rows. Each gameplay command ends with a checkpoint containing the committed digital state and catalog values needed to interpret it. It records the outcomes of randomized operations (including exact card identities, recipients and turn order), so replay does not rerun random draws, re-evaluate past rules or read mutable tables. A checkpoint defines the visible committed state for the whole atomic command. Intermediate semantic rows describe steps within that command.

Replay reads archived JSON and rejects unknown formats or sequence gaps. Analytical consumers can query game key, frame kind, actor, affected player, subject, phase and recording time, then interpret versioned context and results. Full checkpoints contain hidden cards. Keep them server-side; only the authorized gameplay projection and captain observations are served. Action Cable sends session-scoped invalidations and clients fetch a freshly authorized view on changes and reconnect.

Legacy sessions keep their existing rows and links. Authorized former participants can read recorded state and recorded play history. Missing checkpoints and unrecorded physical actions make deterministic legacy replay unavailable. No replay or observation rows are fabricated for those sessions.

On an isolated restore of the Akamai dump, the migration kept historical table and sequence fingerprints identical. The participant view rendered all 95 Modern Art sessions and all nine Pandemic sessions. These sessions have no version 1 checkpoints or recorded physical observations.

## Physical observations

The first player to join a new session becomes the captain. A captain who leaves before play transfers the role to the earliest remaining player. A season checkpoint can serve as event context for a late report. Report and correction frames keep their author, recording time, optional occurrence time and context. A correction appends a replacement linked to the superseded frame. A tabletop projection follows the correction chain and retains original provenance in the source history. It describes coverage as incomplete because no reporting step is mandatory. Operational replay ignores physical reports.

A game engine opts into physical reporting by providing its own observation schema. Modern Art validates auction results, payments, and season scores against the selected checkpoint. These values are participant reports. Engine checkpoints remain the source for digitally verified state. P1.1 keeps the production directory-only route configuration in place.

## Local verification

Run `RAILS_ENV=test bin/rails db:schema:load` against an empty test database, then run `bundle exec rspec`. The SQL schema carries the PostgreSQL append-only trigger into fresh databases. The browser specs use headless Chrome, with optional `CHROME_BINARY` and `CHROMEDRIVER` paths for a matched local install. Use `db:migrate` on a separate restored copy for compatibility checks.

The full browser scenario uses three authenticated players, a live lobby, a reconnect, all four seasons, captain reports and end-of-game scoring. Separate backend scenarios compare standalone replay with the final committed state, exercise the single-double pass rule, and verify authorization and rollback independently of Svelte.
