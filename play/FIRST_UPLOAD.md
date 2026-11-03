# First Google Play release

Package: `com.bilvok.numberslidepro`. Listing language: English (United States). Category: Games / Puzzle.

The [release package workflow](https://github.com/subair71/number-slide-pro/actions/workflows/play-store.yml) builds the AAB and an installable universal APK from the same release code. It separately captures phone screenshots from that APK and packages the listing text, 512×512 icon, 1024×500 feature graphic, and privacy policy. The workflow does not roll out an app automatically.

## Signing

Use your existing upload keystore if you already have one. For a first upload with no upload key, create one locally and keep a private backup:

```sh
keytool -genkeypair -v -keystore numberslide-upload.jks -storetype JKS -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

To sign the packaged unsigned bundle locally, unzip the Android release artifact and run:

```sh
jarsigner -keystore numberslide-upload.jks -digestalg SHA-256 -signedjar NumberSlidePro-upload-signed.aab NumberSlidePro-unsigned.aab upload
jarsigner -verify -verbose -certs NumberSlidePro-upload-signed.aab
```

Alternatively configure the following **repository secrets** and rerun the release workflow on main:

- `PLAY_UPLOAD_KEYSTORE_BASE64` — base64 representation of the keystore file.
- `PLAY_UPLOAD_KEY_ALIAS` — keystore alias.
- `PLAY_UPLOAD_STORE_PASSWORD` and `PLAY_UPLOAD_KEY_PASSWORD` — store and key passwords.

When all four are set, the Android artifact contains an upload-signed AAB and APK. Without them, it contains an unsigned AAB for local signing and a release-mode APK signed with a disposable preview certificate for device installation. Never register that preview certificate as a Play upload key. Keep credentials out of Git, chat and artifacts.

## In Play Console

1. Create **Number Slide Pro** in the developer account. Use Game → Puzzle. Confirm distribution, pricing and the first release track in your account.
2. Under Main store listing, use the title and descriptions, icon, feature graphic and phone screenshots from the listing artifact. Supply a monitored support email.
3. Under App content, provide this public policy URL:
   https://raw.githubusercontent.com/subair71/number-slide-pro/main/assets/privacy_policy.txt
   The policy is also available inside the game under **Quests → Privacy & data**.
4. Complete the target audience, content rating, ads and Data safety declarations for the actual build. The game uses anonymous Firebase authentication and sends scores and installation-linked identifiers to Firestore. The Mobile Ads SDK is included. Check whether publisher ad units are enabled for this binary and review the SDK disclosures. Review the developer identity, business contact and the retention and deletion practices in the policy before submission.
5. Upload the **upload-signed AAB** to the required release track, paste the release notes, resolve the Console's checks and submit for review. New personal accounts may need closed testing before production access. Google decides when the listing can go live.
