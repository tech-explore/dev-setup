# Local Dev Environment: Setup Manual

Step-by-step instructions to build the whole local environment on Windows: Postgres, Redis, Kafka and RustFS (S3-compatible object storage) running in a local Kubernetes cluster, a demo Java service, and a Next.js frontend page that proves everything is connected. For diagrams and networking background, see the [architecture document](https://claude.ai/code/artifact/b2bfc8c4-e372-4998-ab50-89a1255541ff).

## 0. What you will end up with

- **Windows tools:** VS Code, IntelliJ IDEA, Git, JDK 21, Windows Terminal, PowerShell 7.
- **WSL2 with Ubuntu** for the Next.js frontend.
- **Rancher Desktop**, providing the dockerd container engine and a local Kubernetes cluster (k3s).
- **In the cluster, namespace `dev`:** Postgres, Redis, Kafka and RustFS.
- **A demo service (Java) and a frontend page (`/stack-check`)** that check all four services.

Time needed: about 1 to 2 hours, mostly downloads and first-run setup.

**Requirements**

- Windows with virtualization enabled in the BIOS/UEFI. If `systeminfo` says a hypervisor has been detected, that is fine.
- Administrator rights on the machine.
- 16 GB RAM recommended. The Rancher Desktop VM needs about 6 GB for Kubernetes, Kafka and Postgres together.
- About 20 GB of free disk space.

## 1. Files and folder layout

Create `C:\dev-setup\` and arrange the downloaded files like this:

```
C:\dev-setup\
  setup-dev.ps1
  k8s-dev\
    kustomization.yaml
    namespace.yaml
    secrets.yaml
    postgres.yaml
    redis.yaml
    kafka.yaml
    rustfs.yaml
    port-forward.ps1
  demo-service\          (unzip demo-service.zip here)
    pom.xml, Dockerfile, k8s\demo-service.yaml, src\...
  frontend\
    k8s\frontend.yaml
```

Three frontend files go inside your own Next.js project (step 7): `Dockerfile` and `.dockerignore` in the project root, and `page.tsx` in `app\stack-check\`. The `docker-compose.yml` from earlier is no longer needed, because the infrastructure now runs in Kubernetes.

## 2. Step 1: install the base tools

1. Open PowerShell as Administrator (right-click Start, then Terminal (Admin)).
2. Run the setup script:

```powershell
cd C:\dev-setup
powershell -ExecutionPolicy Bypass -File .\setup-dev.ps1
```

3. Read the output. `[skip]` means already installed, `[install]` means installing now, and the `[note]` about skipping native Postgres is expected, because Postgres runs in Kubernetes. Click Yes on any Windows permission prompts.
4. If WSL was installed, **reboot**. Afterwards Ubuntu opens by itself and asks you to create a Linux username and password.
5. Open a new terminal and verify:

```powershell
git --version
java -version
wsl --status
```

The script installs Windows Terminal, PowerShell 7, Git, VS Code, IntelliJ IDEA Community, Temurin JDK 21, Rancher Desktop and WSL2. Tools that are already installed are skipped. If one package fails, the script prints a warning and continues. Find the current package ID with `winget search <name>` and run the script again.

## 3. Step 2: Ubuntu (WSL2) basics

Open Ubuntu from the Start menu (or run `wsl` in PowerShell) and run:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl git unzip
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global core.autocrlf input
```

Node.js is installed later, in step 7.

## 4. Step 3: Rancher Desktop

1. Launch Rancher Desktop. If the Start menu entry does nothing, run `C:\Program Files\Rancher Desktop\Rancher Desktop.exe` directly and pin it to the taskbar.
2. In the first-run dialog choose **dockerd (moby)** as the container engine, set **Configure PATH** to Automatic, and keep **Kubernetes enabled**.
3. Wait until the progress bar at the bottom finishes. The first start downloads and sets up its own WSL distro, which takes several minutes.
4. Open Preferences and confirm:
   - **Container Engine:** dockerd (moby).
   - **Kubernetes:** enabled.
   - **WSL, Integrations:** tick your Ubuntu distro.
   - **Virtual Machine, Memory:** 6 GB or more if your machine allows it.
5. In a **new** PowerShell window, verify:

```powershell
docker version
docker run --rm hello-world
kubectl config current-context
kubectl get nodes
```

Expected: `docker version` shows both a Client and a Server section, `hello-world` prints its greeting, the context is `rancher-desktop`, and one node shows `Ready`.

6. If the context shows something else (for example `minikube`):

```powershell
kubectl config get-contexts
kubectl config use-context rancher-desktop
```

Optionally remove the stale entry with `kubectl config delete-context minikube`.

## 5. Step 4: deploy Postgres, Redis, Kafka and RustFS

```powershell
cd C:\dev-setup\k8s-dev
kubectl apply -k .
kubectl -n dev get pods -w
```

Wait until `postgres-0`, `redis-0`, `kafka-0` and `rustfs-0` all show `1/1 Running`, then press Ctrl+C to leave the watch. Kafka takes the longest, about a minute.

What this created in the `dev` namespace:

- A Secret per service that needs credentials (dev values only).
- A StatefulSet, a Service and a persistent disk for each of Postgres (5 GB), Redis (1 GB), Kafka (5 GB) and RustFS (10 GB).

Quick checks:

```powershell
kubectl -n dev exec postgres-0 -- psql -U dev -d appdb -c "select version();"
kubectl -n dev exec redis-0 -- redis-cli ping
kubectl -n dev exec kafka-0 -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list
kubectl -n dev logs rustfs-0 --tail=10
```

Expected: a Postgres version row, `PONG`, an empty topic list (or a list of topics), and RustFS log lines showing the S3 API and console have started. If a pod does not start, run `kubectl -n dev describe pod <name>` and `kubectl -n dev logs <name>`.

## 6. Step 5: start the port-forwards

Windows cannot reach services inside the cluster directly. The script maps each one to a port on `localhost`:

```powershell
cd C:\dev-setup\k8s-dev
.\port-forward.ps1
```

If PowerShell blocks the script, run `powershell -ExecutionPolicy Bypass -File .\port-forward.ps1` instead.

| Service | Local address | Credentials |
| --- | --- | --- |
| Postgres | `localhost:5433` | user `dev`, password `dev`, database `appdb` |
| Redis | `localhost:6379` | none |
| Kafka | `localhost:9092` | none |
| RustFS S3 API | `http://localhost:9000` | `rustfsadmin` / `rustfsadmin` |
| RustFS console | `http://localhost:9001/rustfs/console/` | `rustfsadmin` / `rustfsadmin` |

Stop all forwards with `.\port-forward.ps1 -Stop`. The forwards also end when a pod restarts or Rancher Desktop restarts, so run the script again after either.

You can change the local ports in the script, with one exception: Kafka must stay on 9092. The broker tells clients to connect to `localhost:9092`, so changing it means editing both `kafka.yaml` and `port-forward.ps1`.

To test RustFS, open `http://localhost:9001/rustfs/console/` in a browser and log in with `rustfsadmin` / `rustfsadmin`.

## 7. Step 6: verify with the demo service

`demo-service` is a small Spring Boot app. For each service it writes something and reads it back: a row in Postgres, a key in Redis, a message through Kafka, and an object in RustFS through its S3 API.

### Option A: run it from IntelliJ (port-forwards must be running)

1. Unzip `demo-service.zip` into `C:\dev-setup\demo-service`.
2. In IntelliJ choose File, Open, select `pom.xml`, then Open as Project. Set the Project SDK to Temurin 21 (File, Project Structure) and let Maven import finish.
3. Run `DemoApplication`.
4. Test it:

```powershell
Invoke-RestMethod http://localhost:8080/check | ConvertTo-Json -Depth 5
```

Expected: `overall` is `UP`, and postgres, redis, kafka and s3 (the object storage check) each report `UP` with a short detail line. You can also call `/check/postgres`, `/check/redis`, `/check/kafka` and `/check/s3` one at a time. `/ping` is a plain liveness endpoint.

To run from the command line instead you need Maven installed (find its package ID with `winget search maven`), then run `mvn spring-boot:run` in the `demo-service` folder.

If a service reports `DOWN`, its error text says why. The most common cause is a port-forward that is not running.

### Option B: run it as a pod in the cluster

```powershell
cd C:\dev-setup\demo-service
docker build -t demo-service:0.1.0 .
kubectl apply -f k8s\demo-service.yaml
kubectl -n dev get pods -w
kubectl -n dev port-forward svc/demo-service 8081:8080
```

Then test it:

```powershell
Invoke-RestMethod http://localhost:8081/check | ConvertTo-Json -Depth 5
```

The first image build downloads dependencies and takes a few minutes. The pod uses service names (`postgres`, `redis`, `kafka`, `rustfs`) instead of `localhost`, so this proves the in-cluster path works. It does not need a registry: because the engine is dockerd, the cluster sees images you build locally.

## 8. Step 7: the Next.js 16 frontend

1. **Install Node in WSL** (Next.js 16 needs Node 20.9 or newer):

```bash
curl -fsSL https://fnm.vercel.app/install | bash
source ~/.bashrc
fnm install 22
node -v
```

2. **Create or open your project** under `~/projects` (keep it in the Linux filesystem, not under `/mnt/c`). For a new one: `npx create-next-app@latest my-app`.
3. **Add the check page:** copy `page.tsx` to `app/stack-check/page.tsx` (or `src/app/stack-check/page.tsx`).
4. **Enable standalone output** in `next.config.ts`, which the Dockerfile needs:

```ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
};

export default nextConfig;
```

5. **Copy** `Dockerfile` and `.dockerignore` into the project root.

### Run the frontend as a pod

In the Ubuntu terminal, in the project root:

```bash
docker build -t frontend:0.1.0 .
```

Then in PowerShell:

```powershell
kubectl apply -f C:\dev-setup\frontend\k8s\frontend.yaml
kubectl -n dev get pods -w
kubectl -n dev port-forward svc/frontend 3000:3000
```

Open `http://localhost:3000/stack-check`. You should see a green tick next to postgres, redis, kafka and s3. This tests the whole chain: browser, Next.js, demo-service, and the four services. It requires the demo service to be deployed as a pod (option B), because the frontend calls `http://demo-service:8080`.

### Or run the dev server in WSL

```bash
BACKEND_URL=http://localhost:8080 npm run dev
```

Then open `http://localhost:3000/stack-check`. From WSL, `localhost` may not reach services running on Windows. If the page cannot reach the backend, enable mirrored networking by adding this to `%UserProfile%\.wslconfig`, then run `wsl --shutdown` in PowerShell:

```
[wsl2]
networkingMode=mirrored
```

Use either the dev server or the frontend pod, not both at once, because both use port 3000.

Note: server-side code (server components and route handlers) can call cluster names like `demo-service:8080`. Code running in the browser cannot, so browser-side calls need a URL reachable from Windows or a server-side proxy route.

## 9. Daily use

- **Start the day:** open Rancher Desktop and wait until it is ready, check `kubectl -n dev get pods`, then run `.\port-forward.ps1`.
- **End the day:** run `.\port-forward.ps1 -Stop`, then quit Rancher Desktop. Data is kept on disk.
- **Free memory but keep data:** `kubectl -n dev scale statefulset --all --replicas=0`. Bring everything back with `--replicas=1`.
- **Apply a manifest change:** `kubectl apply -k .` in `k8s-dev`.
- **Reset one service's data** (Postgres as the example):

```powershell
kubectl -n dev scale statefulset postgres --replicas=0
kubectl -n dev delete pvc data-postgres-0
kubectl -n dev scale statefulset postgres --replicas=1
```

- **Wipe everything:** `kubectl delete -k .` deletes the whole `dev` namespace, including all data and any app pods in it. Redeploy with `kubectl apply -k .`.
- **Update an app image:** rebuild it with a new tag, change the tag in its manifest, and apply. If you reuse the same tag, run `kubectl -n dev rollout restart deployment <name>`.

## 10. Connection cheat sheet

Use the first address column from your IDE or command line (port-forwards running), and the second from code running as a pod. All credentials are for development only.

| Service | From Windows (IDE / CLI) | From pods in the cluster | Credentials |
| --- | --- | --- | --- |
| Postgres | `jdbc:postgresql://localhost:5433/appdb` | `jdbc:postgresql://postgres:5432/appdb` | `dev` / `dev` |
| Redis | `localhost:6379` | `redis:6379` | none |
| Kafka | `localhost:9092` | `kafka:9092` | none |
| RustFS S3 API | `http://localhost:9000` | `http://rustfs:9000` | `rustfsadmin` / `rustfsadmin` |
| RustFS console | `http://localhost:9001/rustfs/console/` | not needed | `rustfsadmin` / `rustfsadmin` |

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `docker` cannot connect to the API (`docker_engine` pipe error) | Rancher Desktop is not running or still starting, or the wrong engine is selected | Start Rancher Desktop, wait for the progress bar to finish, set Container Engine to dockerd (moby), and retry in a new terminal |
| `kubectl` says unable to connect, or the context is `minikube` | Kubernetes is disabled, or the wrong context is active | Enable Kubernetes in Rancher Desktop, then `kubectl config use-context rancher-desktop` |
| Rancher Desktop does not open from the Start menu | Shortcut or first-run problem | Run the exe from `C:\Program Files\Rancher Desktop`, reboot after the WSL install, run `wsl --update` |
| Pod stuck in `Pending` | Disk (PVC) not bound, or not enough memory | `kubectl -n dev describe pod <name>`, raise the Rancher VM memory, check `kubectl get storageclass` |
| `kafka-0` keeps restarting | Out of memory | Give the Rancher VM 6 GB or more |
| Port-forward says address already in use | Another process uses that local port (for example an old Compose stack) | Stop the other process, or change the local port in the script (not Kafka's) |
| Script is blocked | PowerShell execution policy | Run it with `powershell -ExecutionPolicy Bypass -File ...` |
| Kafka client connects, then times out | The forward is not on 9092, or another process holds 9092 | Keep Kafka's local port at 9092 and make sure nothing else uses it |
| `demo-service` or `frontend` pod shows `ImagePullBackOff` or `ErrImagePull` | The image was not built locally, or the engine is not dockerd | Rebuild with `docker build -t <name>:0.1.0 .` and confirm dockerd is selected |
| `/check` shows `DOWN` for one service | That one connection is failing | Read the error text, check the port-forward is running and the pod is Ready |
| `rustfs-0` stays unready, or shows `ImagePullBackOff` or `CrashLoopBackOff` | The pinned image tag is not available, the data volume is not writable, or a setting is wrong | Run `kubectl -n dev describe pod rustfs-0` and `kubectl -n dev logs rustfs-0`, and check the available tags for `rustfs/rustfs` on Docker Hub |
| Next.js dev server in WSL cannot reach the backend on Windows | WSL networking does not expose Windows localhost | Enable mirrored networking (step 7), or run the frontend as a pod |
| Browser calls to `http://demo-service:8080` fail | Cluster names do not resolve in the browser | Call the backend from server-side code, or through a reachable URL |

## 12. Known limitations

- **RustFS is a young project.** It reached 1.0.0 in 2026 and is licensed Apache 2.0, but expect rough edges and read the release notes before upgrading. The manifest pins `rustfs/rustfs:1.0.0`. Because RustFS speaks the standard S3 API, moving to another S3-compatible server later (for example SeaweedFS) means changing the image and settings in `rustfs.yaml`; your application code stays the same.
- **Development credentials everywhere.** Never reuse them, and do not expose these ports beyond `localhost`.
- **Single node, no replication, no TLS.** This setup is for local development, not a production blueprint.
- **Port-forwards are manual.** They stop when a pod restarts and must be started again.

## 13. Postponed items

- Connecting VS Code to WSL and installing extensions.
- Connecting IntelliJ to Postgres (use the JDBC URL in the cheat sheet).
- Deciding which Postgres version matches production (the cluster runs 17) and whether RustFS is mature enough for your needs.
