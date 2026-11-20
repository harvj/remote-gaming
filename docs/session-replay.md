# Modern Art replay and private branches

Open **Replay history** from a Modern Art table. The cursor addresses the recorded frame sequence. The board shares its card faces with live play and uses the original artist names, colors, and auction icons. It shows the recorded season, turn, digital offers, played paintings, hand sizes, and the cards visible to the viewer at that point. Discarded cards follow the same visibility rule. Completed states use the existing Modern Art end-of-game hand visibility rule. Undealt cards and raw checkpoints stay on the server.

A checkpoint records the state after an atomic gameplay command. For an intermediate frame, replay starts with the preceding checkpoint and applies version 1 engine events in sequence. The event identifies the actual shuffled result, and the closing checkpoint supplies exact persisted values missing from the event payload, such as a card's deal timestamp. Replay only presents an intermediate state if the events reconcile with the complete closing checkpoint. Reports leave digital state unchanged.

A history without an initial checkpoint or an intact sequence is unavailable. An individual command interval is unavailable when it has unknown events, a missing closing checkpoint, or changes the events cannot explain. The cursor can still navigate to other supported frames and recorded checkpoints in an intact history.

Captain observations and corrections appear with their original event and recording times. Before a correction is recorded, the earlier report is current. Afterward, the earlier report is marked superseded. The board labels a sale when a single current report establishes it and keeps conflicting reports available in the history panel. Physical bids, money, valuations, and ownership transfers that were never reported remain unknown.

The local implementation and browser comparison are recorded in the [P1.4.1 tabletop review](design/p1.4.1-tabletop/README.md).

## Staging

An authenticated real owner can branch from an active-season checkpoint in their own private experiment. The original frame chain stays immutable. A branch records the immediate parent, fork frame, current rule version and creator. We copy the checkpoint's state and replay prefix to separate rows within one transaction. The engine uses the copied history to enforce existing card-play, auction and turn rules. Previously dealt cards and recorded turn order are preserved. Later random deals are recorded in the branch as independent gameplay.

Each copied dummy seat has a new identity and starts without browser access. Issue a new code from the branch's live table. Source credentials and sessions continue to belong to the source table. Experimental branches remain private and outside ordinary statistics. From branch replay, **Compare with original fork** displays both viewer-authorized tabletop states at the selected points, and **Original timeline** returns to the source replay.

The staging migration adds nullable lineage fields and a constraint requiring complete lineage on experimental branches. The deployment fingerprint excludes those additive fields when checking historical payloads. Staging needs the reviewed migration rollout before using the feature.

## Production

The default deployment continues to serve the public directory. Read-only replay can be enabled independently with `REMOTE_GAMING_PRODUCTION_REPLAY=1`, a dedicated Auth client at `https://gaming.harvj.com/auth/callback`, and the existing OIDC environment settings for that client. It has its own host-only cookie. The routes include the participant's replay library, replay reads, and OIDC session entry and logout. The route set excludes gameplay mutations, dummy access, Action Cable, and branch creation. Initial activation requires a separate production configuration and Auth registration review.

A future post-game What If feature would need its own simulation classification, authorization and creation policy. It would use completed, authorized sources and separate private histories with ordinary statistics excluded. P1.4 exposes no production simulation creation.
