# Local Flutter launcher

From the VistoraMobile repository root, run:

```powershell
.\scripts\run_flutter.ps1
```
.\scripts\run_flutter.ps1 -AppEnv production -ApiBaseUrl "https://vistora.ahanova.in/api/v1"

The launcher lists connected physical Android devices first. Enter the number
for a phone, or press `E` to use the connected emulator (or start the configured
`flutter_emulator` if none is running).

## Local API routing

The launcher chooses the correct API address for the selected target:

| Target | API URL used by the app | How the PC server is reached |
| --- | --- | --- |
| Android emulator | `http://10.0.2.2:8000/api/v1` | Emulator host alias to the PC |
| Physical phone over USB or Wireless Debugging | `http://127.0.0.1:8000/api/v1` | `adb reverse` forwards the phone's port 8000 to the PC |

For normal development, start Laravel from the backend repository and leave it
listening on loopback:

```powershell
php artisan serve --host=127.0.0.1 --port=8000
```

The physical-device tunnel is set up by the launcher. The phone must remain
connected in `flutter devices` (over USB or Wireless Debugging). You do not
need to expose the local server to the LAN or open a firewall port when using
the launcher.

## USB phone setup

1. Enable Developer options and USB debugging on the phone.
2. Connect it to the PC and accept the debugging authorization prompt.
3. Confirm it appears in `flutter devices`.
4. Run the launcher and enter the phone's number.

## Wireless phone setup

Pair/connect the phone using Android's Wireless debugging, then verify it is
listed by Flutter:

```powershell
flutter devices
```

If it is not listed, use the pairing address and port shown on the phone:

```powershell
adb pair PHONE_IP:PAIRING_PORT
adb connect PHONE_IP:ADB_PORT
```

Run the launcher and choose the phone. It uses `adb reverse`, so the local
Laravel server can continue listening on `127.0.0.1`.

## Run without the launcher

For a physical phone, first create the tunnel, then use loopback as the app's
API URL:

```powershell
adb -s DEVICE_ID reverse tcp:8000 tcp:8000
flutter run -d DEVICE_ID `
  --dart-define=APP_ENV=local `
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

For the emulator, use `10.0.2.2` instead:

```powershell
flutter run -d emulator-5554 `
  --dart-define=APP_ENV=local `
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## LAN or remote API override

You can pass an explicit API URL:

```powershell
.\scripts\run_flutter.ps1 -ApiBaseUrl "https://staging.example.com/api/v1"
```

If you specifically want a physical phone to connect directly to the PC over
Wi-Fi instead of using `adb reverse`, start Laravel on all interfaces:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Then pass the PC's current LAN IPv4 address, and allow inbound TCP port 8000 on
the Windows private network firewall if prompted:

```powershell
.\scripts\run_flutter.ps1 -ApiBaseUrl "http://PC_LAN_IP:8000/api/v1"
```

Keep the phone and PC on the same network for this direct-LAN option. Do not
use `10.0.2.2` on a physical phone; that address is emulator-only.

If PowerShell blocks local scripts, enable them for your user once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
