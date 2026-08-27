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

iOS simulator or physical iOS device (Xcode default):

```text
flutter run
```

iOS defaults to the live API (`https://vistora.ahanova.in/api/v1`). To override
it explicitly for a release build:

```text
flutter build ios --release --no-codesign --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://vistora.ahanova.in/api/v1
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

An iOS build must be run on macOS. Open `ios/Runner.xcworkspace` (not the
`.xcodeproj`) after `flutter pub get` and select a signing team in Xcode for a
physical device:

```text
open ios/Runner.xcworkspace
```

## Architecture

- `lib/app`: environment, routing, theme and global providers
- `lib/core`: API client, secure storage, connectivity, errors and reusable widgets
- `lib/features`: feature-first data, domain and presentation code

Sanctum tokens are stored with `flutter_secure_storage`. Widgets do not perform raw HTTP requests. Routing responds to session restoration, logout and API 401 responses.

## Implemented workspaces

- Employee/Supervisor: dashboard, attendance, leave, holidays, payslips, assigned projects, performance history, interview-panel feedback and profile/security.
- Admin/HR: employee directory, team attendance and leave actions, salary structures/revisions, payroll, recruitment, interview scheduling, offer letters, appointment letters, F&F settlements, secure files, company settings and a tenant-isolated tax-invoice vault.
- MR: doctor-location management, subordinate assignment, visit capture/review/audit and MR Field Expenses with approval and payroll reimbursement inclusion/reversal.
- Superadmin: platform overview, companies, onboarding, provider billing/GST settings, seal upload, and complete payment/tax-invoice administration.

The component/formula Salary Designer remains a desktop authoring surface because it configures complex pay templates. Flutter consumes the resulting authoritative structures and supports operational year search, detail, revisions, arrears and latest-revision rollback.

## Device permissions

- Android: coarse and fine location are declared for attendance and MR visit geofence validation.
- iOS: `NSLocationWhenInUseUsageDescription` explains attendance and MR visit location use.
- Location is requested only for a geofenced attendance action or when an employee captures an MR visit.
- Laravel performs all authoritative distance, geofence, assignment, tenant and approval decisions.

The Holidays feature uses tenant-scoped Laravel database persistence. Admin/HR users can manage the calendar; all authenticated tenant users can view it. The Laravel Blade settings and employee portal consume the same API, so holiday data is no longer device/browser-specific.

The MR workspace is available only when the tenant MR feature is enabled. It provides mapped doctor locations, an audited per-doctor location limit, subordinate-scoped planning, searchable/paginated records, dependent location selection, GPS/geofence visit reporting, employee submission rollback, and role-authorized review. Legacy territories remain a backend compatibility detail and are not required by the mobile assignment flow.

MR Field Expenses mirror the client workbook's daily HQ, EX HQ and Outstation statement. Employee identity/designation/headquarters are sourced from Laravel; expense totals, review authority and payroll inclusion are calculated and enforced by Laravel. Only approved claims for the payroll month can be included, and both bulk and individual inclusion have an auditable reversal.

Payslip PDFs are generated from the authenticated payslip API payload, matching the existing Laravel employee portal behavior, and can be previewed, printed or shared using the native platform sheet.

Payslip PDFs and previews use the authenticated tenant's company name. Admin and HR users also have a responsive Payroll Administration screen with server-authoritative attendance/leave deductions, bulk or per-employee recalculation, and reversible deduction rollback.

Platform billing supports installation, initial, advance and recurring-period payments. Laravel derives standard billing periods, validates mutually exclusive CGST/SGST or IGST, snapshots provider and tenant billing identities, and issues invoice numbers no longer than 12 characters. Superadmin can search, filter, edit, view, share or soft-delete invoices; Admin/HR users can view, print and share only invoices issued to their authenticated tenant.

Authenticated screens share a role-aware bottom navigation bar. Android back from any top-level section returns to Dashboard; back from Dashboard exits normally. Admin/HR payslips provide month/year filtering, employee search, identity/contact details, payroll totals, deduction breakdowns, and employee detail sheets.

See `docs/FLUTTER_PARITY_MATRIX.md` and `docs/API_CONTRACTS.md` for implementation status and mobile API contracts.
