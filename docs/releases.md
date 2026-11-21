# Remote Gaming releases

Remote Gaming uses Semantic Versioning with annotated Git tags of the form `v0.MINOR.PATCH`. The project is in the initial development series. Use minor releases for substantial new capabilities and patch releases for fixes to a release series. Roadmap milestones such as P1.3 track delivery work independently of software versions.

## Publishing and deploying

- Tag the exact reviewed release commit before creating its deployment archive. The archive stamps that commit and tag into the release metadata used by the landing page footer. Published tags are immutable. Publish a new version to correct a release.
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

## Shell release candidates

Allocate an annotated `vX.Y.Z-rc.N` tag on the exact reviewed main commit. Start at 1 for each target, use the next number after checking the remote tags, and push normally without force. A concurrent allocation of the same tag must fail. Archive the tagged commit once and retain the archive and its SHA-256. The archive stamps the candidate tag. Use the same archive digest for both environments. This workflow uses one artifact per Git revision. If the archive bytes must change, use a new revision and the next candidate number.

After activation, verify the running footer and record the exact candidate tuple from the root-owned `.release-candidate.json`, passing acceptance evidence reference, and UTC acceptance time. The deployment helper writes the tuple from the upload checksum after validating the archive. Store the approved acceptance in the root-owned staging state directory under `acceptance/<sha>-<digest>.json` with the keys `candidate`, `status` (value `pass`), `evidence_ref`, and `accepted_at` (UTC to the second). Use the corresponding production directory after that environment passes.

After successful promotion and verification, publish the annotated final tag at the same commit and attach the **retained candidate archive bytes** as `remote-gaming-vX.Y.Z.tar.gz`. Never move an existing final tag. Use the reviewed release operator to invoke `deploy/record-shell-publication.rb STAGE SHA` for each environment. It verifies the final tag, published release and GitHub asset digest independently of the local acceptance record and installs the immutable receipt. Retry a failed lookup after one minute, then after five minutes. Reads take effect on the next request with no service restart. Retain the candidate archive, acceptance records, and matching receipts for rollback.
