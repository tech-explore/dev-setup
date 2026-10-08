# port-forward.ps1 - expose the dev stack on localhost
# Start:  .\port-forward.ps1
# Stop:   .\port-forward.ps1 -Stop      (stops ALL kubectl port-forwards)
#
# Ports on localhost:
#   Postgres 5433, Redis 6379, Kafka 9092, RustFS S3 API 9000, RustFS console 9001
# Kafka's local port must match the advertised listener in kafka.yaml (localhost:9092).

param([switch]$Stop)

$ns = 'dev'

$forwards = @(
    @{ Name = 'postgres';      Target = 'svc/postgres'; Ports = '5433:5432' },
    @{ Name = 'redis';         Target = 'svc/redis';    Ports = '6379:6379' },
    @{ Name = 'kafka';         Target = 'pod/kafka-0';  Ports = '9092:9094' },
    @{ Name = 'rustfs-api';     Target = 'svc/rustfs';   Ports = '9000:9000' },
    @{ Name = 'rustfs-console'; Target = 'svc/rustfs';   Ports = '9001:9001' }
)

if ($Stop) {
    Get-CimInstance Win32_Process -Filter "Name = 'kubectl.exe'" |
        Where-Object { $_.CommandLine -match 'port-forward' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Write-Host 'Stopped all kubectl port-forwards.' -ForegroundColor Yellow
    return
}

foreach ($f in $forwards) {
    Start-Process -FilePath kubectl -WindowStyle Hidden `
        -ArgumentList @('-n', $ns, 'port-forward', $f.Target, $f.Ports)
    Write-Host ("[forward] {0,-14} localhost:{1}" -f $f.Name, $f.Ports.Split(':')[0]) -ForegroundColor Cyan
}

Write-Host "`nRunning in the background. If a pod restarts, its forward ends: run the script again." -ForegroundColor Green
