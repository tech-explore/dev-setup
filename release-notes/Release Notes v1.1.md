# Release Notes V1.1
**Released:** October 17, 2026

## Highlights
- A one-command workflow: `task doctor`, `task up`, `task verify`, `task down` and `task reset`.
- Two new scripts that check your machine and verify the running stack.
- The demo service now builds on Spring Boot 4.1.1.
- The frontend check page that works with Next.js 16 `cacheComponents`.
## New
- `Taskfile.yml` with the commands above, plus `demo:deploy`, `status`, `logs` and `psql`.
- `scripts/doctor.ps1` checks RAM, virtualization, tools, WSL, the Docker engine, the Kubernetes context, local ports and pod status.
- `scripts/verify.ps1` checks pods, the localhost port-forwards and the demo service's `/check` endpoint.
- `docs/benefits-of-a-common-dev-setup.md` and `docs/improvement-roadmap.md`.
## Changed
- `setup-dev.ps1` also installs Task.
## Fixed
- Nothing to fix
## Known limitations
- RustFS is a young project, and its pinned image tag comes from a single source.
## 