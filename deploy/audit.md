# Repository and recovery audit

| Area | Active `harvj/remote-gaming` main at `f183310` | Archived `harvj/remote-gaming-v1` master at `bacccbe` |
| --- | --- | --- |
| Runtime and assets | Ruby 3.4.8, Rails 8.1.2, PostgreSQL, Puma, Svelte 5 with Vite Ruby, Propshaft | Ruby 2.7.1, Rails 6, PostgreSQL, Puma, Vue and Webpacker |
| Directory | Index action prepared game data. The corresponding HTML view was missing, and a generic subdomain constraint would have sent `gaming.harvj.com` through game lookup. P1.0 uses exact directory aliases and registry lookup for game names. | Vue's `GamesIndex` asked “What are we playing?” and presented a list of direct game links. P1.0 keeps that behavior and adds explicit status and descriptions. |
| Authentication | Devise username/password sign-in, with user models and profile/statistics routes. Legacy session mutation actions need explicit authentication, game scoping and authorization review before public use. | Devise username/password sign-in and user configuration. Historical accounts are stored in PostgreSQL. |
| Sessions and rules | Svelte game, session and player components, Action Cable streams, Rails representers, and Ruby services under `app/services/play`. Modern Art and Pandemic implementations exist. There is no validated production playthrough for either game. | Vue lobby, session list and controls. Ruby engines cover shared session and card behavior plus Modern Art and Pandemic. These are the behavioral references for P1.1. |
| Schema | Current PostgreSQL schema is checked in. The two existing migrations add game slugs and player removal timestamps. Directory metadata lives outside historical game records. | Historical domain tables for users, sessions, players, decks, cards, frames, roles, badges and user configuration. |
| Tests | RSpec covers portions of the model, player creation service and cable channels. CI includes lint, dependency/static security checks and PostgreSQL-backed tests. P1.0 adds directory, migration and production smoke coverage. | RSpec includes older model and service behavior tests that can inform regression coverage. |
| Deployment | Initial Rails production config listed separate Solid Cache, Queue and Cable databases, with no host-specific unit or proxy configuration. P1.0 uses only the restored primary database, loopback Puma, and precompiled assets. | Tracked Rails/Puma configuration and assets. The source tree does not establish a current Hetzner deployment for this app. |

## Historical data and external files

The archived PostgreSQL 12.2 custom dump was restored into a new local PostgreSQL 14 database. It contained 14 public tables including the two Rails metadata tables, 16 users and 104 game sessions. The three Rails 8 migrations ran successfully. Before and after fingerprints matched for all 12 historical payload tables and their sequences, with the new fields excluded. The two game rows kept their IDs and gained the expected host slugs. The original dump retained its SHA-256 checksum.

The dump has no Active Storage attachment or blob tables. Neither tracked application declares Active Storage attachments or a legacy upload library. Tracked public assets and icon references ship in source. The archive and Git do not cover untracked files or a separate object store. If the old disk or any filesystem export remains available, inventory the old release's `public/uploads`, shared `storage`, other mounted volumes and object-storage settings before declaring the recovery complete. Preserve any discovered files in a separate archive and map them to database references before restoring them.

## P1.1 recommendation

1. Verify one Modern Art playthrough against the archived Vue flow and the Ruby rules. Exercise login with a controlled historical account, create and join, turn advancement, card visibility, reconnect and completion.
2. Add authorization and game/session scoping to every mutation and Cable subscription. Cover two-browser spectator and player updates. Exercise Pandemic separately before publishing its availability.
3. Validate operational backup recovery from a completed production snapshot. Finish wildcard DNS-01 renewal and monitoring before expanding first-party subdomains if the named configuration ships first.
