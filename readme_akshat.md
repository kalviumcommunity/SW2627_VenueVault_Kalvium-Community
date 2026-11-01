# VenueVault handoff — Akshat

Date: 31 October 2026

## Current issue

The Flutter app starts and users can sign in, but the home page shows:

```text
Could not load the operations dashboard.
[firebase_functions/internal] internal [0]
```

The dashboard calls the `getOperationsDashboard` callable Cloud Function. The current app connects to the live Firebase project `venue-vault-kalvium-community`; it is not configured to use local emulators.

A Cloud Shell check using `gcloud functions list` returned `[]`. Deployment was then attempted from the local repository. Lint and TypeScript build passed, but deployment stopped because enabling Cloud Build requires the Blaze billing plan. The project remains on Spark, and billing is not an option for this work.

The missing deployed backend explains why changing user roles alone did not restore the dashboard. Once a local backend is connected, runtime errors still need to be checked through its logs.

## Completed work and checks

- Confirmed that the Flutter Firebase configuration points to `venue-vault-kalvium-community`.
- Confirmed that the dashboard callable is exported from `functions/src/index.ts`.
- Reviewed the role maps in `functions/src/roles.ts`, `app/lib/role_permissions.dart`, and `firestore.rules`.
- Created the first live Auth admin custom claim using Firebase Admin SDK in Google Cloud Shell. Output verified `admin@venuevault.test` has `role: admin`.
- Prepared a fixed assignment script for the remaining users. Its successful execution has not been confirmed; verify actual claims before reporting those assignments as complete.
- Resolved the deployment lint blocker by applying ESLint fixes for CRLF/LF line endings. The latest deployment attempt passed both lint and build.
- TypeScript no-emit checking passed during inspection. Thirteen existing compiled dashboard/role tests also passed; these do not prove live deployment works.
- Live function deployment is NOT complete.

## Intended fixed role assignments

The abbreviated addresses below came from the Firebase Console screenshot. Resolve their full email addresses before recreating users.

| Account | Intended role |
| --- | --- |
| test@gmail.com | admin |
| test2@gmail.com | admin |
| admin@venuevault.test | admin |
| workemail@gmail.com | dispatch_staff |
| operations@… | booking_staff |
| dispatch2@… | operations_manager |
| dispatch@… | warehouse_staff |
| warehouse@… | dispatch_staff |
| booking@… | booking_staff |

Roles come from Firebase Auth custom claims (`role`), not just a Firestore profile field. Users must sign out and back in, or refresh their ID token, after a claim changes.

## Role access

| Role | Defined permissions |
| --- | --- |
| admin | All defined application permissions, including role assignment |
| booking_staff | Inventory and booking reads; create/edit/cancel bookings; limited reports |
| warehouse_staff | Inventory/bookings/all dispatch reads; checklists, stock, maintenance, recording returns and issues |
| dispatch_staff | Assigned dispatches only; dispatch status updates; issue reporting |
| operations_manager | Inventory/bookings/all dispatch reads; conflict resolution, approvals, dispatch assignment, return approval, dashboard, full reports and audit reads |

Only admin and operations_manager have `dashboard.view`. Only admins can assign roles through `setUserRole`.

## Next work: free local emulator mode

This implementation is still pending. No emulator switch has been added to Flutter yet.

1. Add an opt-in `USE_FIREBASE_EMULATORS` compile-time flag in `app/lib/main.dart`. Preserve the normal live configuration when the flag is false.
2. Immediately after Firebase initialization, and before any Auth listeners or service calls, connect Auth, Firestore, and Functions to the local emulators when the flag is true.
3. Use the ports already declared in `firebase.json`: Auth 9099, Firestore 8080, Functions 5001. For Chrome running on the same Windows computer, use `127.0.0.1`. Android emulator and physical-device networking require appropriate host configuration.
4. Start Auth, Firestore, and Functions together so local functions do not accidentally use live services. Confirm the Java requirement for the installed Firestore emulator version.
5. Create local Auth users, set their fixed custom role claims, and seed local Firestore with consistent test data. Live Auth users, claims, and Firestore data are not copied automatically. Review `docs/testing/fake-data.json` as a starting point and replace placeholder UIDs with actual local user UIDs.
6. Review `functions/scripts/set-role.js`. It deliberately refuses to run without `FIREBASE_AUTH_EMULATOR_HOST`; keep that protection. Build functions first because it imports compiled `lib/roles`. This helper only sets Auth claims; seed Firestore profiles separately if needed.
7. Configure emulator export/import so test users, claims, and data survive restarts. Keep local exported user/data files out of Git if they contain personal information or credentials.
8. Test each role, dashboard loading for admin/operations_manager, denied actions for other roles, and assigned-only dispatch access. Check emulator logs for any remaining runtime errors.
9. Add an admin-only Manage Users screen calling the existing `setUserRole` callable. No such screen currently exists. Keep backend authorization in place; never allow users to promote themselves.

## Commands after emulator wiring is implemented

From the repository root, build functions and start the emulators:

```powershell
npm --prefix functions run build
npx -y firebase-tools@latest emulators:start --only auth,firestore,functions --project venue-vault-kalvium-community
```

In a second terminal:

```powershell
cd app
flutter pub get
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

The Flutter flag above will only take effect after the code change described above. Keep both terminals running during testing.

## Limits and handoff notes

- Firebase emulators provide local development without a Blaze upgrade. They do not publish a public backend.
- Running Flutter alone does not deploy or start Cloud Functions.
- Do not keep retrying cloud deployment while the project is on Spark; the billing requirement remains.
- Never commit service-account private keys, login tokens, or test-user passwords.
- Review the ESLint formatting changes before committing; they may affect many function files.
- This handoff does not claim that the dashboard is fixed or that all planned role assignments were applied.
