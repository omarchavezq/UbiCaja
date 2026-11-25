# UbiCaja - arranque de la demo. Ejecutar en PowerShell COMO ADMINISTRADOR:
#   powershell -ExecutionPolicy Bypass -File .\Demo\iniciar_demo.ps1
$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$mosq = 'C:\Program Files\mosquitto\mosquitto.exe'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host 'Abre PowerShell como Administrador y vuelve a ejecutar.' -ForegroundColor Red; exit 1 }

# 1) El servicio Mosquitto de Windows solo escucha en localhost: se detiene para usar la config de la demo.
if ((Get-Service mosquitto -ErrorAction SilentlyContinue).Status -eq 'Running') { Stop-Service mosquitto; Write-Host 'Servicio mosquitto detenido.' }

# 2) Firewall: MQTT (1883), WebSocket (9001) y la página web de la app (8080), en todos los perfiles.
if (-not (Get-NetFirewallRule -DisplayName 'UbiCaja demo' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'UbiCaja demo' -Direction Inbound -Protocol TCP -LocalPort 1883,9001,8080 -Action Allow -Profile Any | Out-Null
  Write-Host 'Regla de firewall creada.'
}

# 3) IP de la laptop (hotspot del iPhone = 172.20.10.x)
$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254)' } | Select-Object -ExpandProperty IPAddress
Write-Host "IPs de esta laptop: $($ips -join ', ')" -ForegroundColor Cyan
$hot = $ips | Where-Object { $_ -like '172.20.10.*' } | Select-Object -First 1
if ($hot) { Write-Host "IP en el hotspot del iPhone: $hot  -> debe coincidir con MQTT_HOST en secrets.h" -ForegroundColor Green }
else { Write-Host 'No se detecta el hotspot del iPhone (172.20.10.x). ¿La laptop está conectada a él?' -ForegroundColor Yellow }

# 4) Servidor web de la app Flutter (si ya se compiló con: flutter build web)
$web = Join-Path $aqui '..\Flutter\build\web'
if (Test-Path $web) {
  Start-Process python -ArgumentList '-m','http.server','8080','-d',(Resolve-Path $web) -WindowStyle Minimized
  if ($hot) { Write-Host "App en el iPhone (Safari): http://$hot`:8080" -ForegroundColor Green }
} else { Write-Host 'No hay Flutter\build\web: la app web no se servirá (usar MQTTX como respaldo).' -ForegroundColor Yellow }

# 5) Broker en primer plano (Ctrl+C para cerrar). -v muestra cada mensaje: útil para enseñar el flujo.
Write-Host 'Iniciando Mosquitto (1883 TCP + 9001 WebSocket)...' -ForegroundColor Cyan
& $mosq -c (Join-Path $aqui 'mosquitto_demo.conf') -v
