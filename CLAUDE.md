# CLAUDE.md — digital_settlement_mobile

Guide for Claude Code working in this repo. Flutter client for **Digital Settlement**,
consuming the `digital_settlement_be` API (sibling repo) — same login/JWT/users table as
the web admin (`digital_settlement_fe`).

## Scope

Covers 4 flows only: Login, New Expense (Pre-Event picker, GPS location, camera/gallery
photo, invoice photo/PDF + OCR summary), Approvals (approve/reject pending steps),
Settlement (list/create/mark-complete, Finance/Admin scoped). Master-data management,
bank-statement auto-match upload, invoice OCR editing, and reports are explicitly out of
scope for this app — those live in the web admin. **Don't add them here without checking
with the user first** — the narrow scope is deliberate, not a gap to fill opportunistically.

## Stack

Flutter/Dart SDK `^3.10.4`. **State management**: `provider` + `ChangeNotifier`, but only
for session state (`AuthService`) — everything else is per-screen `StatefulWidget` +
`FutureBuilder`/manual `setState`. No bloc/riverpod/getx, no code generation, no routing
package (plain `Navigator` push/pop). No get_it/injectable — DI is manual via
`MultiProvider`/`ProxyProvider` in `main.dart`.

**Don't introduce bloc/riverpod/get_it/a routing package** for a new screen — follow the
existing StatefulWidget + FutureBuilder pattern unless the user asks to change the
architecture.

- Networking: raw `http` package wrapped in `lib/services/api_client.dart` (`ApiClient`) —
  JSON GET/POST/PATCH + multipart `uploadFile`, JWT bearer header. Deliberately mirrors
  `digital_settlement_fe`'s `src/lib/api.ts` (same endpoints/error shape) — check that file
  when adding a new API call here. Any non-2xx 401 calls `auth.logout()` and throws,
  bouncing the UI back to login via `AuthGate` in `main.dart`.
- Local storage: `flutter_secure_storage` (Keystore/Keychain) — `accessToken`,
  `refreshToken`, serialized `user` JSON, managed in `lib/services/auth_service.dart`.
- `image_picker` (camera/gallery), `geolocator` (GPS), `intl` (id_ID formatting, init'd in
  `main.dart`).
- Lint: `flutter_lints` via `analysis_options.yaml`, no custom overrides.

## Commands

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1   # Android emulator (default)
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1  # web/desktop
flutter analyze
flutter test
```

Backend must be running first (`npm run start:dev` in `digital_settlement_be`). Android
cleartext HTTP is enabled in `android/app/src/main/AndroidManifest.xml` for local dev only
— don't remove that without switching `API_BASE_URL` to HTTPS.

## Folder structure (`lib/`)

```
services/   api_client.dart (HTTP client), auth_service.dart (session, ChangeNotifier)
models/     thin JSON wrappers — user.dart, expense_row.dart, expense_detail.dart,
            settlement_detail.dart, approval_pending_item.dart, bank_statement.dart,
            dashboard_data.dart, simple_option.dart
screens/    login_screen.dart, home_shell.dart (role-gated bottom-nav shell),
            dashboard/, expenses/, approvals/, statements/, profile_screen.dart
widgets/    error_view.dart, authed_image.dart, photo_tile.dart, status_badge.dart,
            expense_form_widgets.dart
utils/      format.dart, thousands_formatter.dart, invoice_ocr.dart
theme.dart  buildAppTheme() — app forces ThemeMode.dark
```

## Auth / role gating

`AppUser.hasAnyRole`/`hasAnyPermission` plus `positionCode` checks (`HEAD_POD`, `BOD`
special-cased in `home_shell.dart`) gate what's shown client-side. This is UX only — the
backend re-checks authorization on every request. Don't treat a hidden tab/button as a
security control when reasoning about access.

## Testing

Only `test/widget_test.dart` exists — a smoke test that `LoginScreen` renders with fresh
providers. There is no broader test suite to extend by convention; add tests as the user
requests them rather than assuming a missing test file is an oversight to fix silently.

## Platforms

Full multi-platform Flutter scaffold (`android/`, `ios/`, `linux/`, `macos/`, `web/`,
`windows/`) exists, but Android is the primary target per existing screens/comments —
don't assume desktop/web parity when making UI changes.

## Related repos

- `digital_settlement_be` — the NestJS API this app consumes.
- `digital_settlement_fe` — Next.js web admin, same backend, full feature set; this app's
  `ApiClient` is kept in sync with its `src/lib/api.ts`.
