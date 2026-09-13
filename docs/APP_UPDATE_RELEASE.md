# Vistora mobile updates

The app checks for a newer release on every cold launch and when returning to the
foreground. Android checks Google Play's in-app update API; iOS compares the
installed version with the public App Store listing. An optional HTTPS release
manifest can additionally provide release notes and minimum-supported-version
policy. The release prompt is shown only when the store/manifest reports a newer
version; ordinary releases can be postponed, while a minimum-version/explicit
force policy cannot.

Example manifest:

```json
{
  "latest_version": "1.0.1",
  "minimum_version": "1.0.1",
  "latest_build": 2,
  "force_update": false,
  "message": "Please update Vistora to continue.",
  "android_url": "https://play.google.com/store/apps/details?id=in.ahanova.vistora_mobile",
  "ios_url": "https://apps.apple.com/app/id6805299271"
}
```

Build example:

```powershell
flutter build appbundle --release `
  --dart-define=APP_ENV=production `
  --dart-define=UPDATE_MANIFEST_URL=https://your-domain.example/vistora-mobile-version.json `
  --dart-define=ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=in.ahanova.vistora_mobile `
  --dart-define=IOS_APP_STORE_ID=6805299271 `
  --dart-define=IOS_STORE_URL=https://apps.apple.com/app/id6805299271
```

Android uses Google Play's immediate in-app update flow when Play permits it;
otherwise it uses Play's flexible background download flow, completing the
install when Play reports the download is ready. If neither flow is permitted,
the button opens the app's Play listing. Play update checks require a
compatible Play-installed build and that the release is available to that
account/device (including rollout and country targeting). A sideloaded APK or
local emulator falls back to the Play listing. iOS opens the public App Store
listing; consumer iOS apps cannot install their own App Store updates. Store
automatic-update settings remain controlled by each user's device/store.

The app cannot silently install a consumer Play Store or App Store release one
week later. Play's flexible flow downloads in the background only after the
user starts/accepts that flow; it is not a silent timer-based install. For a
critical release after a grace period, publish an updated manifest with
`minimum_version` set to the required version (or explicitly set
`force_update: true`); the app will then require the user to complete the
platform's update flow. The release manifest must be updated when the store
release is available, and store review/rollout timing is controlled by Google
and Apple.

The Android Play listing URL defaults to this app's package ID. For iOS, the app
looks up its App Store listing by numeric listing ID and uses that listing's
update URL; `IOS_APP_STORE_ID` and `IOS_STORE_URL` can override the defaults.
This fix is prepared as version `1.0.5+8` (Android version code 8 / iOS build
8). Existing installs need this corrected store build once; after that, the
launch/resume check can prompt them about later releases. Increase the Flutter
build number for each release and publish the matching version in the manifest
if using one. Keep the manifest on HTTPS and deploy it atomically.
