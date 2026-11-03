#!/usr/bin/env bash
set -euo pipefail
umask 077
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
dest=play-package/android
mkdir -p "$dest"
# The initial Play release uses the package and version from pubspec/Gradle.
args=(--release)
if [[ -n "${ADMOB_ANDROID_APP_ID:-}${ADMOB_ANDROID_BANNER_UNIT_ID:-}${ADMOB_ANDROID_REWARDED_UNIT_ID:-}" ]]; then
  if ! [[ "$ADMOB_ANDROID_APP_ID" =~ ^(ca-app-pub-[0-9]{16})~[0-9]{10}$ ]]; then
    echo "Invalid AdMob app ID" >&2; exit 1
  fi
  publisher=${BASH_REMATCH[1]}
  [[ "$publisher" != ca-app-pub-3940256099942544 && "$ADMOB_ANDROID_BANNER_UNIT_ID" != "$ADMOB_ANDROID_REWARDED_UNIT_ID" ]]
  for unit in "$ADMOB_ANDROID_BANNER_UNIT_ID" "$ADMOB_ANDROID_REWARDED_UNIT_ID"; do
    [[ "$unit" =~ ^${publisher}/[0-9]{10}$ ]] || { echo "Invalid publisher unit ID" >&2; exit 1; }
  done
  args+=("--dart-define=ADMOB_ANDROID_BANNER_UNIT_ID=$ADMOB_ANDROID_BANNER_UNIT_ID"
         "--dart-define=ADMOB_ANDROID_REWARDED_UNIT_ID=$ADMOB_ANDROID_REWARDED_UNIT_ID")
else
  echo "Release has no configured AdMob placements."
fi
flutter build appbundle "${args[@]}"
bundle="$dest/NumberSlidePro-unsigned.aab"
cp build/app/outputs/bundle/release/app-release.aab "$bundle"
if unzip -Z1 "$bundle" | grep -Ei '^META-INF/[^/]+\.(SF|RSA|EC|DSA)$' >/dev/null; then
  echo "Unexpected pre-existing signature; refusing to label this bundle." >&2
  exit 1
fi
curl --proto '=https' --retry 3 -fsSL -o "$tmp/bundletool.jar" https://github.com/google/bundletool/releases/download/1.18.1/bundletool-all-1.18.1.jar
java -jar "$tmp/bundletool.jar" validate --bundle="$bundle"
java -jar "$tmp/bundletool.jar" dump manifest --bundle="$bundle" > "$tmp/manifest.xml"
python3 - "$tmp/manifest.xml" "$bundle" <<'PY'
import struct, sys, zipfile
import xml.etree.ElementTree as ET
a = '{http://schemas.android.com/apk/res/android}'
m = ET.parse(sys.argv[1]).getroot()
assert m.get('package') == 'com.bilvok.numberslidepro'
assert int(m.find('uses-sdk').get(a+'targetSdkVersion')) >= 36
assert m.find('application').get(a+'debuggable', 'false') != 'true'
print('Package:', m.get('package'), 'version code:', m.get(a+'versionCode'), 'target SDK:', m.find('uses-sdk').get(a+'targetSdkVersion'))
with zipfile.ZipFile(sys.argv[2]) as z:
    libs = [n for n in z.namelist() if n.endswith('.so') and ('/arm64-v8a/' in n or '/x86_64/' in n)]
    assert libs, 'No 64-bit native libraries'
    for n in libs:
        data = z.read(n)
        assert data[:6] == b'\x7fELF\x02\x01', n
        offset = struct.unpack_from('<Q', data, 32)[0]
        step, count = struct.unpack_from('<HH', data, 54)
        for i in range(count):
            p = offset + i * step
            if struct.unpack_from('<I', data, p)[0] == 1:
                assert struct.unpack_from('<Q', data, p + 48)[0] >= 16384, ('ELF alignment', n)
    print('Validated 16 KB LOAD alignment for', len(libs), '64-bit native libraries.')
PY
keystore="$tmp/signer.jks"
if [[ -n "${PLAY_UPLOAD_KEYSTORE_BASE64:-}${PLAY_UPLOAD_KEY_ALIAS:-}${PLAY_UPLOAD_STORE_PASSWORD:-}${PLAY_UPLOAD_KEY_PASSWORD:-}" ]]; then
  : "${PLAY_UPLOAD_KEYSTORE_BASE64:?Upload keystore is missing}"
  : "${PLAY_UPLOAD_KEY_ALIAS:?Upload alias is missing}"
  : "${PLAY_UPLOAD_STORE_PASSWORD:?Upload store password is missing}"
  : "${PLAY_UPLOAD_KEY_PASSWORD:?Upload key password is missing}"
  printf '%s' "$PLAY_UPLOAD_KEYSTORE_BASE64" | base64 -d > "$keystore"
  alias_name="$PLAY_UPLOAD_KEY_ALIAS"
  [[ "${alias_name,,}" != androiddebugkey ]]
  keytool -exportcert -keystore "$keystore" -storepass:env PLAY_UPLOAD_STORE_PASSWORD -alias "$alias_name" -file "$tmp/upload.der"
  if openssl x509 -inform DER -in "$tmp/upload.der" -noout -subject | grep -qi 'Android Debug'; then
    echo "A Google Play upload key is required." >&2; exit 1
  fi
  signed="$dest/NumberSlidePro-upload-signed.aab"
  jarsigner -keystore "$keystore" -storepass:env PLAY_UPLOAD_STORE_PASSWORD -keypass:env PLAY_UPLOAD_KEY_PASSWORD \
    -digestalg SHA-256 -signedjar "$signed" "$bundle" "$alias_name"
  jarsigner -verify "$signed"
  rm "$bundle"
  bundle="$signed"
  apk="$dest/NumberSlidePro-upload-signed-release.apk"
  echo "Upload-signed bundle and APK." > "$dest/SIGNING.txt"
else
  # For installing the release-mode APK locally only. The Play bundle stays unsigned.
  alias_name=preview
  export PLAY_UPLOAD_STORE_PASSWORD="$(openssl rand -hex 24)"
  export PLAY_UPLOAD_KEY_PASSWORD="$PLAY_UPLOAD_STORE_PASSWORD"
  keytool -genkeypair -keystore "$keystore" -storepass:env PLAY_UPLOAD_STORE_PASSWORD -keypass:env PLAY_UPLOAD_KEY_PASSWORD \
    -alias "$alias_name" -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=Number Slide Pro local preview'
  apk="$dest/NumberSlidePro-preview-release.apk"
  printf '%s\n' 'The release-mode APK uses a temporary preview certificate for sideloading.' \
    'The AAB is unsigned. Sign it with your private upload key before sending it to Play Console.' > "$dest/SIGNING.txt"
fi
printf '%s' "$PLAY_UPLOAD_STORE_PASSWORD" > "$tmp/store.pass"
printf '%s' "$PLAY_UPLOAD_KEY_PASSWORD" > "$tmp/key.pass"
java -jar "$tmp/bundletool.jar" build-apks --mode=universal --bundle="$bundle" --output="$tmp/app.apks" \
  --ks="$keystore" --ks-key-alias="$alias_name" --ks-pass="file:$tmp/store.pass" --key-pass="file:$tmp/key.pass"
unzip -p "$tmp/app.apks" universal.apk > "$apk"
buildtools=$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
"$buildtools/apksigner" verify "$apk"
"$buildtools/zipalign" -c -P 16 -v 4 "$apk" > "$tmp/alignment.txt"
(cd "$dest" && sha256sum *.apk *.aab > SHA256SUMS)
