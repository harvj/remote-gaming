# P1.4.1 Modern Art tabletop review

These local Chrome captures use the same scripted three-player fixture and the original Modern Art card catalog. The intermediate frame is a Karl Gitter Open play. The adjacent checkpoint has already advanced the turn to Morgan. The intermediate frame still shows Inez as the current seat.

| v0.4.0 | P1.4.1 |
| --- | --- |
| [Live table](before-live-desktop.png) | [Live table](live-desktop.png) |
| [Intermediate replay](before-replay-intermediate-desktop.png) | [Intermediate replay](replay-intermediate-desktop.png) |

[Replay at the matching live checkpoint](replay-checkpoint-desktop.png) · [Intermediate replay at 390 px](replay-intermediate-mobile.png)

The replay spec compares the face, artist color, icon, and zone between the live table and replay. It also verifies hidden opponents' hands, movement from hand to auction at the exact play frame, and a season transition. The four-season reconstruction test captures the database state immediately after each engine event and compares it with replay in randomized cursor order.

Local benchmark on a completed three-player game with 175 frames and 137 engine events

| Operation | Samples | p50 | p95 |
| --- | ---: | ---: | ---: |
| Reconstruction with frames in memory | 411 | 0.328 ms | 0.419 ms |
| PostgreSQL load, chain validation, reconstruction, viewer projection and JSON | 60 | 7.448 ms | 8.604 ms |

Replay uses no shared state cache. This patch needs no database migration or rewrite of existing histories or branches. Visual acceptance and staging smoke checks precede promotion of the same commit with production replay and experimental routes gated.
