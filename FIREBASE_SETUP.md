# Firebase setup for Number Slide Pro

1. Create or select a Firebase project at https://console.firebase.google.com/.
2. Add an Android app. Choose a stable unique application ID (e.g. com.bilvok.numberslidepro) and use the SAME ID in Android Gradle.
3. Download google-services.json and place it at android/app/google-services.json. Do not commit private credentials or service-account keys.
4. Install Firebase CLI and FlutterFire CLI; run `firebase login`, `dart pub global activate flutterfire_cli`, then `flutterfire configure --platforms=android`.
5. Add generated `lib/firebase_options.dart` and initialize Firebase using `DefaultFirebaseOptions.currentPlatform`. The existing `Firebase.initializeApp()` works only when native Android Firebase configuration is correctly generated.
6. Enable Firebase Authentication → Sign-in method → Anonymous.
7. Create a Firestore database, then deploy `firestore.rules` and `firestore.indexes.json` with Firebase CLI (`firebase deploy --only firestore`), using a firebase.json pointing to these files.
8. Test leaderboard reading and writing on an Android device. Queries filter by board size and sort descending by score.
9. For public launch, do NOT trust client-submitted scores. Implement server-validated submissions, App Check, abuse controls and moderation before allowing competitive rankings.

Note: This repository does not yet have access to your Firebase project. A GitHub commit does not create or deploy Firebase resources.
