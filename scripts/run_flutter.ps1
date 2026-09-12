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

function Get-AdbExecutable {
    $configuration = & flutter config --machine
    if ($LASTEXITCODE -eq 0) {
        $androidSdk = ($configuration -join "`n" | ConvertFrom-Json).'android-sdk'
        if ($androidSdk) {
            $configuredAdb = Join-Path $androidSdk 'platform-tools\adb.exe'
            if (Test-Path -LiteralPath $configuredAdb) { return $configuredAdb }
        }
    }

    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) { return $adbCommand.Source }
    throw "Could not find adb.exe. Check the Android SDK platform-tools installation."
}

function Enable-PhysicalDeviceApiTunnel([string]$DeviceId, [int]$Port) {
    $adb = Get-AdbExecutable
    & $adb -s $DeviceId reverse "tcp:$Port" "tcp:$Port"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not forward device port $Port to this PC. Keep the device connected with USB or Wireless Debugging and run: adb -s $DeviceId reverse tcp:$Port tcp:$Port"
    }
    Write-Host "Forwarded physical-device localhost:$Port to this PC." -ForegroundColor Green
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
$selectedPhysicalDevice = $null

if ($physicalDevices.Count -gt 0) {
    Write-Host "Physical Android device(s) found:" -ForegroundColor Green
    for ($i = 0; $i -lt $physicalDevices.Count; $i++) {
        Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $physicalDevices[$i].name, $physicalDevices[$i].id)
    }
    if ($connectedEmulators.Count -gt 0) {
        Write-Host ("  [E] Use connected Android emulator ({0})" -f $connectedEmulators[0].name)
    } else {
        Write-Host "  [E] Start Android emulator"
    }
    $selection = Read-Host "Choose a device"
    if ($selection -match "^[Ee]$") {
        if ($connectedEmulators.Count -gt 0) {
            $deviceId = $connectedEmulators[0].id
        } else {
            $deviceId = Start-AndroidEmulator "flutter_emulator"
        }
    } elseif ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $physicalDevices.Count) {
        $selectedPhysicalDevice = $physicalDevices[[int]$selection - 1]
        $deviceId = $selectedPhysicalDevice.id
    } else {
        throw "Invalid selection. Run the script again and choose one of the listed options."
    }
} elseif ($connectedEmulators.Count -gt 0) {
    # Reuse an emulator that is already running when no physical phone is
    # available for selection.
    $deviceId = $connectedEmulators[0].id
    Write-Host "Using connected Android emulator '$deviceId'." -ForegroundColor Green
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

if ($selectedPhysicalDevice) {
    $loopbackUrl = [regex]::Match(
        $ApiBaseUrl,
        '^http://(?:127\.0\.0\.1|localhost):(?<port>\d+)(?:/|$)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        $ApiBaseUrl = 'http://127.0.0.1:8000/api/v1'
        Enable-PhysicalDeviceApiTunnel $selectedPhysicalDevice.id 8000
    } elseif ($loopbackUrl.Success) {
        Enable-PhysicalDeviceApiTunnel $selectedPhysicalDevice.id ([int]$loopbackUrl.Groups['port'].Value)
    }
} elseif ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = 'http://10.0.2.2:8000/api/v1'
}

# For explicit LAN URLs, catch addresses that are not assigned to this PC.
if ($selectedPhysicalDevice -and $ApiBaseUrl -match '^http://(?<host>\d{1,3}(?:\.\d{1,3}){3}):(?<port>\d+)/' -and $Matches['host'] -notin @('127.0.0.1')) {
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
