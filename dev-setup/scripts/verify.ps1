# verify.ps1 - checks that the running stack really works.
#   1. the infrastructure pods are ready
#   2. the port-forwards answer on localhost
#   3. demo-service /check passes (from the IDE on :8080, or from the pod via a temporary forward)
# Run:  task verify      Exit code is 1 if any check FAILS.

$ns = 'dev'
$script:fails = 0

function Ok($m)      { Write-Host ('[ ok ]  ' + $m) -ForegroundColor Green }
function Warn($m)    { Write-Host ('[warn]  ' + $m) -ForegroundColor Yellow }
function Fail($m)    { Write-Host ('[FAIL]  ' + $m) -ForegroundColor Red; $script:fails++ }
function Info($m)    { Write-Host ('        ' + $m) -ForegroundColor DarkGray }
function Section($m) { Write-Host ''; Write-Host $m -ForegroundColor Cyan }

function Test-Port($port) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', $port, $null, $null)
        return ($iar.AsyncWaitHandle.WaitOne(1500) -and $client.Connected)
    } catch { return $false } finally { $client.Close() }
}

# /check answers 503 with a JSON body when a service is down, so read the body either way
function Get-Check($url) {
    try {
        return Invoke-RestMethod -Uri $url -TimeoutSec 30
    } catch {
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try { return ($_.ErrorDetails.Message | ConvertFrom-Json) } catch { }
        }
        if ($_.Exception.Response -and $_.Exception.Response.GetType().GetMethod('GetResponseStream')) {
            try {
                $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                return ($reader.ReadToEnd() | ConvertFrom-Json)
            } catch { }
        }
        return $null
    }
}

# ---- 1. Pods ----
Section '1. Pods'
foreach ($s in 'postgres', 'redis', 'kafka', 'rustfs') {
    $ready = kubectl -n $ns get pod "$s-0" -o jsonpath='{.status.containerStatuses[0].ready}' 2>$null
    if ($ready -eq 'true') { Ok ("$s-0 is ready") }
    else { Fail ("$s-0 is not ready (kubectl -n $ns describe pod $s-0)") }
}

# ---- 2. Port-forwards ----
Section '2. Port-forwards on localhost'
$targets = [ordered]@{ 'Postgres' = 5433; 'Redis' = 6379; 'Kafka' = 9092; 'RustFS API' = 9000; 'RustFS console' = 9001 }
foreach ($name in $targets.Keys) {
    $port = $targets[$name]
    if (Test-Port $port) { Ok ("$name answers on localhost:$port") }
    else { Fail ("$name does not answer on localhost:$port (run: task forward)") }
}

# ---- 3. End to end ----
Section '3. End-to-end check (demo-service /check)'
$source = 'demo-service on localhost:8080 (running from the IDE)'
$result = Get-Check 'http://localhost:8080/check'
$forward = $null

if (-not $result) {
    $avail = kubectl -n $ns get deployment demo-service -o jsonpath='{.status.availableReplicas}' 2>$null
    if ($avail -and ([int]$avail -ge 1)) {
        $forward = Start-Process -FilePath kubectl -WindowStyle Hidden -PassThru `
            -ArgumentList @('-n', $ns, 'port-forward', 'svc/demo-service', '18081:8080')
        Start-Sleep -Seconds 4
        $source = 'demo-service pod (temporary forward on localhost:18081)'
        $result = Get-Check 'http://localhost:18081/check'
    }
}
if ($forward) { Stop-Process -Id $forward.Id -Force -ErrorAction SilentlyContinue }

if (-not $result) {
    Warn 'demo-service is not running, so the end-to-end check was skipped.'
    Info 'Run it from the IDE, or deploy it with: task demo:deploy'
}
else {
    Info ('Source: ' + $source)
    foreach ($svc in 'postgres', 'redis', 'kafka', 's3') {
        $r = $result.$svc
        if ($r -and $r.status -eq 'UP') { Ok ("$svc : " + $r.detail + ' (' + $r.ms + ' ms)') }
        elseif ($r) { Fail ("$svc : " + $r.error) }
        else { Fail ("$svc : no result returned") }
    }
}

Write-Host ''
if ($script:fails -gt 0) {
    Write-Host ('{0} check(s) failed.' -f $script:fails) -ForegroundColor Red
    exit 1
}
Write-Host 'Everything verified.' -ForegroundColor Green
exit 0
