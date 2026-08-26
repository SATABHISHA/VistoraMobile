# Flutter parity matrix

Status meanings: **Implemented** is API-connected, **Tested** has automated coverage, and **Verified** has also passed the current static-analysis/build gate. Desktop-only authoring tools are marked **Not Applicable to Mobile** only where the operational result is fully available on mobile.

## Foundation and access

| Feature | Roles | Laravel/API | Flutter | Evidence |
|---|---|---|---|---|
| Environment configuration | All | Existing | Verified | Local/staging/production `dart-define` support; Android emulator, LAN-device and iOS simulator guidance |
| Central API/error layer | All | Existing response conventions | Verified | One Dio client handles auth, 401/403/404/422/429/5xx, timeout, upload and download |
| Sanctum login/session/logout | All | Existing plus mobile bootstrap | Tested | Secure storage, restoration, expiry handling and animated logout confirmation |
| Role, permission and tenant feature state | All | `/auth/me` | Tested | Route guards and role-aware navigation; Laravel remains authoritative |
| Responsive navigation/accessibility | All | N/A | Tested | Shared bottom navigation, Android back behavior, SafeArea, scalable layouts and semantic controls |

## Employee and supervisor workflows

| Feature | Roles | Laravel/API | Flutter | Evidence |
|---|---|---|---|---|
| Role-aware dashboard | All tenant roles | Existing dashboard endpoints | Tested | Employee/Supervisor own metrics, manager pending actions, holidays and next-three-day MR visits |
| Own attendance and GPS punch | Employee, Supervisor | Ready | Tested | Clock-in/out, server geofence, current state, monthly calendar, in/out time and worked hours |
| Tenant/subordinate attendance | Admin, HR, Supervisor | Ready | Verified | Debounced name/code search, color-coded responsive data tables, live punch/location, detail sheet and monthly in/out/worked-hours table |
| Own leave | Employee, Supervisor | Ready | Tested | Correct approved-used balance, apply, status history, filters and pagination |
| Leave review | Admin, HR, Supervisor | Ready | Tested | Pending/approved/rejected tabs, live search, subordinate scope and approve/reject/revert |
| Holidays | All; Admin/HR writes | Database-backed API | Tested | Upcoming dashboard, calendar and manager CRUD; no browser-storage source of truth |
| Personal payslips | Employee, Supervisor | Self-scoped | Verified | Month/year pagination, brief cards, full Laravel-equivalent salary statement and tenant-branded PDF preview/share |
| Admin payslip directory | Admin, HR | Tenant-scoped search/filter API | Verified | Employee identity, month/year/search/pagination and the same detailed salary statement available from released payroll |
| Profile and security | All | Ready | Tested | Profile display and password change |
| Assigned project work | Employee, Supervisor | Feature-gated | Tested | Own assignments and progress submissions |
| Performance history | Employee, Supervisor | Not present in authoritative Laravel UI | Not Applicable to Mobile | Removed from Flutter navigation so mobile does not expose a Laravel-nonexistent module |
| Interview panel work | Assigned panelists | Ready | Verified | Assigned candidate, schedule/mode/contact/resume/notes, rating/recommendation and create/update feedback |

## HR and payroll administration

| Feature | Roles | Laravel/API | Flutter | Evidence |
|---|---|---|---|---|
| Employee directory | Admin, HR | Search/status/pagination | Tested | Add/edit, activate/deactivate, credentials, salary snapshot and attendance links |
| Salary structures and revisions | Admin, HR | Existing APIs plus optional mobile pagination/search | Verified | Search/year roster, pay-group assignment and breakup preview, structure update, revision/arrears history and safe latest-revision rollback |
| Component/formula Salary Designer | Admin, HR | Existing tenant-local designer plus API-backed employee structures | Verified | Mobile now provides Pay Components, Pay Groups, Formula Builder, Salary Structure, Revisions and Arrears workspaces with tenant-isolated persistence |
| Payroll cycles | Admin, HR | Ready | Verified | Initiate, employee selection, deduction calculation/rollback, hold, release/rollback, editable salary breakup, arrears, field expense and released salary-slip controls |
| MR expense payroll inclusion | Admin, HR | Added | Tested | Approved same-month claims, multi-select/bulk or individual include, reversible ledger and released-cycle lock |
| Recruitment pipeline | Admin, HR | Ready | Verified | Search, status pipeline actions, candidate creation, panelist interview assignment/rescheduling and notification |
| Offer letters | Admin, HR | Added persistent offers | Tested | Template authoring, tenant-branded generation, preview, list/filter and status actions |
| Appointment letters | Admin, HR | Ready | Tested | Employee/template selection, generation, paginated list and preview |
| Full & Final settlements | Admin, HR | Ready | Tested | Calculate, edit, review/approve/revoke and multi-record disbursement |
| Secure file manager | Admin, HR | Ready with optional pagination/search | Tested | Quota, folders, employee folders, upload, download/open and delete |
| Company settings | Admin, HR | Existing settings APIs | Tested | Company profile, organisation masters, geofence and SMTP settings/test |
| Platform administration | Superadmin | Extended billing and tenant APIs | Tested | Overview, companies, onboarding, restricted GSTIN/phone tenant details, provider GST settings and seal upload |
| Platform payments and tax invoices | Superadmin | Added transactional invoice APIs | Tested | Installation/initial/advance/period payments, automatic/custom periods, split GST, payment modes, search/filter/pagination, edit, soft-delete, preview, print and PDF share |
| Tenant tax-invoice vault | Admin, HR | Added tenant-isolated invoice APIs | Tested | Live search, month/year filters, pagination, animated summary cards, branded detail, print and PDF share/download |
| Public candidate application and employee invitation forms | Public links | Existing browser endpoints | Not Applicable to Mobile | These links intentionally open as responsive web onboarding forms; managers create employees directly in mobile |

## Medical Representative module

All rows are feature-gated by the authenticated tenant's MR setting and server-side tenant scope.

| Feature | Roles | Laravel/API | Flutter | Evidence |
|---|---|---|---|---|
| Doctors and mapped locations | Admin, HR, Supervisor | Extended | Tested | Search/pagination, CRUD, location mapping and configurable per-doctor limit |
| MR locations/geofence | Admin, HR, Supervisor | Extended | Tested | State/branch/business-unit fields, optional coordinates/radius and CRUD |
| Assignment planning | Admin, HR, Supervisor | Extended | Tested | Subordinate scope, searchable doctor, dependent mapped location, edit/delete before report submission |
| Employee visit reporting | Employee, Supervisor | Extended | Tested | Dashboard schedule, detail, GPS capture, optional geofence, draft/submit and noted rollback |
| Visit report review | Admin, HR, Supervisor | Extended | Tested | Employee/doctor/date/year search, pagination and subordinate-scoped approve/reject/revert |
| MR audit log | Admin, HR, Supervisor | Extended | Implemented | Actor, action, before/after context and employee scope are API-backed |
| MR Field Expenses — own claims | Employee, Supervisor | Added | Tested | HQ/EX HQ/Outstation daily form, server totals, draft/edit/submit/rollback, search and month/year filters |
| MR Field Expenses — approvals | Admin, HR, Supervisor | Added | Tested | Supervisor subordinate-only queue; Admin/HR review Supervisor and employee claims; approve/reject/revert |
| Legacy territory records | Managers | Existing compatibility API | Not Applicable to Mobile | New assignment flow intentionally uses doctor-location mappings without employee-area restrictions |

## Current verification boundary

- Laravel feature suite: all current feature tests pass.
- Flutter formatting, analysis and automated tests pass on the current code.
- Android debug APK build passes on the current code.
- iOS compilation requires macOS/Xcode and is therefore reviewed/configured, not built on this Windows host.
- Live deployment and live migrations are outside this local implementation unless explicitly requested in a separate deployment instruction.
