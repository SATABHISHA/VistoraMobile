# Vistora Mobile

Production Flutter client for the Vistora Laravel HRMS. Android and iOS use the same feature-first codebase and consume the versioned Laravel API.

## Requirements

- Flutter 3.38.7 or a compatible stable release
- Dart 3.10.7 or compatible
- Android Studio/Android SDK for Android builds
- macOS with Xcode and CocoaPods for iOS builds
- A running Vistora Laravel API

## Install

```text
flutter pub get
```

## API environments

Configuration is provided with compile-time `dart-define` values. No API secret or live URL is committed.

Local Android emulator (default):

```text
flutter run --dart-define=APP_ENV=local --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

iOS simulator:

```text
flutter run --dart-define=APP_ENV=local --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Physical device on the same LAN:

```text
flutter run --dart-define=APP_ENV=local --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000/api/v1
```

Staging or production:

```text
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging.example.com/api/v1
flutter build apk --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Production must use HTTPS. Android cleartext traffic is enabled only in the debug manifest.

## Quality commands

```text
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

## Quick local run

On Windows, use the device-aware launcher. It offers detected wireless Android devices and otherwise starts the Android emulator automatically:

```powershell
.\scripts\run_flutter.ps1
```

See [`docs/LOCAL_RUN_GUIDE.md`](docs/LOCAL_RUN_GUIDE.md) for API URL overrides and wireless debugging setup.

An iOS build must be run on macOS:

```text
flutter build ios --no-codesign --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging.example.com/api/v1
```

## Architecture

- `lib/app`: environment, routing, theme and global providers
- `lib/core`: API client, secure storage, connectivity, errors and reusable widgets
- `lib/features`: feature-first data, domain and presentation code

Sanctum tokens are stored with `flutter_secure_storage`. Widgets do not perform raw HTTP requests. Routing responds to session restoration, logout and API 401 responses.

## Device permissions

- Android: coarse and fine location are declared for attendance and MR visit geofence validation.
- iOS: `NSLocationWhenInUseUsageDescription` explains attendance and MR visit location use.
- Location is requested only for a geofenced attendance action or when an employee captures an MR visit.
- Laravel performs all authoritative distance, geofence, assignment, tenant and approval decisions.

The Holidays feature uses tenant-scoped Laravel database persistence. Admin/HR users can manage the calendar; all authenticated tenant users can view it. The Laravel Blade settings and employee portal consume the same API, so holiday data is no longer device/browser-specific.

The MR workspace is available only when the tenant MR feature is enabled. It provides mapped doctor locations, an audited per-doctor location limit, subordinate-scoped planning, searchable/paginated records, dependent location selection, GPS/geofence visit reporting, employee submission rollback, and role-authorized review. Legacy territories remain a backend compatibility detail and are not required by the mobile assignment flow.

Payslip PDFs are generated from the authenticated payslip API payload, matching the existing Laravel employee portal behavior, and can be previewed, printed or shared using the native platform sheet.

Payslip PDFs and previews use the authenticated tenant's company name. Admin and HR users also have a responsive Payroll Administration screen with server-authoritative attendance/leave deductions, bulk or per-employee recalculation, and reversible deduction rollback.

Authenticated screens share a role-aware bottom navigation bar. Android back from any top-level section returns to Dashboard; back from Dashboard exits normally. Admin/HR payslips provide month/year filtering, employee search, identity/contact details, payroll totals, deduction breakdowns, and employee detail sheets.

See `docs/FLUTTER_PARITY_MATRIX.md` and `docs/API_CONTRACTS.md` for implementation status and mobile API contracts.
