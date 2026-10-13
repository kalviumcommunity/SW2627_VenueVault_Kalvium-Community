# VenueVault

VenueVault is a Flutter mobile application backed by Firebase for event
equipment booking, inventory, dispatch, and return tracking.

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

Install Flutter and the FlutterFire CLI first. Run Flutter commands from the
`app` directory:

```powershell
cd app
flutter pub get
flutterfire configure --project=venue-vault-kalvium-community
```

`flutterfire configure` registers the mobile apps and generates
`app/lib/firebase_options.dart` plus the platform Firebase configuration
files. The generated platform projects are already included under `app/`.

Install and build the backend separately:

```powershell
cd ..
cd functions
npm ci
npm run lint
npm run build
```

Run the mobile app with:

```powershell
cd app
flutter run
```

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