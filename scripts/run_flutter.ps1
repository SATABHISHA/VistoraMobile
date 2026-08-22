[CmdletBinding()]
param(
    [string]$ApiBaseUrl = "http://10.0.2.2:8000/api/v1",
    [string]$AppEnv = "local"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Invoke-FlutterJson([string[]]$Arguments) {
    $json = & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter command failed: flutter $($Arguments -join ' ')"
    }
    return ($json -join "`n" | ConvertFrom-Json)
}

Write-Host "Vistora Mobile launcher" -ForegroundColor Cyan
Write-Host "Checking connected devices..."
$devices = @(Invoke-FlutterJson @("devices", "--machine"))

# Flutter does not expose a dedicated wireless flag. Android Wi-Fi ADB IDs are
# normally host:port (or contain 'wireless'), so keep the check intentionally
# conservative and only offer Android devices that match that convention.
$wirelessDevices = @($devices | Where-Object {
    $_.isSupported -and $_.targetPlatform -like "android-*" -and
    ($_.id -match ":\d+$" -or $_.id -match "(?i)wireless|adb[- ]?wifi")
})

if ($wirelessDevices.Count -gt 0) {
    Write-Host "Wireless Android device(s) found:" -ForegroundColor Green
    for ($i = 0; $i -lt $wirelessDevices.Count; $i++) {
        Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $wirelessDevices[$i].name, $wirelessDevices[$i].id)
    }
    Write-Host "  [E] Start Android emulator"
    $selection = Read-Host "Choose a device"

    if ($selection -match "^[Ee]$") {
        $deviceId = "flutter_emulator"
    } elseif ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $wirelessDevices.Count) {
        $deviceId = $wirelessDevices[[int]$selection - 1].id
    } else {
        throw "Invalid selection. Run the script again and choose one of the listed options."
    }
} else {
    $emulatorOutput = (& flutter emulators | Out-String)
    $deviceId = $null
    if ($emulatorOutput -match '(?m)^flutter_emulator\s+') {
        $deviceId = "flutter_emulator"
    } else {
        $emulatorLine = $emulatorOutput -split "`r?`n" |
            Where-Object { $_ -match '^\s*[A-Za-z0-9_.-]+\s+•' } |
            Select-Object -First 1
        if ($emulatorLine -match '^\s*([A-Za-z0-9_.-]+)\s+•') {
            $deviceId = $Matches[1]
        }
    }
    if (-not $deviceId) {
        throw "No wireless Android device or Android emulator was found. Create one with: flutter emulators --create"
    }
    Write-Host "No wireless Android device found. Starting emulator '$deviceId'..." -ForegroundColor Yellow
    & flutter emulators --launch $deviceId
    if ($LASTEXITCODE -ne 0) { throw "Could not start emulator '$deviceId'." }
    Write-Host "Waiting for the emulator to connect..."
    $runtimeDeviceId = $null
    for ($attempt = 1; $attempt -le 30 -and -not $runtimeDeviceId; $attempt++) {
        Start-Sleep -Seconds 2
        $runtimeDevices = @(Invoke-FlutterJson @("devices", "--machine"))
        $runtimeDevice = $runtimeDevices | Where-Object {
            $_.isSupported -and $_.targetPlatform -like "android-*" -and $_.id -match "^emulator-"
        } | Select-Object -First 1
        if ($runtimeDevice) { $runtimeDeviceId = $runtimeDevice.id }
    }
    if (-not $runtimeDeviceId) { throw "The Android emulator did not become ready within 60 seconds." }
    $deviceId = $runtimeDeviceId
}

Write-Host "Running on $deviceId" -ForegroundColor Green
& flutter run -d $deviceId `
    "--dart-define=APP_ENV=$AppEnv" `
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
exit $LASTEXITCODE
