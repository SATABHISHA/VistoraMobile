[CmdletBinding()]
param(
    [string]$ApiBaseUrl = "",
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

# Offer all detected physical Android devices, including USB and wireless ADB.
# The emulator is kept as a separate fallback option.
$physicalDevices = @($devices | Where-Object {
    $_.isSupported -and $_.targetPlatform -like "android-*" -and -not $_.emulator
})
$usingWirelessDevice = $false

if ($physicalDevices.Count -gt 0) {
    Write-Host "Physical Android device(s) found:" -ForegroundColor Green
    for ($i = 0; $i -lt $physicalDevices.Count; $i++) {
        Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $physicalDevices[$i].name, $physicalDevices[$i].id)
    }
    Write-Host "  [E] Start Android emulator"
    $selection = Read-Host "Choose a device"
    $selectedPhysicalDevice = $null

    if ($selection -match "^[Ee]$") {
        $deviceId = "flutter_emulator"
    } elseif ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $physicalDevices.Count) {
        $selectedPhysicalDevice = $physicalDevices[[int]$selection - 1]
        $deviceId = $selectedPhysicalDevice.id
    } else {
        throw "Invalid selection. Run the script again and choose one of the listed options."
    }
    $usingWirelessDevice = $selectedPhysicalDevice -and $selectedPhysicalDevice.id -match ":\d+$|(?i)wireless|adb[- ]?wifi"
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

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    if ($usingWirelessDevice) {
        $lanIp = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi' -PrefixOrigin Manual, Dhcp -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -ExpandProperty IPAddress -First 1
        if (-not $lanIp) {
            throw "Could not detect the PC Wi-Fi IPv4 address. Pass -ApiBaseUrl explicitly, for example http://192.168.0.125:8000/api/v1"
        }
        $ApiBaseUrl = "http://$lanIp:8000/api/v1"
        Write-Host "Using LAN API URL $ApiBaseUrl for the wireless device." -ForegroundColor Green
    } else {
        $ApiBaseUrl = "http://10.0.2.2:8000/api/v1"
    }
}

Write-Host "Running on $deviceId" -ForegroundColor Green
& flutter run -d $deviceId `
    "--dart-define=APP_ENV=$AppEnv" `
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
exit $LASTEXITCODE
