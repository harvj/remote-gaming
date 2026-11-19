# Remote Gaming releases

Remote Gaming uses Semantic Versioning with annotated Git tags of the form `v0.MINOR.PATCH`. The project is in the initial development series. Use minor releases for substantial new capabilities and patch releases for fixes to a release series. Roadmap milestones such as P1.3 track delivery work independently of software versions.

## Publishing and deploying

- Tag the exact reviewed release commit. Published tags are immutable. Publish a new version to correct a release.
- Start each GitHub release title with the exact tag followed by an em dash and a descriptive name, for example `v0.2.0 — SessionFrame Replay and Modern Art`.
- Describe functionality, compatibility, migrations, verification results, known limitations, and deployment status in the release notes. State which capabilities are public, which are private staging only, and which require a future rollout.
- Record both the exact version and full Git SHA in production and staging deployment reports, including rollback reports. Use `git describe --exact-match --match 'v0.*' <sha>` to check the version. Record an untagged reviewed build as `unreleased` with its full SHA.
- Publishing a release and deploying it are separate operations. Follow the applicable [deployment runbook](../deploy/capistrano.md) and its approval, backup, migration, and rollback checks.

## Historical releases

| Version | Exact commit | Deployment status |
| --- | --- | --- |
| [v0.1.0 — Production Foundation](https://github.com/harvj/remote-gaming/releases/tag/v0.1.0) | `82543490160a6e7650f5e8ba677d8c28430ba01d` | Hetzner production directory with recovered PostgreSQL history. |
| [v0.2.0 — SessionFrame Replay and Modern Art](https://github.com/harvj/remote-gaming/releases/tag/v0.2.0) | `7bda3eef2762b2a0732817043d49aacfdc831285` | Private staging gameplay and Capistrano rollback verified. Public gameplay remains closed. |

## Provisional targets

| Target | Scope |
| --- | --- |
| v0.3.0 | Auth integration, historical identity reconciliation, private sessions, and dummy players |
| v0.4.0 | Interactive SessionFrame replay and experimental branching |
| v0.5.0 | Public Modern Art activation |

These targets are planning labels. Create their tags and GitHub releases after review and verification of the exact release commits.
