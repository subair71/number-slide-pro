# Number Slide Pro

Flutter sliding puzzle with 3×3, 4×4 and 5×5 boards, coins, a daily challenge and rewarded ads. The leaderboard shows up to 50 players for the selected size. Each anonymous player keeps their best score per size.

## Run on Android

1. Install Flutter 3.29.3 and the Android SDK.
2. Run `flutter create --platforms android --org com.bilvok --project-name number_slide_pro .` to generate the remaining platform files.
3. Put the Firebase Android client configuration for `com.bilvok.numberslidepro` at `android/app/google-services.json`.
4. Run `flutter run`.

See [Firebase setup](FIREBASE_SETUP.md) for backend deployment, tests and Android build artifacts. Debug builds use Google's sample AdMob application, rewarded ad, and adaptive banner. The Android banner sits below the game controls and appears only after an ad loads.

For a release with live banners, set your AdMob app ID and pass your banner ad unit ID at build time:

```sh
ADMOB_ANDROID_APP_ID='ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY' \
  flutter build appbundle --dart-define=ADMOB_ANDROID_BANNER_UNIT_ID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
```

Release builds omit the banner if no banner unit ID is supplied.
