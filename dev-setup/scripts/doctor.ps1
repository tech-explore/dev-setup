# doctor.ps1 - checks prerequisites and the state of the local dev environment.
# Run:  task doctor      (or: powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1)
# Exit code is 1 if any check FAILS. Warnings do not fail the run.

$ns = 'dev'
$script:fails = 0
$script:warns = 0

function Ok($m)      { Write-Host ('[ ok ]  ' + $m) -ForegroundColor Green }
function Warn($m)    { Write-Host ('[warn]  ' + $m) -ForegroundColor Yellow; $script:warns++ }
function Fail($m)    { Write-Host ('[FAIL]  ' + $m) -ForegroundColor Red; $script:fails++ }
function Section($m) { Write-Host ''; Write-Host $m -ForegroundColor Cyan }
function Has($cmd)   { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# ---- Machine ----
Section 'Machine'
$cs = Get-CimInstance Win32_ComputerSystem
$ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB)
if ($ramGb -ge 16) { Ok ("RAM: $ramGb GB") }
elseif ($ramGb -ge 12) { Warn ("RAM: $ramGb GB (16 GB or more is recommended)") }
else { Fail ("RAM: $ramGb GB (the full stack needs about 8 GB for WSL plus Windows itself)") }

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
if ($cs.HypervisorPresent -or $cpu.VirtualizationFirmwareEnabled) { Ok 'Virtualization is available' }
else { Fail 'Virtualization is off: enable it in the BIOS/UEFI' }

$freeGb = [math]::Round((Get-PSDrive -Name C).Free / 1GB)
if ($freeGb -ge 20) { Ok ("Free disk on C: $freeGb GB") }
else { Warn ("Free disk on C: $freeGb GB (20 GB or more is recommended)") }

# ---- Tools ----
Section 'Tools on PATH'
$tools = @(
    @('winget', 'winget'), @('git', 'Git'), @('java', 'JDK'),
    @('kubectl', 'kubectl'), @('docker', 'docker CLI'), @('wsl', 'WSL')
)
foreach ($t in $tools) {
    if (Has $t[0]) { Ok $t[1] }
    else { Fail ($t[1] + ' not found on PATH (run setup-dev.ps1, then open a new terminal)') }
}
if (Has 'task') { Ok 'Task' } else { Warn 'Task not found (winget install -e --id Task.Task)' }

if (Has 'java') {
    $jv = [string](& java -version 2>&1 | Select-Object -First 1)
    if ($jv -match '"21\.') { Ok ('Java 21 ' + $jv.Trim()) }
    else { Warn ('Java is not version 21: ' + $jv.Trim()) }
}

# ---- WSL ----
Section 'WSL'
if (Has 'wsl') {
    $null = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) { Ok 'WSL is installed' }
    else { Fail 'WSL is not set up (run wsl --install in an admin shell, then reboot)' }

    $distros = (wsl -l -q 2>&1 | Out-String) -replace "`0", ''
    if ($distros -match 'Ubuntu') { Ok 'Ubuntu distro found' }
    else { Warn 'No Ubuntu distro found (needed for the Next.js dev server)' }
}
$cfg = Join-Path $env:USERPROFILE '.wslconfig'
if ((Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match '(?im)^\s*memory\s*=')) { Ok '.wslconfig sets a memory limit' }
else { Warn 'No memory limit in .wslconfig: WSL can take half of your RAM (see the Performance Optimization Guide)' }

# ---- Rancher Desktop and Kubernetes ----
Section 'Rancher Desktop and Kubernetes'
$k8sUp = $false
if (Has 'docker') {
    $dv = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $dv) { Ok ("Docker engine reachable (server $dv)") }
    else { Fail 'Docker engine not reachable: start Rancher Desktop and select dockerd (moby)' }
}
if (Has 'kubectl') {
    $ctx = kubectl config current-context 2>$null
    if ($ctx -eq 'rancher-desktop') { Ok 'kubectl context is rancher-desktop' }
    else { Fail ("kubectl context is '$ctx' (run: kubectl config use-context rancher-desktop)") }

    $null = kubectl get nodes -o name 2>$null
    if ($LASTEXITCODE -eq 0) { Ok 'Kubernetes cluster reachable'; $k8sUp = $true }
    else { Fail 'Kubernetes not reachable: enable it in Rancher Desktop and wait for it to start' }
}

# ---- Stack ----
if ($k8sUp) {
    Section ("Stack in namespace '$ns'")
    $null = kubectl get namespace $ns 2>$null
    if ($LASTEXITCODE -ne 0) { Warn ("Namespace '$ns' does not exist yet (run: task up)") }
    else {
        foreach ($s in 'postgres', 'redis', 'kafka', 'rustfs') {
            $ready = kubectl -n $ns get pod "$s-0" -o jsonpath='{.status.containerStatuses[0].ready}' 2>$null
            if ($ready -eq 'true') { Ok ("$s-0 is ready") }
            else { Warn ("$s-0 is not ready (task status, or: kubectl -n $ns describe pod $s-0)") }
        }
    }
}

# ---- Local ports ----
Section 'Local ports'
$ports = @{
    5433 = 'Postgres forward'; 6379 = 'Redis forward'; 9092 = 'Kafka forward'
    9000 = 'RustFS API forward'; 9001 = 'RustFS console forward'
    8080 = 'Java backend / demo-service'; 3000 = 'Next.js'
}
foreach ($p in ($ports.Keys | Sort-Object)) {
    $label = $ports[$p]
    $conn = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) { Ok ("port $p is free ($label)"); continue }
    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    $name = 'unknown'
    if ($proc) { $name = $proc.ProcessName }
    if ($name -eq 'kubectl') { Ok ("port $p is forwarded by kubectl ($label)") }
    else { Warn ("port $p ($label) is in use by '$name'") }
}

# ---- Summary ----
Write-Host ''
if ($script:fails -gt 0) {
    Write-Host ('{0} check(s) failed, {1} warning(s).' -f $script:fails, $script:warns) -ForegroundColor Red
    exit 1
}
if ($script:warns -gt 0) {
    Write-Host ('No failures, {0} warning(s).' -f $script:warns) -ForegroundColor Yellow
    exit 0
}
Write-Host 'All checks passed.' -ForegroundColor Green
exit 0
