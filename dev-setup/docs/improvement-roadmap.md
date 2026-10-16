# Improvement Roadmap for the Local Dev Setup

Ideas for extending the current setup with more features and functionality, grouped by theme. Effort is a rough guide: **S** is under an hour, **M** is a day or less, **L** is several days.

## 1. Status

| Item | Status |
|---|---|
| Task runner with `up`, `down`, `reset`, `verify` | **Done** (`Taskfile.yml`) |
| Doctor script that checks prerequisites | **Done** (`scripts/doctor.ps1`) |
| End-to-end verify script | **Done** (`scripts/verify.ps1`) |
| Everything below | Proposed |

## 2. Make it team-ready

| Improvement | What it adds | Effort |
|---|---|---|
| **Repository layout** | One Git repository holding the manifests, scripts and docs, with a README and a contribution guide | S |
| **Pinned versions** | A pinned `winget export` file, a Maven wrapper for the backend, an `.nvmrc` for Node, and pinned image tags everywhere | S |
| **Kustomize overlays** | Separate `local` and `shared` configurations, with per-developer values kept out of Git | M |
| **Pre-commit hooks** | Run linters and the manifest checks before every commit | S |
| **CI parity** | Run `task verify` (or the same manifests) in the pipeline against a throwaway cluster, for example kind or k3d | M |

## 3. Better day-to-day experience

| Improvement | What it adds | Effort |
|---|---|---|
| **Ingress instead of port-forwards** | Friendly hostnames such as `app.localhost`, and nothing to restart when a pod restarts | M |
| **Hot reload in the cluster** | Tilt or Skaffold rebuilds and redeploys on file change | M |
| **Admin UIs** | A Kafka UI, Adminer or pgAdmin for Postgres, and RedisInsight, next to the RustFS console | S |
| **Terminal tools** | k9s for browsing the cluster and stern for tailing logs across pods | S |
| **Self-healing port-forwards** | Forwards restart themselves after a pod restart (a draft is in the Performance Optimization Guide) | S |

## 4. Data and quality

| Improvement | What it adds | Effort |
|---|---|---|
| **Migrations and seed data** | Flyway or Liquibase plus a seed Job, so a reset gives a usable database | M |
| **Bucket and topic bootstrap** | A Job that creates the buckets and topics every app expects | S |
| **Testcontainers** | Integration tests that start their own dependencies instead of using the shared cluster | M |
| **Backup and restore tasks** | `task backup` and `task restore` for the Postgres data | S |
| **Observability** | Metrics and dashboards (Prometheus and Grafana) or lightweight tracing for the apps | L |

## 5. Security and portability

| Improvement | What it adds | Effort |
|---|---|---|
| **Local TLS** | Trusted HTTPS on local hostnames using mkcert | M |
| **Per-developer credentials** | Secrets generated locally instead of shared defaults | S |
| **Dev Containers** | A VS Code `devcontainer.json` so the WSL side is fully reproducible | M |
| **macOS and Linux support** | Shell equivalents of the PowerShell scripts, for teams that are not all on Windows | M |
| **Image and manifest scanning** | Automatic checks for vulnerable images and misconfigured manifests | M |

## 6. Suggested order

1. **Foundations (done).** Task runner, doctor, verify.
2. **Quick additions.** Repository layout, pinned versions, admin UIs, terminal tools, bucket and topic bootstrap.
3. **Daily comfort.** Ingress with local hostnames, self-healing forwards, hot reload.
4. **Data and tests.** Migrations and seed data, Testcontainers, backup and restore.
5. **Scale to the team.** Overlays, CI parity, per-developer credentials, cross-platform scripts, Dev Containers.
6. **Hardening.** Local TLS, scanning, observability.

## 7. Open choices

- Which of these matter for your team's size and platforms?
- Should the local setup mirror production more closely (same ingress, same configuration shape), or stay as light as possible?
- Who owns the setup, and how are changes reviewed?
