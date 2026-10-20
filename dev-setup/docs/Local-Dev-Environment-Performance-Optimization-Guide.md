# Local Dev Environment: Performance Optimization Guide

Ways to make the local environment lighter and faster. Everything here is optional. Apply one change at a time, measure the effect, and keep what helps. Companion documents: the [setup manual](./Local-Dev-Environment-Setup-Manual.md) and the [architecture document](./architecture/architecture-and-networking.md).

## 1. Changes at a glance

| Change | Effort | Risk | Helps with |
| --- | --- | --- | --- |
| Cap WSL memory and CPUs (`.wslconfig`) | 5 min | Low | Memory hogging, Windows slowdowns |
| Antivirus exclusions for dev folders | 5 min | Medium (less scanning) | Slow installs, builds, database I/O |
| Scale down services you are not using | 1 min | None | Memory |
| Postgres dev tuning | 5 min | Data loss on crash | Write speed |
| Redis without persistence | 2 min | Data lost on restart | Minor |
| Turn off Traefik | 2 min | None if you use no ingress | Memory |
| Fast inner loop (IDE and dev server) | none | None | Everything you iterate on |
| Docker build cache mounts | 10 min | Low | Image build time |
| JVM and Spring Boot tuning | 10 min | Lower peak speed in dev | Pod memory, startup time |
| Self-healing port-forwards | 10 min | Low | Less manual restarting |

## 2. Measure first

Write down a baseline so you can tell whether a change helped.

- **Windows memory:** Task Manager, Details tab, look at the `Vmmem` or `vmmemWSL` process. That is the memory WSL2 (and therefore Rancher Desktop) is using.
- **Container usage:** `docker stats --no-stream` shows CPU and memory per container.
- **Cluster usage:** `kubectl top nodes` and `kubectl -n dev top pods`, if metrics are available in your cluster.
- **Timings:** note how long `kubectl apply -k .` takes until every pod is Ready, and how long `docker build` takes for the demo service.

For reference, the pod resource requests in this setup add up to roughly 2 GB (Postgres 256 Mi, Redis 64 Mi, Kafka 768 Mi, RustFS 256 Mi, demo-service 384 Mi, frontend 192 Mi), plus the overhead of k3s itself.

## 3. Quick wins

### 3.1 Cap WSL memory and CPUs

WSL2 can claim up to half of your RAM and hold on to it. Rancher Desktop on Windows runs inside WSL2, so these limits cover it too. This is also where the memory limit for the whole cluster is set: **on Windows with the WSL2 backend, the memory limit comes from `.wslconfig`, not from a slider in Rancher Desktop's Preferences.** (Earlier instructions mentioned a VM memory setting; use `.wslconfig` instead.)

Create or edit `%UserProfile%\.wslconfig`:

```
[wsl2]
memory=8GB
processors=4
swap=2GB
```

Then apply it:

```powershell
wsl --shutdown
```

Restart Rancher Desktop afterwards. Suggested starting points:

| Machine RAM | `memory` | `processors` | Notes |
| --- | --- | --- | --- |
| 16 GB | 8GB | 4 | Scale Kafka down when you are not using it |
| 32 GB | 12GB to 16GB | 6 to 8 | Comfortable for the whole stack plus IDEs |
| 8 GB | not recommended |  | Run only Postgres and Redis; scale Kafka and RustFS to 0 |

If `kafka-0` restarts with out-of-memory errors, the limit is too low.

### 3.2 Antivirus exclusions

Real-time scanning slows down anything that touches many small files: npm installs, Maven builds and database writes. Excluding trusted dev locations from Microsoft Defender can make a visible difference. In an Administrator PowerShell:

```powershell
Add-MpPreference -ExclusionPath "C:\dev-setup"
Add-MpPreference -ExclusionPath "$env:USERPROFILE\.m2"
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\rancher-desktop"
```

Adjust the paths to where your projects live. The Rancher Desktop data folder holds the WSL disk images; its exact location can vary by version. This lowers protection for those folders, so only exclude locations you trust, and follow your organisation's policy if the machine is managed.

On Windows 11 you can also keep Windows-side projects and the Maven repository on a **Dev Drive**, a volume type designed for developer workloads, which reduces scanning overhead without per-folder exclusions.

### 3.3 Scale down what you are not using

Kafka is the heaviest piece. Stop it when you are not working with messaging, and start it again when you are (data is kept on disk):

```powershell
kubectl -n dev scale statefulset kafka --replicas=0
kubectl -n dev scale statefulset kafka --replicas=1
```

The same works for `rustfs`, `redis` and `postgres`. To stop everything and keep the data, use `kubectl -n dev scale statefulset --all --replicas=0`.

### 3.4 Postgres dev tuning

For throwaway development data you can trade crash safety for speed. In `postgres.yaml`, add `args` to the Postgres container. The first entry must be `postgres`, because `args` replaces the image's default command:

```yaml
          args:
            - postgres
            - -c
            - fsync=off
            - -c
            - synchronous_commit=off
            - -c
            - full_page_writes=off
            - -c
            - shared_buffers=256MB
```

Then run `kubectl apply -k .` and `kubectl -n dev delete pod postgres-0` so the pod restarts with the new settings. **Risk:** if Postgres crashes or the VM is killed, the database can be corrupted. Do not use these settings for data you care about.

### 3.5 Redis without persistence

If you do not need cached data to survive restarts, replace the container arguments in `redis.yaml`:

```yaml
          args: ["redis-server", "--save", "", "--appendonly", "no"]
```

This removes disk writes. The gain is small; skip it if you rely on Redis data surviving a restart.

### 3.6 Turn off Traefik

k3s ships with the Traefik ingress controller. This setup reaches services through port-forwards, so Traefik is unused. If your version of Rancher Desktop has an **Enable Traefik** checkbox under Preferences, Kubernetes, untick it and apply to save some memory.

## 4. Faster daily workflow

### 4.1 Use the fast inner loop

The biggest speed-up is a habit, not a setting: run the Java app from IntelliJ and Next.js with `npm run dev`, with only the infrastructure in the cluster. Hot reload is near-instant, with no image build and no redeploy. Build and deploy containers only when you want to test the deployment itself (probes, service names, configuration from Secrets).

### 4.2 Cache dependencies in image builds

BuildKit cache mounts keep the Maven and npm caches between builds, so changing one source file does not re-download every dependency. In the demo service `Dockerfile`, change the two Maven lines in the build stage to:

```dockerfile
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests
```

In the frontend `Dockerfile`, change the install step to:

```dockerfile
RUN --mount=type=cache,target=/root/.npm npm ci
```

The layer order already copies `pom.xml` and `package.json` first, so unchanged dependencies are reused. Keep `.dockerignore` files in place so the build context stays small. If `--mount` is rejected, your builder is not using BuildKit; update Rancher Desktop or enable BuildKit.

### 4.3 Keep project files on the right side

Keep Next.js projects inside WSL (`~/projects`), not under `/mnt/c`: file watching and `node_modules` installs are much faster on the Linux filesystem. Keep Java projects on native Windows for IntelliJ.

### 4.4 Self-healing port-forwards

A `kubectl port-forward` ends when its pod restarts. This variant of `port-forward.ps1` restarts each forward automatically. Save it as `port-forward-resilient.ps1` in `k8s-dev` (it has not been tested on a live machine, so try it before relying on it):

```powershell
# Restarts each forward if it drops (pod restart, Rancher restart).
# Start: .\port-forward-resilient.ps1      Stop: .\port-forward-resilient.ps1 -Stop
param([switch]$Stop)
$ns = 'dev'
$forwards = @(
    @{ Target = 'svc/postgres'; Ports = '5433:5432' },
    @{ Target = 'svc/redis';    Ports = '6379:6379' },
    @{ Target = 'pod/kafka-0';  Ports = '9092:9094' },
    @{ Target = 'svc/rustfs';   Ports = '9000:9000' },
    @{ Target = 'svc/rustfs';   Ports = '9001:9001' }
)

if ($Stop) {
    $procs = Get-CimInstance Win32_Process |
        Where-Object { $_.CommandLine -match 'port-forward' -and $_.ProcessId -ne $PID }
    # Stop the restart loops first, then the kubectl processes they started
    $procs | Where-Object { $_.Name -match 'powershell|pwsh' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    $procs | Where-Object { $_.Name -match 'kubectl' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Host 'Stopped all port-forwards.'
    return
}

foreach ($f in $forwards) {
    $cmd = "while (`$true) { kubectl -n $ns port-forward $($f.Target) $($f.Ports); Start-Sleep -Seconds 2 }"
    Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $cmd
    Write-Host ("[forward] {0} -> localhost:{1}" -f $f.Target, $f.Ports.Split(':')[0])
}
```

Do not run it together with the original `port-forward.ps1`, because both want the same local ports. Kafka's local port must stay 9092.

## 5. JVM and Spring Boot tuning (for backend pods)

These apply to the demo service and your own backend when they run as pods. Add them as environment variables in the Deployment:

```yaml
            - name: JAVA_TOOL_OPTIONS
              value: -XX:MaxRAMPercentage=75 -XX:+UseSerialGC -XX:TieredStopAtLevel=1
```

- **`-XX:MaxRAMPercentage=75`:** sizes the heap relative to the container's memory limit instead of a fixed number. Java 21 already respects container limits; this makes the share explicit.
- **`-XX:+UseSerialGC`:** the simplest garbage collector, with the lowest memory overhead. Good for small dev pods.
- **`-XX:TieredStopAtLevel=1`:** uses only the quick compiler, which starts faster and uses less memory but reaches a lower peak speed. Fine for development, not for load testing.
- **Lazy initialization:** set `spring.main.lazy-initialization=true` (in `application.yml` or as the environment variable `SPRING_MAIN_LAZY_INITIALIZATION=true`) to speed up startup. The first request to each component is then slower, and problems that would have failed at startup show up later.
- **In the IDE:** Spring Boot DevTools gives fast restarts when you run from IntelliJ.

Keep the pod memory limit (768 Mi for the demo service) comfortably above the JVM's heap plus overhead.

## 6. Kubernetes sizing

- **Requests versus limits:** requests decide how much the scheduler reserves; limits decide when a container is killed. The manifests use small requests and larger limits so the stack fits on a laptop. If a pod is killed for memory, raise its limit; if the machine is tight, lower the requests of services you rarely use.
- **Probes:** the `initialDelaySeconds` values are tuned for a laptop. If a pod is restarted before it finishes starting, raise the delay; if you want faster readiness, lower it.
- **One replica:** everything runs as a single replica on a single node. Do not add replicas locally unless you are testing for that.

## 7. Heavier options (not adopted)

- **Redpanda instead of Kafka:** it is Kafka API compatible, written in C++, and advertises a lower footprint, but it uses a different license (BSL 1.1 for the community edition) and its resource claims were not measured here. Decision: staying with Apache Kafka for now.
- **Tilt or Skaffold:** tools that rebuild and redeploy pods automatically when you change code. Worth considering if you work with app pods more than with the IDE loop.

## 8. Checklist and rollback

1. Record a baseline (section 2).
2. Apply one change from section 3 to 5.
3. Re-measure, and run `Invoke-RestMethod http://localhost:8080/check` (or open `/stack-check`) to confirm everything still works.
4. Keep the change if it helps. To undo a manifest change, edit it back and run `kubectl apply -k .`; to undo `.wslconfig`, remove the lines and run `wsl --shutdown`.
