#!/bin/bash
# Upload the release APK to s3://recompdaily-builds/ with a version+sha+date key.
#
# Usage:
#   ./scripts/upload_apk_to_s3.sh                  # upload existing build/...app-release.apk
#   ./scripts/upload_apk_to_s3.sh --build          # `flutter build apk --release` first (fat APK)
#   ./scripts/upload_apk_to_s3.sh --split          # `flutter build apk --release --split-per-abi`,
#                                                    upload all three APKs side by side
#
# Notes:
#   - The default credential chain on this Mac falls into a Lightsail role with no
#     S3 access — must pass --profile recompdaily, which is what this script does.
#   - `flutter run --release` leaves a per-device-ABI APK (~21 MB) which is fine
#     for adb install but breaks for random Android users. For public drops use
#     --build (fat APK ~58 MB) or --split.

set -eu

cd "$(dirname "$0")/.."

PROFILE="recompdaily"
BUCKET="recompdaily-builds"
APK_DIR="build/app/outputs/flutter-apk"
MODE="reuse"

while [ $# -gt 0 ]; do
    case "$1" in
        --build) MODE="fat"; shift ;;
        --split) MODE="split"; shift ;;
        --reuse) MODE="reuse"; shift ;;
        -h|--help)
            sed -n '2,17p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

case "$MODE" in
    fat)
        echo "==> flutter build apk --release (fat APK)"
        flutter build apk --release
        ;;
    split)
        echo "==> flutter build apk --release --split-per-abi"
        flutter build apk --release --split-per-abi
        ;;
    reuse)
        if [ ! -f "$APK_DIR/app-release.apk" ] && ! ls "$APK_DIR"/app-*-release.apk >/dev/null 2>&1; then
            echo "no APK in $APK_DIR — run with --build or --split first" >&2
            exit 1
        fi
        ;;
esac

VERSION=$(awk '/^version:/{print $2}' pubspec.yaml)
SHA=$(git rev-parse --short HEAD)
DATE=$(date +%Y%m%d)
PREFIX="recompdaily-android-${VERSION}-${SHA}-${DATE}"

upload_one() {
    local src="$1"
    local suffix="$2"
    local key="${PREFIX}${suffix:+-$suffix}.apk"
    echo "==> aws s3 cp $src s3://$BUCKET/$key"
    aws s3 cp "$src" "s3://$BUCKET/$key" --profile "$PROFILE"
    echo "    s3://$BUCKET/$key"
}

if ls "$APK_DIR"/app-*-release.apk >/dev/null 2>&1; then
    # split mode: app-arm64-v8a-release.apk, app-armeabi-v7a-release.apk, app-x86_64-release.apk
    for apk in "$APK_DIR"/app-*-release.apk; do
        abi=$(basename "$apk" | sed -E 's/^app-(.*)-release\.apk$/\1/')
        upload_one "$apk" "$abi"
    done
else
    upload_one "$APK_DIR/app-release.apk" ""
fi

echo
echo "==> bucket listing (last 5):"
aws s3 ls "s3://$BUCKET/" --profile "$PROFILE" | tail -5
