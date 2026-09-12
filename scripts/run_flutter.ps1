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

function Start-AndroidEmulator([string]$EmulatorId) {
    Write-Host "Starting Android emulator '$EmulatorId'..." -ForegroundColor Yellow
    & flutter emulators --launch $EmulatorId
    if ($LASTEXITCODE -ne 0) { throw "Could not start emulator '$EmulatorId'." }

    Write-Host "Waiting for the emulator to connect..."
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        Start-Sleep -Seconds 2
        $runtimeDevices = @(Invoke-FlutterJson @("devices", "--machine"))
        $runtimeDevice = $runtimeDevices | Where-Object {
            $_.isSupported -and $_.targetPlatform -like "android-*" -and $_.emulator -and $_.id -match "^emulator-"
        } | Select-Object -First 1
        if ($runtimeDevice) { return $runtimeDevice.id }
    }
    throw "The Android emulator did not become ready within 60 seconds."
}

Write-Host "Vistora Mobile launcher" -ForegroundColor Cyan
Write-Host "Checking connected devices..."
$devices = @(Invoke-FlutterJson @("devices", "--machine"))

# Offer all detected physical Android devices, including USB and wireless ADB.
# The emulator is kept as a separate fallback option.
$physicalDevices = @($devices | Where-Object {
    $_.isSupported -and $_.targetPlatform -like "android-*" -and -not $_.emulator
})
$connectedEmulators = @($devices | Where-Object {
    $_.isSupported -and $_.targetPlatform -like "android-*" -and $_.emulator
})
$usingWirelessDevice = $false

if ($connectedEmulators.Count -gt 0) {
    # Reuse an emulator that is already running instead of launching a second
    # instance of the configured AVD (which can fail with exit code 1).
    $deviceId = $connectedEmulators[0].id
    Write-Host "Using connected Android emulator '$deviceId'." -ForegroundColor Green
} elseif ($physicalDevices.Count -gt 0) {
    Write-Host "Physical Android device(s) found:" -ForegroundColor Green
    for ($i = 0; $i -lt $physicalDevices.Count; $i++) {
        Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $physicalDevices[$i].name, $physicalDevices[$i].id)
    }
    Write-Host "  [E] Start Android emulator"
    $selection = Read-Host "Choose a device"
    $selectedPhysicalDevice = $null

    if ($selection -match "^[Ee]$") {
        $deviceId = Start-AndroidEmulator "flutter_emulator"
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
    $deviceId = Start-AndroidEmulator $deviceId
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

# A physical device cannot reach an old/private address that is not assigned
# to this development PC. Fail early with the current LAN address instead of
# letting the app appear to hang on login.
if ($ApiBaseUrl -match '^http://(?<host>\d{1,3}(?:\.\d{1,3}){3}):(?<port>\d+)/') {
    $localAddresses = @(Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual, Dhcp -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress)
    if ($localAddresses.Count -gt 0 -and $localAddresses -notcontains $Matches['host']) {
        throw "API URL host $($Matches['host']) is not assigned to this PC. Use a current LAN URL such as http://$($localAddresses[0]):$($Matches['port'])/api/v1. Start Laravel with: php artisan serve --host=0.0.0.0 --port=$($Matches['port'])"
    }
}

Write-Host "Running on $deviceId" -ForegroundColor Green
& flutter run -d $deviceId `
    "--dart-define=APP_ENV=$AppEnv" `
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
exit $LASTEXITCODE
