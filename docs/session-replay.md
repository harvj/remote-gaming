# Modern Art replay and private branches

Open **Replay history** from a Modern Art table. The cursor addresses the recorded frame sequence. Checkpoints capture the state after an atomic gameplay command. Engine or observation frames between checkpoints show their recorded event alongside the last committed checkpoint. The viewer receives their own hand, other seats' hand sizes and the public paintings played so far. A completed checkpoint applies the existing Modern Art end-of-game hand visibility. No undealt cards or raw checkpoints go to the browser.

The physical timeline lists observations and their corrections separately. Replaying a point before a correction shows the original report as current. Once a correction appears, the original is marked superseded. Historical sessions without a complete supported checkpoint chain show an unavailable message.

## Staging

An authenticated real owner can branch from an active-season checkpoint in their own private experiment. The original frame chain stays immutable. A branch records the immediate parent, fork frame, current rule version and creator. We copy the checkpoint's state and replay prefix to separate rows within one transaction. The engine uses the copied history to enforce existing card-play, auction and turn rules. Previously dealt cards and recorded turn order are preserved. Later random deals are recorded in the branch as independent gameplay.

Each copied dummy seat has a new identity and starts without browser access. Issue a new code from the branch's live table. Source credentials and sessions continue to belong to the source table. Experimental branches remain private and outside ordinary statistics. From branch replay, **Compare with original fork** displays both public painting histories at the selected points, and **Original timeline** returns to the source replay.

The staging migration adds nullable lineage fields and a constraint requiring complete lineage on experimental branches. The deployment fingerprint excludes those additive fields when checking historical payloads. Staging needs the reviewed migration rollout before using the feature.

## Production

The default deployment continues to serve the public directory. Read-only replay can be enabled independently with `REMOTE_GAMING_PRODUCTION_REPLAY=1`, a dedicated Auth client at `https://gaming.harvj.com/auth/callback`, and the existing OIDC environment settings for that client. It has its own host-only cookie. The routes include the participant's replay library, replay reads, and OIDC session entry and logout. The route set excludes gameplay mutations, dummy access, Action Cable, and branch creation. Initial activation requires a separate production configuration and Auth registration review.

A future post-game What If feature would need its own simulation classification, authorization and creation policy. It would use completed, authorized sources and separate private histories with ordinary statistics excluded. P1.4 exposes no production simulation creation.
