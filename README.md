# VenueVault

VenueVault is a Flutter application for managing event equipment rentals, from inventory and booking to dispatch, returns, and inspection. It uses Firebase Authentication and Cloud Firestore, with a TypeScript Cloud Functions backend included in the repository.

## Implemented features

- **Staff authentication:** Email and password sign-in, password reset, and access based on Firebase Auth role claims.
- **Equipment catalog:** Search and filter equipment, view stock and equipment details, and manage catalog entries, stock, condition, maintenance notes, and retirement according to staff permissions.
- **Booking management:** Create, edit, view, and cancel bookings with customer details, event information, date ranges, and equipment quantities. The booking form checks availability against existing reservations.
- **Booking calendar:** Browse bookings by date and view event details for a selected day.
- **Conflict reporting:** View equipment shortages, overlapping reservations, and unavailable equipment windows in a read-only report.
- **Dispatch operations:** View dispatch jobs, assign staff, manage packing checklists, and update delivery progress according to role permissions.
- **Returns and inspections:** Record returned, damaged, and missing quantities, approve inspections, and track equipment that remains unavailable.
- **Operations dashboard:** Review upcoming events, usable stock, open dispatches, overdue returns, pending inspections, and conflicts. Authorized staff can also view audit records.

These features are implemented in the source. Deployment status and end-to-end production readiness are not established by this README.

## Technology stack

| Layer | Technology |
| --- | --- |
| Application | Flutter, Dart, Material 3 |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Backend | Cloud Functions for Firebase, TypeScript, Node.js 24 |
| Access control | Firebase Auth custom claims and Firestore Security Rules |
| Local development | Firebase Local Emulator Suite |
| Static hosting | Firebase Hosting configuration and starter page |

## Repository structure

```text
app/
  lib/                    Flutter screens, availability logic, and role permissions
  test/                   Authentication UI and role-permission tests
  android/, ios/, ...     Flutter platform projects
  pubspec.yaml            App dependencies and Dart SDK requirement
functions/
  src/                    Callable functions, Firestore triggers, and unit tests
  scripts/set-role.js     Emulator-only role assignment helper
  package.json            Backend dependencies and commands
public/                   Firebase Hosting starter page
firestore.rules           Firestore access rules and data validation
firestore.indexes.json    Firestore index definitions
firebase.json             Root Firebase service and emulator configuration
PRD.md                    Product requirements
```

The application project is under `app/`. Run Flutter commands there. Backend commands run separately under `functions/`.

## Architecture and current limitations

The Flutter app uses Firebase Authentication for sign-in and reads the user's `role` custom claim to control access to screens and actions. Firestore rules enforce database access separately from the interface.

The current client reads and writes operational records directly through the Firestore SDK, including transactions for some workflows. The backend also contains callable functions for booking, equipment, dispatch, returns, dashboard summaries, and role management. These callables are not currently wired into the Flutter client; `cloud_functions` is not listed as an app dependency.

The backend includes Firestore triggers to create and synchronize dispatch records for confirmed bookings. Dispatch records use the booking ID as their document ID. Automatic dispatch creation requires those triggers to be deployed or running locally.

Keep the following implementation limits in mind:

- Availability checks exist in the client, but the app does not currently use the server-side booking callable that serializes availability checks. Client checks alone do not guarantee prevention of simultaneous conflicting reservations.
- Conflict reporting is read-only; the app does not expose dedicated conflict-resolution actions.
- Role management is available through an Admin-only callable, with no role-management screen in the app.
- The root `firebase.json` configures Firestore, Hosting, and Auth/Firestore/Hosting emulators. It does not currently declare a Functions source or Functions emulator configuration, so Functions setup is required before deployment or local trigger testing.
- Hosting currently serves `public/index.html`, a Firebase starter page. It does not serve a built Flutter web app.
- Firebase options are included for web, Android, iOS, macOS, and Windows. Linux Firebase options are not configured.

## Staff roles

| Role claim | Main responsibilities |
| --- | --- |
| `admin` | All defined application permissions, including catalog and user-role management |
| `booking_staff` | View inventory and bookings; create, edit, and cancel bookings |
| `warehouse_staff` | View inventory and bookings; update stock, manage checklists, record returns, and track equipment issues |
| `dispatch_staff` | View assigned dispatches and update their status |
| `operations_manager` | Manage bookings, assign dispatches, approve returns, and review dashboard, conflicts, and audit records |

Permission definitions are in `app/lib/role_permissions.dart` and `functions/src/roles.ts`; database access is enforced in `firestore.rules`. A missing or unrecognized role receives no application permissions.

### Assigning roles

1. Create the staff account in Firebase Authentication and copy its UID. The app provides sign-in rather than public account registration.
2. Bootstrap the first Admin from a trusted Firebase Admin SDK environment by setting the custom claim to `{ "role": "admin" }`.
3. Use the Admin-authorized `setUserRole` callable for subsequent assignments. It accepts a target UID and one of the role claims listed above. The callable must be deployed or otherwise made available before use.
4. Have the affected user sign out and back in to refresh their Auth token.

The Firebase Console manages accounts but does not directly edit custom role claims. Keep Admin SDK credentials outside the Flutter client and repository.

## Local setup

### Prerequisites

- A Flutter SDK with Dart compatible with `^3.13.5`, as declared in `app/pubspec.yaml`.
- Node.js 24 and npm, matching `functions/package.json`.
- Firebase CLI for emulator and Firebase service commands.
- Java for the Firestore emulator.
- FlutterFire CLI if you need to regenerate Firebase configuration.
- Platform tooling for the device or desktop target you intend to run.

### Run the application

From the repository root:

```powershell
cd app
flutter pub get
flutter run
```

Firebase options are already included in `app/lib/firebase_options.dart`. The default Firebase project in `.firebaserc` is `venue-vault-kalvium-community`. Running without the emulator flag connects to the configured Firebase services and requires a provisioned staff account and appropriate role.

If you are connecting your own project, regenerate the app configuration from `app/`:

```powershell
flutterfire configure --project=<your-project-id>
```

Also update the root Firebase project selection for CLI commands.

### Build the backend

In a terminal at the repository root:

```powershell
cd functions
npm ci
npm run lint
npm run build
```

This compiles the TypeScript source to `functions/lib/`. Building does not deploy the functions or connect them to the Flutter app.

### Run the configured emulators

From the repository root:

```powershell
firebase emulators:start
```

| Service | Local address |
| --- | --- |
| Authentication | `127.0.0.1:9099` |
| Firestore | `127.0.0.1:8080` |
| Hosting | `http://127.0.0.1:5000` |
| Emulator UI | Usually `http://127.0.0.1:4000`; check the CLI output |

In another terminal, run the application from `app/`:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

The flag connects Auth and Firestore to the hardcoded host `127.0.0.1` in `app/lib/main.dart`. For an Android emulator or physical device, adjust the host or configure port forwarding so the device can reach the development machine.

Create a local user in the Auth emulator before assigning a role. After building the backend, run this helper from `functions/`:

```powershell
$env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099"
node scripts/set-role.js staff@example.com admin
```

The helper only works with the Auth emulator and refuses to run without `FIREBASE_AUTH_EMULATOR_HOST`. Sign in again after assigning the role. The Functions emulator is not included in the current root configuration, so this setup does not run backend triggers or callables.

## Validation

Run the application checks from `app/`:

```powershell
flutter analyze
flutter test
```

Run the backend checks from `functions/`:

```powershell
npm run lint
npm test
```

`npm test` builds the backend before running its Node.js unit tests. Existing tests cover backend role permissions, role-change safeguards, booking availability, and dashboard calculations, plus Flutter authentication UI and role permissions. These checks do not establish complete end-to-end coverage of operational workflows or Firestore rules.

## Contributing

1. Create a focused branch from the default branch.
2. Make the change and update relevant documentation.
3. Run the checks appropriate to the affected app or backend code.
4. Open a pull request with a clear summary, validation results, and screenshots for interface changes.

Keep credentials, local logs, dependency directories, and generated build output out of commits. Keep the Flutter client in `app/` and trusted backend code in `functions/`.
