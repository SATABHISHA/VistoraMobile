# Local Flutter launcher

Use the launcher from the repository root:

```powershell
.\scripts\run_flutter.ps1
```

It performs this flow:

1. Reads the devices currently visible to Flutter.
2. If wireless Android devices are detected, shows a numbered menu.
3. Lets you choose a wireless device or press `E` to use the emulator.
4. If no wireless Android device is detected, starts `flutter_emulator` and runs the app there.

The default local API URL is `http://10.0.2.2:8000/api/v1`, which is suitable for an Android emulator talking to a Laravel API on the host machine. Override it for a physical phone on the same network:

```powershell
.\scripts\run_flutter.ps1 -ApiBaseUrl "http://192.168.1.25:8000/api/v1"
```

You can also override the environment:

```powershell
.\scripts\run_flutter.ps1 -AppEnv staging -ApiBaseUrl "https://staging.example.com/api/v1"
```

## Wireless Android setup

Pair/connect the phone with Android Studio or ADB first. Confirm that Flutter can see it:

```powershell
flutter devices
```

If it is not listed, enable Wireless debugging on the phone and connect it with:

```powershell
adb pair PHONE_IP:PAIRING_PORT
adb connect PHONE_IP:ADB_PORT
```

## Emulator setup

The script prefers the checked-in local emulator ID `flutter_emulator`. If it is missing, create an Android emulator and run `flutter emulators` to inspect its ID.

If PowerShell blocks local scripts, enable them for your user once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
