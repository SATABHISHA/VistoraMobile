# Vistora mobile updates

The app checks an optional release manifest when it opens. Configure the release
build with `UPDATE_MANIFEST_URL`, `ANDROID_STORE_URL`, and `IOS_STORE_URL`.

Example manifest:

```json
{
  "latest_version": "1.0.1",
  "minimum_version": "1.0.1",
  "latest_build": 2,
  "force_update": true,
  "message": "Please update Vistora to continue.",
  "android_url": "https://play.google.com/store/apps/details?id=in.ahanova.vistora_mobile",
  "ios_url": "https://apps.apple.com/app/id0000000000"
}
```

Build example:

```powershell
flutter build appbundle --release `
  --dart-define=APP_ENV=production `
  --dart-define=UPDATE_MANIFEST_URL=https://your-domain.example/vistora-mobile-version.json `
  --dart-define=ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=in.ahanova.vistora_mobile `
  --dart-define=IOS_STORE_URL=https://apps.apple.com/app/id0000000000
```

Android uses Google Play in-app update when the app was installed from Play. A
sideloaded APK or local emulator falls back to the configured store URL. iOS
opens the App Store update page; iOS does not permit an app to silently install
its own update. The blocking prompt remains until the installed version meets
the manifest version/build requirement.

For every release, increase the Flutter build number and publish the matching
version in the manifest. Keep the manifest on HTTPS and deploy it atomically.
