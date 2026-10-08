# Local Dev Environment Package

Everything needed to set up the local development environment on Windows:
Postgres, Redis, Kafka and RustFS (S3-compatible object storage) in a local Kubernetes
cluster, a demo Java service, and a Next.js page that checks the whole chain.

Full instructions: the "Local Dev Environment: Setup Manual" document.
Diagrams and networking background: the "Local Dev Environment: Architecture and Networking" document.

## Contents

```
dev-setup/
  README.md                 this file
  setup-dev.ps1             installs the Windows tools with winget (skips what is installed)
  k8s-dev/                  Kubernetes manifests for the infrastructure (namespace "dev")
    kustomization.yaml
    namespace.yaml
    secrets.yaml            dev-only credentials
    postgres.yaml
    redis.yaml
    kafka.yaml
    rustfs.yaml
    port-forward.ps1        exposes the services on localhost
  demo-service/             Spring Boot app that checks all four services (/check)
    pom.xml, Dockerfile, k8s/demo-service.yaml, src/...
  frontend/                 files to add to your own Next.js 16 project
    Dockerfile, .dockerignore
    app/stack-check/page.tsx
    k8s/frontend.yaml
```

Unzip it to `C:\dev-setup\` so the paths in the manual match.

## Quick start

1. Open PowerShell as Administrator and run the setup script, then reboot if asked:
   `powershell -ExecutionPolicy Bypass -File .\setup-dev.ps1`
2. Start Rancher Desktop (dockerd engine, Kubernetes enabled) and check `kubectl get nodes`.
3. Deploy the infrastructure:
   `cd k8s-dev` then `kubectl apply -k .` and watch `kubectl -n dev get pods -w`.
4. Start the port-forwards: `.\port-forward.ps1` (stop them with `-Stop`).
5. Verify: run `demo-service` from IntelliJ and open http://localhost:8080/check,
   or build and deploy it as a pod (see the manual, step 6).
6. Frontend: copy the files from `frontend/` into your Next.js project, enable
   `output: 'standalone'` in `next.config.ts`, and open /stack-check (manual, step 7).

## Local addresses (port-forwards running)

| Service | Address | Credentials |
|---|---|---|
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
- Not tested on a live machine when this package was assembled; check the troubleshooting
  table in the manual if a step behaves differently.
