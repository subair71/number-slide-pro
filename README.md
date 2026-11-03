# Number Slide Pro

Flutter sliding puzzle with 3×3, 4×4 and 5×5 boards, coins, a daily challenge and rewarded ads. The leaderboard shows up to 50 players for the selected size. Each anonymous player keeps their best score per size.

## Run on Android

1. Install Flutter 3.29.3 and the Android SDK.
2. Run `flutter create --platforms android --org com.bilvok --project-name number_slide_pro .` to generate the remaining platform files.
3. Put the Firebase Android client configuration for `com.bilvok.numberslidepro` at `android/app/google-services.json`.
4. Run `flutter run`.

See [Firebase setup](FIREBASE_SETUP.md) for backend deployment, tests and Android build artifacts. Debug builds use Google's sample AdMob application, rewarded ad, and adaptive banner. The Android banner sits below the game controls and appears only after an ad loads.

## Connect the Android game to your AdMob account

In AdMob, choose the Android app for `com.bilvok.numberslidepro`. Copy its app ID and the two unit IDs for its banner and rewarded placements. Add these [GitHub Actions repository variables](https://github.com/subair71/number-slide-pro/settings/variables/actions):

| Variable | Value |
| --- | --- |
| `ADMOB_ANDROID_APP_ID` | Android app ID containing `~` |
| `ADMOB_ANDROID_BANNER_UNIT_ID` | Banner ad unit ID containing `/` |
| `ADMOB_ANDROID_REWARDED_UNIT_ID` | Rewarded ad unit ID containing `/` |

Run **Android APK build** on `main`. When all three IDs pass validation, the workflow builds a separate `publisher-release-apk` artifact for installation. The current Android Gradle configuration signs this APK with the debug key. The artifact name identifies whether its leaderboard uses Firebase emulators or the online project.

For a local build, export those same three variables, then run:

```sh
flutter build apk --release \
  --dart-define=ADMOB_ANDROID_BANNER_UNIT_ID="$ADMOB_ANDROID_BANNER_UNIT_ID" \
  --dart-define=ADMOB_ANDROID_REWARDED_UNIT_ID="$ADMOB_ANDROID_REWARDED_UNIT_ID"
```

Debug builds use Google's test ad units. In release builds, each placement is disabled when its unit ID is omitted.
