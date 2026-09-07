# Digital Settlement — Mobile App

Flutter client for the same backend `web-admin` talks to (`../src`). Logs in
with an email/password already registered there (same `users` table, same
JWT), and covers four things from the phone:

- **Login** — `POST /auth/login`, same credentials as web-admin.
- **New Expense** — Pre-Event picker (or manual Unit/Advertiser/Brand/Activity
  Type entry when there's no Pre-Event), date/amount/purpose/POD/payment
  method/merchant/location, "use my location" via the device GPS, camera or
  gallery photo upload for Foto Kegiatan, and invoice photo/PDF upload with a
  simple merchant/total/tax summary.
- **Approvals** — pending expense (and Pre-Event) approval steps assigned to
  the signed-in user, with Approve / Reject (reason required).
- **Settlement** — lists Settlements for the user's POD(s) (or all, for
  Finance/Admin), "Create Settlement" to group the current user's bank-matched
  Expenses, and "Approve (Mark Complete)" for Finance/Admin on a DRAFT
  settlement.

Everything else from web-admin (master data management, bank-statement
auto-match upload, invoice OCR editing, reports) is intentionally out of scope
for this first mobile pass.

## Running it

```
cd mobile-app
flutter pub get
flutter run
```

### Pointing at the backend

The backend base URL is compiled in via `--dart-define`:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1   # Android emulator (default)
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1  # Chrome/web, Windows desktop
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000/api/v1  # physical device on the same LAN as the dev machine
```

Default (no flag) is `http://10.0.2.2:3000/api/v1`, the Android emulator's
alias for the host machine's `localhost` — start the NestJS API
(`npm run start:dev` in the repo root) before running the app.

The backend must be reachable over plain HTTP for local dev; Android's
cleartext-traffic block is disabled in `android/app/src/main/AndroidManifest.xml`
for that reason. Point `API_BASE_URL` at an HTTPS backend for anything beyond
local development.

## Architecture

Deliberately small - no code generation, no routing package, no state
management beyond `provider` + `ChangeNotifier` (`AuthService`) and
per-screen `StatefulWidget` + `FutureBuilder`.

```
lib/
  services/
    api_client.dart    JSON + multipart HTTP client, JWT bearer, error shape
                        matches web-admin's src/lib/api.ts
    auth_service.dart  session state, persisted via flutter_secure_storage
  models/               thin wrappers around the JSON the API already returns
  screens/
    login_screen.dart
    home_shell.dart     bottom-nav shell (Expenses / Approvals / Settlement / Profile)
    expenses/           list + New Expense form
    approvals/          pending approvals inbox
    settlements/        settlement list + create + mark-complete
  widgets/              small shared pieces (error view, photo picker row)
```

A 401 from any endpoint clears the stored session and drops back to the
login screen, the same behavior as web-admin.
