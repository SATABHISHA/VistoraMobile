# Store listing privacy checklist: attendance location

Vistora requests precise foreground device location only after an employee confirms an attendance clock-in or clock-out. The app does not request background location. Coordinates and any address resolved on the device are submitted to the Vistora API and stored with the attendance record. The Flutter app uses the native Android/iOS geocoding service to resolve an address; that platform service may process coordinates under its own service terms. If lookup is unavailable or returns no address, the punch still completes and stores the coordinates. Tenant HR/Admin and authorized supervisors can view the punch location and address; employees can view their own records.

Before each punch, the app presents an affirmative in-app disclosure covering precise coordinate collection, possible processing by the device's geocoding service, server storage, authorized viewers, and the lack of background tracking. The iOS purpose string explains attendance-only foreground use and address resolution. A privacy-policy link is available from the mobile profile screen and the policy describes native geocoding and browser behavior.

Before submitting a release, update the store declarations to match the release build and actual data handling:

- Google Play Data safety: declare precise location collected for app functionality and associated with the workforce account/attendance record. Do not declare background collection or advertising use. Describe any platform-service processing accurately in the applicable disclosure fields. Declare the applicable retention/deletion behavior from the tenant's attendance-record policy.
- Apple App Privacy: declare precise location as linked to the employee/account and used for app functionality; accurately disclose processing by platform services where required. Do not mark it as tracking if it is not used for tracking/advertising.
- Include `https://vistora.ahanova.in/privacy-policy` in the store privacy-policy field and verify it loads without authentication.
- Test first-run permission, precise-location permission, user denial, location-service disabled, native geocoder unavailable/offline/no-result, and a real attendance punch. Geocoding failure must not block attendance.

Browser attendance only uses the browser's foreground geolocation coordinates; it does not perform reverse geocoding or call an external geocoding provider.
