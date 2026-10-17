# Local Dev Environment Package

Everything needed to set up the local development environment on Windows:
Postgres, Redis, Kafka and RustFS (S3-compatible object storage) in a local Kubernetes
cluster, a demo Java service, and a Next.js page that checks the whole chain.

Full instructions: the "Local Dev Environment: Setup Manual" document.
Diagrams and networking background: the "Local Dev Environment: Architecture and Networking" document.
Tuning: the "Local Dev Environment: Performance Optimization Guide" document.

## Contents

```
dev-setup/
  README.md                 this file
  setup-dev.ps1             installs the Windows tools with winget (skips what is installed)
  Taskfile.yml              one-command workflow: task doctor / up / verify / down / reset
  scripts/
    doctor.ps1              checks prerequisites and the state of the environment
    verify.ps1              checks pods, local ports and the demo-service end to end
  docs/
    benefits-of-a-common-dev-setup.md
    improvement-roadmap.md
  k8s-dev/                  Kubernetes manifests for the infrastructure (namespace "dev")
    kustomization.yaml, namespace.yaml, secrets.yaml (dev-only credentials)
    postgres.yaml, redis.yaml, kafka.yaml, rustfs.yaml
    port-forward.ps1        exposes the services on localhost
  demo-service/             Spring Boot app that checks all four services (/check)
  frontend/                 files to add to your own Next.js 16 project
```

## Quick start

1. Open PowerShell as Administrator and run the setup script, then reboot if asked:
   `powershell -ExecutionPolicy Bypass -File .\setup-dev.ps1`
   (It also installs Task. If that package ID fails, check `winget search task`.)
2. Start Rancher Desktop (dockerd engine, Kubernetes enabled).
3. In a new terminal, in `C:\dev-setup\dev-setup`:

| Command | What it does |
| --- | --- |
| `task doctor` | Checks prerequisites and the state of the environment |
| `task up` | Deploys the infrastructure, waits until it is ready, starts the port-forwards |
| `task verify` | Checks pods, local ports and the demo-service `/check` endpoint |
| `task down` | Stops everything but keeps the data (frees memory) |
| `task reset` | Deletes ALL data and deploys a fresh stack (asks first) |
| `task demo:deploy` | Builds the demo-service image and deploys it as a pod |
| `task status` / `task logs -- kafka-0` / `task psql` | Look around |

Without Task, the plain commands are in the setup manual (`kubectl apply -k k8s-dev`, `k8s-dev\port-forward.ps1`).

4. Run `demo-service` from IntelliJ and open http://localhost:8080/check, or run `task demo:deploy`.
5. Frontend: copy the files from `frontend/` into your Next.js project, enable
   `output: 'standalone'` in `next.config.ts`, and open /stack-check (manual, step 7).

## Local addresses (port-forwards running)

| Service | Address | Credentials |
| --- | --- | --- |
| Postgres | localhost:5433 | dev / dev, database appdb |
| Redis | localhost:6379 | none |
| Kafka | localhost:9092 | none |
| RustFS S3 API | http://localhost:9000 | rustfsadmin / rustfsadmin |
| RustFS console | http://localhost:9001/rustfs/console/ | rustfsadmin / rustfsadmin |

All credentials are for local development only.

## Notes

- RustFS reached 1.0.0 in 2026 and is a young project; the image tag is pinned in `k8s-dev/rustfs.yaml`.
- Kafka's local port must stay 9092 (it is advertised as localhost:9092). Change it in
  `k8s-dev/kafka.yaml` and `k8s-dev/port-forward.ps1` together if you ever need to.
- `task reset` deletes the whole `dev` namespace, including app pods such as demo-service.
  Run `task demo:deploy` again afterwards.
- The scripts pass a PowerShell syntax check, but have not been run on a live Windows machine.
  Check the troubleshooting table in the manual if a step behaves differently.
