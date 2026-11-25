# UbiCaja - compila y carga el firmware con arduino-cli (core ESP32 3.3.13 y NimBLE 2.5.2 instalados en F:).
# Uso (en la carpeta archivos_fuente):
#   powershell -ExecutionPolicy Bypass -File .\Demo\cargar_firmware.ps1 -Placa etiqueta -Puerto COM5
#   powershell -ExecutionPolicy Bypass -File .\Demo\cargar_firmware.ps1 -Placa gateway  -Puerto COM6
# Para ver el puerto: conecta la placa y ejecuta  F:\Arduino15_ubicaja\bin\arduino-cli.exe board list
param(
  [Parameter(Mandatory)][ValidateSet('etiqueta','gateway')][string]$Placa,
  [Parameter(Mandatory)][string]$Puerto,
  [switch]$Monitor
)
$cli = 'F:\Arduino15_ubicaja\bin\arduino-cli.exe'
$cfg = 'F:\Arduino15_ubicaja\arduino-cli.yaml'
$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sketch = if ($Placa -eq 'etiqueta') { "$raiz\Firmware\Etiqueta_ESP32C3" } else { "$raiz\Firmware\Gateway_ESP32C3" }
$fqbn = 'esp32:esp32:esp32c3:CDCOnBoot=cdc,PartitionScheme=huge_app'

if ($Placa -eq 'gateway' -and -not (Test-Path "$sketch\secrets.h")) {
  Write-Host 'Falta Firmware\Gateway_ESP32C3\secrets.h (copiar de secrets_example.h y completar).' -ForegroundColor Red; exit 1
}
& $cli --config-file $cfg compile -b $fqbn --build-path "F:\Arduino15_ubicaja\build_$Placa" -u -p $Puerto $sketch
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Fallo. Si no conecta: mantener BOOT, pulsar RESET, soltar BOOT y reintentar.' -ForegroundColor Yellow; exit 1
}
if ($Monitor) { & $cli --config-file $cfg monitor -p $Puerto -c baudrate=115200 }
