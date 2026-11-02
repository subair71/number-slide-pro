# Number Slide Pro

Flutter sliding puzzle with 3×3, 4×4 and 5×5 boards, coins, a daily challenge and rewarded ads. The leaderboard shows up to 50 players for the selected size. Each anonymous player keeps their best score per size.

## Run on Android

1. Install Flutter 3.29.3 and the Android SDK.
2. Run `flutter create --platforms android --org com.bilvok --project-name number_slide_pro .` to generate the remaining platform files.
3. Put the Firebase Android client configuration for `com.bilvok.numberslidepro` at `android/app/google-services.json`.
4. Run `flutter run`.

See [Firebase setup](FIREBASE_SETUP.md) for backend deployment, tests and Android build artifacts. Debug builds use Google's sample AdMob application and rewarded ad unit.
