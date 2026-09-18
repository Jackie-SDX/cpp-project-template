#!/usr/bin/env bash
set -euo pipefail

target="$1"
abi="$2"
version="$3"
ndk_version="$4"
platform="$5"
output="$6"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
test -n "$sdk_root"
build_tools_dir="$sdk_root/build-tools"
build_tools="$(find "$build_tools_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -1)"
test -n "$build_tools"

aapt2="$build_tools_dir/$build_tools/aapt2"
d8="$build_tools_dir/$build_tools/d8"
zipalign="$build_tools_dir/$build_tools/zipalign"
apksigner="$build_tools_dir/$build_tools/apksigner"
android_jar="$sdk_root/platforms/android-28/android.jar"
for tool in "$aapt2" "$d8" "$zipalign" "$apksigner" "$android_jar"; do
  test -e "$tool"
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$root/packaging/android/AndroidManifest.xml"
activity="$root/packaging/android/MainActivity.java"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/src/com/naylacruz/cppprojecttemplate" "$work/classes" "$work/dex" "$work/assets/bin"
cp "$activity" "$work/src/com/naylacruz/cppprojecttemplate/MainActivity.java"
cp "$target" "$work/assets/bin/projectcli"
cat > "$work/assets/BUILD-INFO.txt" <<EOF
Project: cpp-project-template
Version: $version
Android ABI: $abi
NDK: $ndk_version
API: $platform
Payload: assets/bin/projectcli
EOF

javac -source 17 -target 17 -cp "$android_jar" -d "$work/classes"   "$work/src/com/naylacruz/cppprojecttemplate/MainActivity.java"

"$d8" --min-api 28 --lib "$android_jar" --output "$work/dex" \
  "$work/classes/com/naylacruz/cppprojecttemplate/MainActivity.class"

base_version="${version%%-*}"
IFS=. read -r major minor patch extra <<< "$base_version"
major="${major:-0}"
minor="${minor:-0}"
patch="${patch:-0}"
version_code="$((major * 1000000 + minor * 1000 + patch))"
test "$version_code" -gt 0

"$aapt2" link \
  --manifest "$manifest" \
  -I "$android_jar" \
  --min-sdk-version 28 \
  --target-sdk-version 28 \
  --version-code "$version_code" \
  --version-name "$version" \
  -A "$work/assets" \
  -o "$work/app-unaligned.apk"

(cd "$work/dex" && zip -q -0 "$work/app-unaligned.apk" classes.dex)
"$zipalign" -f 4 "$work/app-unaligned.apk" "$work/app-aligned.apk"

keystore="$work/release.keystore"
alias="${ANDROID_RELEASE_KEY_ALIAS:-}"
store_password="${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}"
key_password="${ANDROID_RELEASE_KEY_PASSWORD:-}"

if [ -n "${ANDROID_RELEASE_KEYSTORE_B64:-}" ]; then
  printf '%s' "$ANDROID_RELEASE_KEYSTORE_B64" | base64 --decode > "$keystore"
  test -s "$keystore"
  test -n "$alias"
  test -n "$store_password"
  test -n "$key_password"
else
  alias="androiddebugkey"
  store_password="android"
  key_password="android"
  keytool -genkeypair -noprompt     -keystore "$keystore"     -storepass "$store_password"     -keypass "$key_password"     -alias "$alias"     -keyalg RSA     -keysize 2048     -validity 10000     -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

mkdir -p "$(dirname "$output")"
"$apksigner" sign   --ks "$keystore"   --ks-key-alias "$alias"   --ks-pass "pass:$store_password"   --key-pass "pass:$key_password"   --v1-signing-enabled true   --v2-signing-enabled true   --v3-signing-enabled true   --v4-signing-enabled false   --out "$output"   "$work/app-aligned.apk"

"$apksigner" verify --verbose "$output"
unzip -l "$output" | grep -F "assets/bin/projectcli"
