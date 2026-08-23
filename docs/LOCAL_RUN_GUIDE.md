# Local Flutter launcher

Use the launcher from the repository root:

```powershell
.\scripts\run_flutter.ps1
```

It performs this flow:

1. Reads the devices currently visible to Flutter.
2. If physical Android devices are detected over USB or Wi-Fi, shows a numbered menu.
3. Lets you choose a physical device or press `E` to use the emulator.
4. If no wireless Android device is detected, starts `flutter_emulator` and runs the app there.

The launcher uses `http://10.0.2.2:8000/api/v1` for an Android emulator. When a wireless Android device is selected, it automatically detects the PC's Wi-Fi IPv4 address and uses that LAN URL. You can also override it explicitly:

```powershell
.\scripts\run_flutter.ps1 -ApiBaseUrl "http://192.168.1.25:8000/api/v1"
```

The Laravel development server must listen on the network interface, not only on loopback. Start it from the Laravel repository with:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

If Windows Firewall blocks port 8000, allow inbound TCP port 8000 on the private network. Keep the phone and PC on the same Wi-Fi network, and do not use `localhost`, `127.0.0.1`, or `10.0.2.2` in the physical-device API URL.

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
