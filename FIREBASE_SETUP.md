# Number Slide Pro on Firebase

## Android and Firebase

Register the Android app as `com.bilvok.numberslidepro`. Download its Android client configuration from the Firebase project settings. Put the file at `android/app/google-services.json` for local builds. In GitHub Actions, the repository secret `FIREBASE_ANDROID_CONFIG` accepts the complete JSON file. Use the Android client file for this setting.

The checked-in Gradle configuration runs the Google Services plugin. FlutterFire initializes the default app from the generated Android resources, then reuses the current player or signs in anonymously.

## Backend

Enable Anonymous under Firebase Authentication sign-in methods. Create the default Cloud Firestore Standard database in production mode. From this directory deploy to the dedicated game project:

```sh
firebase deploy --project YOUR_GAME_PROJECT_ID --only firestore
```

The query filters by `size`, orders by descending `score`, and requests up to 50 records. Wait for the composite index to become ready. Rules permit authenticated leaderboard reads and increasing scores on the player's own document, using the server timestamp and a board-specific score range. The game calculates scores on the client.

## Verification

```sh
firebase emulators:exec --project demo-number-slide-pro --only auth,firestore "node --test test/leaderboard-emulators.mjs"
```

GitHub Actions runs that test, validates the Firebase Android client against the Gradle application ID, runs Flutter analysis and the widget test, and builds a debug APK. An `online-debug-apk` artifact uses the supplied Firebase configuration. An `emulator-debug-apk` artifact connects to the Android emulator's host at `10.0.2.2` with authentication on 9099 and Firestore on 8080.

For a device check, install the online debug APK, solve a board, and tap the bar-chart icon. Verify that the score appears under the correct board size and persists when the app reopens.
