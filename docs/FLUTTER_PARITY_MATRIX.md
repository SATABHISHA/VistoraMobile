# Flutter parity matrix

Status meanings: Not Started, Blocked by API, In Progress, Implemented, Tested, Verified, Not Applicable to Mobile.

| Feature | Roles | API status | Flutter status | Verification |
|---|---|---|---|---|
| Environment configuration | All | N/A | Verified | Analyze, tests, and Android debug build pass |
| Central API/error layer | All | Existing conventions supported | Implemented | Analyze and Android build pass; endpoint integration journeys remain |
| Secure Sanctum token storage | All | Ready | Implemented | Android build verified; device journey remains |
| Login and session restoration | All | Extended bootstrap contract | Tested | Laravel contract and Flutter parsing tests pass; device journey remains |
| Forgot password | All | Ready | Implemented | Integration test pending |
| Change password | All | Added in Phase 2 | Tested | Laravel feature test passes; device journey remains |
| Role/permission state | All | Extended bootstrap contract | Tested | Laravel contract and Flutter parsing tests pass |
| Tenant feature state | Tenant users | Extended bootstrap contract | Tested | Laravel contract and Flutter parsing tests pass |
| Guarded routing | All | N/A | Tested | Flutter widget test passes |
| Responsive theme/shared UI | All | N/A | Tested | Flutter widget test and Android build pass |
| Role-aware dashboard | All tenant roles | Existing dashboard APIs | Tested | Admin pending leave actions; Employee/Supervisor next-three-day MR visits; animated logout confirmation |
| Attendance/GPS | Employee/Admin/HR/Supervisor | Ready; calendar ID added in Phase 3 | Tested | Employee punch/calendar; Admin tenant roster; Supervisor searchable subordinate roster, detail, location and calendar |
| Leave | Employee/Admin/HR/Supervisor | Search/status and decision APIs ready | Tested | Employee apply/history; Admin tenant approvals; Supervisor subordinate approve/reject/revert; pending dashboard count |
| Payslips | Role scoped | Period/search API ready | Tested | Employee/Supervisor self-only month/year list; Admin employee search, period filter, pagination, detail and PDF preview/share |
| Employee project assignments | Role scoped | Ready when enabled | Tested | Assignment list and employee progress submission implemented; typed-model tests pass |
| Employee performance history | Role scoped | Ready | Tested | Score history and comments implemented; typed models used |
| Interview panel tasks | Assigned panelists | Ready | Tested | Assigned interviews and feedback create/update implemented; typed-model tests pass |
| Employees/subordinates | Admin/HR/Supervisor | Existing employee/attendance APIs | Tested | Role-labelled navigation; searchable subordinate attendance and employee detail sheet |
| Payroll/salary | Admin/HR | Calculation, hold, release, arrears and rollback APIs ready | Tested | Full mobile cycle actions plus server-authoritative leave/absence/holiday deductions and per-employee controls |
| Recruitment | Admin/HR | Partial API | Blocked by API | Phase 4/6
| File manager | Admin/HR | Ready when enabled | Not Started | Phase 4
| MR employee visits | Employee | Extended feature-gated API | Tested | Own paginated schedule/history, animated details, GPS/geofence or unrestricted capture, draft submission and noted rollback use typed models |
| MR supervisor workflow | Supervisor | Extended role-scoped API | Tested | Doctor/location CRUD, tenant MR setting, subordinate-only assignment and report review; all lists are searchable/filterable/paginated |
| MR administration | Admin/HR | Extended feature-gated API | Tested | Doctor-location mapping limit, dependent assignment locations, immutable submitted assignments, report review and audit log implemented |
| MR tenant feature guard | Tenant users | Existing `/mr/status` and auth feature state | Tested | Navigation and route are hidden/guarded when disabled |
| Holidays | All/Admin/HR | Added tenant-scoped persistence/API | Tested | Database-backed calendar, upcoming dashboard data, Admin/HR CRUD; Laravel tests and Flutter model tests pass |
| Superadmin | Superadmin | Mostly ready | Not Started | Phase 6
