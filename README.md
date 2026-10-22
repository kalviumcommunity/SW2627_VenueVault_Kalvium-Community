# VenueVault

VenueVault is a Flutter mobile application backed by Firebase for event
equipment booking, inventory, dispatch, and return tracking.

## Key Features

- **Equipment Inventory Tracking**: Monitor real-time availability, stock counts, and categories (audio, lighting, staging, power, cables).
- **Booking & Conflict Prevention**: Validate overlapping date ranges and equipment reservations before confirmation to prevent double-booking.
- **Dispatch Management**: View daily dispatches, manage packing checklists, and update item status from warehouse to venue delivery.
- **Return & Inspection Tracking**: Track returned gear, record damages or missing accessories, and restore inventory back to available stock.
- **Secure Multi-Role Access**: Backed by Firebase Authentication and Firestore security rules to protect operational and client data.

## Tech Stack

- **Frontend**: Flutter (Dart), Material 3 design
- **Backend**: Firebase Cloud Functions (TypeScript / Node.js 24)
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth
- **Hosting & Emulators**: Firebase Hosting and Firebase Local Emulator Suite

## Repository structure

```text
.
├── app/                    # Flutter application project
│   ├── lib/                # Application code and Firebase configuration
│   ├── android/            # Android platform project
│   ├── ios/                # iOS platform project
│   └── pubspec.yaml        # Flutter dependencies
├── functions/              # Firebase Cloud Functions (TypeScript)
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Firestore indexes
├── firebase.json           # Firebase services and emulators
└── public/                 # Firebase Hosting files
```

The Flutter app and Firebase Functions are intentionally kept in one
repository. The app is the client; `functions/` contains trusted server-side
operations and must not be moved into `app/lib/`.

## Local setup

### Prerequisites

Ensure you have the following installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- [Node.js](https://nodejs.org/) (v20+) & npm
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) (`dart pub global activate flutterfire_cli`)

### Mobile App Setup

From the repository root run:

```powershell
cd app
flutter pub get
flutterfire configure --project=venue-vault-kalvium-community
```

`flutterfire configure` registers the mobile apps and generates
`app/lib/firebase_options.dart` plus the platform Firebase configuration
files. The generated platform projects are already included under `app/`.

Run the mobile app with:

```powershell
flutter run
```

### Backend Setup (Cloud Functions)

Install and build the backend separately:

```powershell
cd ..
cd functions
npm ci
npm run lint
npm run build
```

### Running with Firebase Local Emulators

For offline testing and local backend development, you can run the Firebase Emulator Suite:

```powershell
firebase emulators:start
```

This starts local emulators for:
- **Authentication**: `localhost:9099`
- **Cloud Functions**: `localhost:5001`
- **Cloud Firestore**: `localhost:8080`
- **Hosting**: `localhost:5000`
- **Emulator Suite UI**: `http://localhost:4000`

The Firebase project is already selected in `.firebaserc`. Do not commit
secrets, local Firebase credentials, or generated build output.

## Contributing

To contribute to VenueVault:

1. Create a focused branch from the default branch.
2. Make the smallest change that addresses the issue or feature.
3. Run the relevant Flutter checks and backend checks before opening a PR:

   ```powershell
   cd app
   flutter analyze
   flutter test
   cd ..
   cd functions
   npm run lint
   npm run build
   ```

4. Open a pull request with a clear summary, testing details, and screenshots
   for UI changes.

Keep pull requests focused and avoid committing generated files, build
artifacts, Firebase credentials, or unrelated formatting changes.
thank you
thanks 

venuevault

spirit 2
hiii

helloo
