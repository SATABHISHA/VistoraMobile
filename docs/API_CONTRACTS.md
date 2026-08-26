# Flutter-used API contracts

## Authentication

### POST `/auth/login`

- Authentication: public
- Body: `corpId`, `identity`, `password`
- Success: Sanctum `accessToken`, `tokenType`, basic `user`
- Errors: 401 invalid credentials, 403 inactive account, 422 validation
- Flutter: login and secure token persistence

### GET `/auth/me`

- Authentication: Sanctum bearer token
- Success: `user`, nullable `employee`, nullable `tenant`, `permissions`, and `features`
- Feature keys: `file_manager`, `mr`, `projects`, `geofence`
- Flutter: startup restoration, routing, role/permission state and optional modules

### POST `/auth/logout`

- Authentication: Sanctum bearer token
- Success: current access token revoked
- Flutter: explicit sign out

### POST `/auth/forgot-password`

- Authentication: public
- Body: `corpId`, `email`
- Errors: 422 validation, 429 attempt limit
- Flutter: forgot-password request

### POST `/auth/change-password`

- Authentication: Sanctum bearer token
- Body: `current_password`, `password`, `password_confirmation`
- Validation: new password minimum 10 characters and confirmed
- Success: password changed; other tokens revoked when a token-authenticated request is used
- Errors: 422 invalid current password or validation
- Flutter: Profile and Security screen

All endpoints are relative to the configured `/api/v1` base URL.

## Attendance

### GET `/attendance/me/today`

- Authentication: Sanctum and tenant context
- Success: linked `employee`, nullable `attendance`, `canClockIn`, `canClockOut`, server time and geofence configuration
- Flutter: dashboard and today's attendance card

### POST `/attendance/clock-in`

### POST `/attendance/clock-out`

- Authentication: Sanctum and tenant context
- Body: optional `latitude`, `longitude`, `accuracy_meters`, `client_timestamp`; coordinates are required when the tenant geofence is enabled
- Authorization: always operates on the employee linked to the authenticated user
- Server authority: Laravel validates tenant geofence configuration and calculates distance
- Errors: 422 missing location, outside geofence, duplicate punch or invalid punch sequence
- Flutter: location is requested only when the returned geofence is enabled

### GET `/attendance/calendar`

- Authentication: Sanctum and tenant context
- Query: `employee_id`, `month`, `year`
- Authorization: Laravel applies `EmployeeAccess::canView`
- Success: employee, calendar days and summary; recorded days include `id` for regularization
- Flutter: responsive monthly calendar

### POST `/attendance/{attendance}/regularize`

- Authentication: Sanctum and tenant context
- Body: required `reason`; optional `requested_values`
- Authorization: requester must be allowed to view the employee attendance record
- Flutter: regularization dialog from a recorded calendar day

## Leave

### GET `/leave/summary/me`

- Authentication: Sanctum and tenant context
- Query: optional `year`, `month`
- Success: linked employee, total balances, status counts, leave-type breakup and monthly absence count
- Flutter: dashboard and leave summary

### GET `/leave`

- Authentication: Sanctum and tenant context
- Query: optional `perPage`, `status`, `q` (employee name/code)
- Authorization: Laravel scopes records through `EmployeeAccess::visibleIds`
- Success: paginated requests with employee and leave type
- Flutter: employee history; Admin/HR approval queue; Supervisor subordinate queue

### POST `/leave/{leave}/approve`, `/reject`, `/revert`

- Authentication: Sanctum and tenant context
- Authorization: Laravel `EmployeeAccess::canManage`; Supervisor actions are limited to manageable subordinates
- Body: approve accepts `leave_type_id` and optional `note`; reject/revert accept optional `note`
- Flutter: role-aware approve, reject and revert sheets; the supervisor's own request is excluded from the subordinate queue

### POST `/leave`

- Authentication: Sanctum and tenant context
- Body: `leave_type_id`, `start_date`, `end_date`, optional `reason`
- Authorization: non-manager users can apply only for their linked employee profile; Flutter does not submit `employee_id`
- Validation: valid tenant-scoped records, valid dates and reason up to 500 characters
- Success: pending leave request
- Flutter: apply-leave bottom sheet

## Payslips

### GET `/payroll/me/payslips`

- Authentication: Sanctum and tenant context
- Query: optional `year`, `month`, `employee_id`, `q`, `perPage`
- Authorization: Employee and Supervisor responses are restricted to the authenticated user's own linked employee; Admin/HR can query tenant-visible employees
- Success: paginated payslips with payroll employee, employee and released cycle data plus `company_name`
- Flutter: Employee/Supervisor month-year list and detail/download; Admin/HR employee search, month/year filtering and paginated employee cards

The existing Laravel portal also renders employee payslip PDFs client-side. Flutter follows that behavior and does not expose internal `file_path` values.

Payslip presentation uses the authenticated tenant's `company_name`; the Vistora product name is not printed on employee salary statements.

## Payroll administration

### GET `/payroll/cycles`

- Authentication: Sanctum and tenant context
- Roles: Admin or HR
- Query: `year`, `month`, optional pagination
- Success: tenant company branding and payroll cycles with employee payroll rows and authoritative attendance snapshots
- Flutter: period selector, payroll totals, employee deduction details

### POST `/payroll/cycles/initiate`

- Authentication: Sanctum, tenant context, Admin/HR role
- Body: `year`, `month`
- Behavior: creates the cycle and calculates payroll from tenant-scoped salary, attendance, approved/pending leave, holidays and weekends

### POST `/payroll/cycles/{cycle}/calculate-deductions`

- Authentication: Sanctum, tenant context, Admin/HR role
- Body: optional `employee_ids` array for targeted recalculation; omit for the full cycle
- Server rules: approved paid leave is protected; pending/rejected/unpaid leave and missing attendance are deductible; holidays and weekends are excluded
- Errors: 409 when the payroll cycle is already released
- Flutter: Calculate & Deduct and per-employee Recalculate actions

### POST `/payroll/cycles/{cycle}/rollback-deductions`

- Authentication: Sanctum, tenant context, Admin/HR role
- Body: optional `employee_ids` array; omit for the full cycle
- Behavior: reverses attendance/leave deductions without deleting the payroll cycle; recalculation remains available
- Errors: 409 when the payroll cycle is already released
- Flutter: Rollback Deductions and per-employee Undo deduction actions

### POST `/payroll/cycles/{cycle}/rollback`

- Authentication: Sanctum, tenant context, Admin/HR role
- Behavior: withdraws a released cycle and associated released payslips before returning it to draft
- Flutter: separately confirmed Rollback Released Cycle action

### POST `/payroll/cycles/{cycle}/hold`, `/release-request`, `/release`

- Authentication: Sanctum, tenant context, Admin/HR role
- Behavior: moves the cycle on hold or performs the existing maker/checker release workflow
- Flutter: role-authorized Put On Hold and Release Payroll controls with confirmation and refresh

## Employee work

### GET `/projects`

- Authentication: Sanctum, tenant context and project feature middleware
- Authorization: Laravel restricts non-manager users through visible employee assignments
- Success: paginated projects and assignments
- Flutter: shown only when the authenticated tenant reports `features.projects = true`

### POST `/projects/{project}/updates`

- Authentication: Sanctum, tenant context and project feature middleware
- Body: `assignment_id`, `period_type`, `period_start`, optional `period_end`, `progress_percent`, `achievements`, `blockers`, `next_plan`
- Authorization: an employee can submit only against their own assignment; Laravel remains authoritative
- Flutter: project progress bottom sheet

### GET `/performance`

- Authentication: Sanctum and tenant context
- Query: authenticated employee ID plus optional month/year and pagination
- Authorization: Laravel applies `EmployeeAccess::canView` and visible employee scope
- Flutter: read-only employee performance history

### GET `/recruitment/interviews/mine`

- Authentication: Sanctum and tenant context
- Authorization: returns only interviews whose panelist list contains the authenticated user
- Flutter: assigned interview panel tasks

### POST `/recruitment/interviews/{interview}/feedback`

- Authentication: Sanctum and tenant context
- Body: rating 1–5, recommendation (`strong_hire`, `hire`, `hold`, `reject`) and feedback up to 5000 characters
- Authorization: Laravel verifies the authenticated user is an assigned panelist
- Flutter: create or update interview feedback

## Holidays

### GET `/holidays`

- Authentication: Sanctum and tenant context
- Roles: all authenticated tenant users
- Query: optional `year`, `from`, `to`, `upcoming`; `perPage` controls pagination
- Success: tenant-scoped paginated holidays with `id`, `date`, `name`, and `type`
- Flutter: dashboard upcoming holidays and year-filtered calendar

### POST `/holidays`

### PUT `/holidays/{holiday}`

### DELETE `/holidays/{holiday}`

- Authentication: Sanctum, tenant context and Admin/HR role middleware
- Body: `date`, `name`, `type` (`National`, `Restricted`, or `Company`)
- Validation: date/name combination is unique within the authenticated tenant
- Flutter: holiday create, edit and remove

### POST `/holidays/import`

- Authentication: Sanctum, tenant context and Admin/HR role middleware
- Body: `items`, up to 500 validated holiday objects
- Behavior: tenant-scoped idempotent import by date/name
- Laravel Blade: settings CSV import; browser storage is no longer the holiday source of truth. If the new tenant calendar is empty, the settings page performs a one-time import of that browser's legacy `vistora_holidays` data and removes the legacy key after success.

## Medical Representative

All MR data endpoints require Sanctum, tenant context and the tenant MR feature middleware. Flutter also guards navigation using the authenticated `features.mr` value; Laravel remains authoritative.

### GET `/mr/metadata`

- Success: role-scoped employees, tenant states/branches/business units, and `settings.max_locations_per_doctor`
- Supervisor employee options contain subordinates only; Admin/HR receive tenant employees
- Flutter: location, doctor-mapping and assignment forms

### GET/PUT `/mr/settings`

- Manager roles: Admin, HR, Supervisor and Superadmin
- Body: `max_locations_per_doctor` from 1 to 50
- Rule: the value cannot be lowered below the largest existing doctor mapping
- Flutter: audited tenant-wide MR settings screen

### GET/POST `/mr/doctors`

### PUT/DELETE `/mr/doctors/{doctor}`

- Manager roles: Admin, HR, Supervisor and Superadmin for writes
- Filters: `q`, `status`, `date`, `year`, pagination
- Validation: name, optional specialization/contact details, status, and mapped `location_ids`
- Rule: at least one location is required by the Flutter workflow and Laravel enforces the tenant mapping limit
- Flutter: searchable doctor CRUD, existing-location mapping and inline new-location creation

### GET/PUT `/mr/doctors/{doctor}/locations`

- Success: active locations mapped to the doctor
- PUT body: `location_ids` and/or nested new `locations`
- Laravel validates tenant ownership and the configured maximum before synchronizing

### GET/POST `/mr/locations`

### PUT/DELETE `/mr/locations/{location}`

- Filters: `q`, `status`, `state_id`, `date`, `year`, pagination
- Validation: address, tenant state, optional branch/business unit, optional latitude/longitude/radius, and status
- Geofence exists only when latitude, longitude and radius are all configured
- Flutter: organisation-aware location and optional GPS boundary CRUD

### GET/POST `/mr/territories`

### PUT/DELETE `/mr/territories/{territory}`

- Filters: doctor/state/branch/business-unit IDs, active flag, search and pagination
- Validation: doctor, state, branch and business unit are checked by Laravel tenant services
- Legacy compatibility only. New Flutter assignment flows use doctor-location mappings and do not expose territory restrictions.

### GET/POST `/mr/assignments`

### PUT/DELETE `/mr/assignments/{assignment}`

### POST `/mr/assignments/{assignment}/cancel`

- Filters: `mine`, `upcoming`, employee/doctor/location fields, status, visit date, year, employee/doctor text search and pagination
- Authorization: Admin/HR see tenant records; Supervisor/Superadmin are subordinate-scoped; Employee uses own assignments
- Validation: Laravel verifies employee scope and that the selected location is mapped to the doctor; employee area does not restrict assignment
- Immutability: edit/delete/cancel are blocked after a report has ever been submitted, including after employee rollback
- Flutter: searchable employee/doctor selection, dependent mapped-location dropdown, automatic single-location selection, edit/delete and visit details

### POST `/mr/assignments/{assignment}/visit-report`

### PUT `/mr/visit-reports/{report}`

### POST `/mr/visit-reports/{report}/submit`

- Authorization: only the assigned employee can create, edit or submit
- Body: `visited_at`, `check_in_source`, optional captured address/notes/outcome; GPS reports include latitude, longitude and device accuracy
- Server authority: Laravel calculates distance, validates geofence/assignment/tenant and controls status
- When the mapped doctor location has latitude, longitude and radius, GPS is mandatory and submission is rejected outside the radius
- When no complete geofence exists, captured GPS is stored without a radius restriction and a manual fallback remains available
- Flutter: GPS capture, permission failures, draft save and submission

### POST `/mr/visit-reports/{report}/rollback-submission`

- Authorization: assigned employee only, while the report is submitted and awaiting review
- Body: required `rollback_notes`
- Result: report returns to draft; notes, actor and time are retained; the assignment remains permanently protected from edit/delete because it was previously submitted

### GET `/mr/visit-reports`

### POST `/mr/visit-reports/{report}/approve`

### POST `/mr/visit-reports/{report}/reject`

### POST `/mr/visit-reports/{report}/revert`

- Filters: `mine`, status, visited date, year, search and pagination
- Authorization: role and subordinate scope is enforced by Laravel
- Rejection body: required `review_notes`
- Flutter: employee report history and manager approval workflow

### GET `/mr/audit-logs`

- Filters: `q`, `action`, `date`, `year`, pagination
- Authorization: Admin/HR receive tenant MR events; Supervisor receives own/subordinate MR events
- Includes doctor/location/settings/assignment/report create, update, delete, submit, rollback and review events with actor and subject employee context

## MR Field Expenses

All endpoints require Sanctum, tenant context and the enabled MR module. Amount totals are calculated by Laravel; clients must treat returned totals as authoritative.

### GET `/mr/expense-claims`

- Query: `mine`, `reviewable`, `employee_id`, `status`, `duty_type`, `q`, `date`, `month`, `year`, `page`, `per_page`
- Scope: Employee receives own claims. Supervisor review mode receives direct-subordinate claims only. Admin/HR review mode receives tenant claims except the reviewer's own employee claim.
- Search: employee name/code, area, travel endpoints and travel mode
- Success: paginated claim rows, employee snapshot, review/rollback actors, payroll-inclusion state and server-calculated capability flags
- Flutter: My Expenses and Expense Approvals tabs

### POST `/mr/expense-claims`

### PUT `/mr/expense-claims/{claim}`

- Owner: authenticated user's linked employee only
- Body: `expense_date`, `duty_type` (`hq`, `ex_hq`, `outstation`), `area_covered`, `travel_from`, `travel_to`, `mode_of_travel`; optional allowance, working allowance, distance, fare, courier, other-doctor expense and remarks fields
- Auto fields: employee number/name/designation/headquarters/state/business unit are snapshotted from the authenticated employee record
- Server calculation: `total_allowance = allowance_amount + working_allowance_amount`; `total_expense = total_allowance + fare_amount + courier_charges + other_doctor_expenses`
- Validation: one daily statement per employee/date; date cannot be future; monetary and distance values must be non-negative
- Edit state: draft or rejected only

### POST `/mr/expense-claims/{claim}/submit`

### POST `/mr/expense-claims/{claim}/rollback-submission`

- Owner only
- Submit requires a positive total and changes the claim to `submitted`
- Rollback requires `rollback_notes` and is permitted only before a manager reviews the claim
- Every transition is written to the MR audit log

### POST `/mr/expense-claims/{claim}/approve`

### POST `/mr/expense-claims/{claim}/reject`

### POST `/mr/expense-claims/{claim}/revert`

- Roles: Admin, HR, Supervisor and tenant-context Superadmin through manager middleware
- Authorization: Supervisors can review only direct-subordinate claims and never their own. Admin/HR review Supervisor and employee claims but never their own linked claim.
- Reject/revert body: required `review_notes`; approve notes are optional
- Approved claims are immutable to employees
- An approval included in payroll cannot be reverted until its payroll inclusion is reversed

## MR expense payroll inclusion

### POST `/payroll/cycles/{cycle}/calculate-mr-expenses`

### POST `/payroll/cycles/{cycle}/rollback-mr-expenses`

- Authentication: Sanctum, tenant context and Admin/HR role
- Body: optional `employee_ids`; omit to process all cycle employees
- Apply rule: only approved claims belonging to the selected payroll month and employee are included
- Idempotency: the inclusion ledger prevents duplicate additions; rerunning recalculates the authoritative included total
- Rollback: marks matching ledger rows reverted and removes only the MR reimbursement amount
- Lock: released cycles return HTTP 409 until the existing payroll rollback workflow returns them to draft
- Payroll effect: MR expense is a reimbursement added after salary/arrears and attendance deductions; it is printed separately on tenant-branded payslips
- Flutter: bulk multi-select and individual Include/Undo actions

## Employee and salary administration

### GET `/employees`

- Roles/scope: Laravel applies `EmployeeAccess::visibleIds`; Admin/HR see tenant employees and Supervisor sees allowed employees
- Query: `q`, `status`, `page`, `perPage`
- Success: paginated employees with organisation relations, supervisors, login identity and current salary snapshot
- Flutter: Employee Directory and supporting employee selectors

### GET `/employees-salary-structures`

- Roles: Admin, HR
- Query: `year`; optional `q`; `paginated=1`, `page`, `perPage` enable the mobile paginator
- Backward compatibility: without `paginated=1`, the existing Laravel Salary/Payroll screens receive the original array contract
- Flutter: searchable salary roster

### GET `/employees/{employee}/salary-structures`

- Roles: Admin, HR
- Success: employee, annual structures and revision history

### POST `/employees/{employee}/salary-revisions`

- Roles: Admin, HR
- Body: `year`, `revision_date`, positive `increment_amount`, optional `arrear_effective_date`
- Server behavior: proportionally revises the persisted structure, calculates arrears and refreshes only mutable payroll cycles

### DELETE `/employees/{employee}/salary-revisions/{revision}`

- Roles: Admin, HR
- Rules: only the latest applied revision can be rolled back; disbursed arrears cannot be reversed
- Flutter: year-filtered structure detail and safe rollback confirmation

## Recruitment, letters and final settlement

### GET/POST/PUT `/recruitment`

### POST `/recruitment/{candidate}/pipeline-action`

### POST `/recruitment/candidates/{candidate}/interviews`

- Roles: Admin, HR
- Candidate list supports server-side status/search pagination
- Interview body: schedule, panel user IDs, mode and optional notes; Laravel notifications remain authoritative
- Flutter: recruitment pipeline and interview scheduling

### GET/POST `/recruitment/offer-templates`

### PUT `/recruitment/offer-templates/{template}`

### GET `/recruitment/offers`

### POST `/recruitment/candidates/{candidate}/offer-letter`

### POST `/recruitment/offers/{offer}/status`

- Roles: Admin, HR
- Offer list filters: `q`, `month`, `year`, `page`, `per_page`
- Generation body: `template_id`, `position`, `start_date`, `offered_ctc`
- Server output: persistent tenant-branded rendered HTML with candidate/template relations and generation metadata
- Flutter: template authoring, generation, preview and sent/accepted/declined/revoked state changes

### GET `/appointment-templates`

### GET `/employee-documents`

### POST `/employees/{employee}/appointment-letters`

- Roles: Admin, HR for generation
- Body: `template_id` and optional designation, joining date and place overrides
- Laravel merges employee, salary and tenant branding fields
- Flutter: generated-letter list, preview and appointment generation

### GET `/final-settlements`

### POST `/employees/{employee}/final-settlement/calculate`

### PUT `/employees/{employee}/final-settlement`

### POST `/final-settlements/{settlement}/status`

### POST `/final-settlements/{settlement}/revoke`

### POST `/final-settlements/disburse`

- Roles: Admin, HR
- Laravel calculates salary due and validates workflow transitions; Flutter supplies editable bonus/deduction/notes values and confirmed employee dates
- Disbursement accepts `settlement_ids` for explicit multi-selection

## Secure file manager

### GET `/file-manager`

- Roles: Admin, HR
- Query: optional `q`; `paginated=1`, `page`, `perPage` enable mobile pagination while the existing web response remains unchanged by default
- Success: folders and quota totals

### POST `/file-manager/folders`

### GET/DELETE `/file-manager/folders/{folder}`

### POST `/file-manager/folders/{folder}/files`

### GET `/file-manager/files/{file}/download`

### DELETE `/file-manager/files/{file}`

- Upload: multipart; Laravel validates tenant folder ownership and the existing file-size/type/quota rules
- Download/delete: tenant-scoped file authorization
- Flutter: create/open folders, upload with native file picker, secure download/open and delete

## Tenant and platform administration

### GET/PUT `/settings/company`

### GET/POST/PUT/DELETE organisation master endpoints

### GET/PUT `/settings/geofence`

### GET/PUT `/settings/smtp`; POST `/settings/smtp/test`

- Roles: Admin, HR according to the existing route middleware
- Flutter: Company Settings tabs; passwords/secrets are never rendered back or logged

### GET `/superadmin/dashboard`

### GET `/superadmin/companies`

### GET `/superadmin/payments`

- Role: Superadmin
- Query: `q` (tenant name, Corp ID or GSTIN), `month`, `year`, `page`, `perPage`
- Success: paginated payments with tenant identity and generated invoice number

### POST `/superadmin/payments`

### PUT/DELETE `/superadmin/payments/{payment}`

- Role: Superadmin
- Purpose: one of `installation`, `initial`, `advance`, `period`
- Period payments accept `monthly`, `quarterly`, `yearly`, or `custom`; Laravel derives standard start/end dates from `payment_date`
- Custom period requires `period_start` and `period_end`
- Payment mode: `cash`, `cheque`, `online`, `neft`, or `upi`; cheque mode requires `cheque_no`
- GST: disabled, `cgst_sgst`, or `igst`; Laravel validates provider configuration and tenant GSTIN, calculates split tax amounts, and rejects mixed tax modes
- Create and update are transactional. Delete soft-deletes the payment and invoice without touching tenant or HRMS data.

### GET `/superadmin/payments/{payment}/invoice`

- Role: Superadmin
- Success: typed `invoice`, `payment`, `provider`, and `client` objects, including immutable invoice number, provider/client snapshots, tax breakup, payment reference, billing period, and optional seal URL
- Flutter: animated preview plus native print/share/download PDF

### GET/PUT `/superadmin/settings`

### POST `/superadmin/settings/seal`

- Role: Superadmin
- Settings: provider/product identity, address, GSTIN, contact details, website, GST enablement, mutually exclusive GST mode/rates, and optional invoice seal
- Seal upload: multipart image (`png`, `jpg`, `jpeg`, or `webp`), maximum 2 MB

### PUT `/superadmin/tenants/{tenant}/billing-profile`

- Role: Superadmin
- Writable fields are deliberately restricted to `gstin` and `phone`; tenant name, Corp ID, features, and status cannot be changed through this endpoint

### GET `/tax-invoices`

### GET `/tax-invoices/{invoice}`

- Roles: Admin, HR
- Query: `q`, `month`, `year`, `page`, `perPage`
- Laravel derives `corp_id` from the authenticated Sanctum user and returns `404` for another tenant's invoice
- Flutter: tenant billing vault with live search, month/year filters, pagination, animated cards, full invoice preview, print and PDF sharing

### GET `/superadmin/onboarding`

- Role: Superadmin
- Company/payment/onboarding lists support server pagination and search/status or period filters
- Flutter: dedicated platform-only shell destinations; tenant attendance/payroll routes are not shown to Superadmin
