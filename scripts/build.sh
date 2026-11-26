#!/bin/zsh
# Debug-build Topsail from the Xcode project, ad-hoc signed.
#
#   scripts/build.sh            App Store flavour (sandboxed)      -> build/Topsail.app
#   scripts/build.sh --direct   direct-download flavour (DIRECT)   -> build/Direct/Topsail.app
#   add --install               also quit Topsail, copy the build to /Applications/Topsail.app, open it
#   add --optimized             the continuity suite's flavour: Release settings (so frame times
#                               mean something) with the debug-only test mode compiled in
#                               -> build/Continuity/Topsail.app. Never shipped, never installed.
#
# The App Store flavour uses the same project, entitlements and Info.plist as the App Store
# build, so sandbox problems show up during development. The direct flavour adds the DIRECT
# compilation condition (brightness via DisplayServices), drops the sandbox, embeds the Low Power
# Mode helper (scripts/embed-helper.sh), and uses its own bundle id so its permissions and
# settings never mix with the App Store build's.
# Compiler errors are also written to build/logs/errors.log.
set -uo pipefail

ROOT=${0:A:h:h}
LOGS=$ROOT/build/logs
mkdir -p $LOGS

DIRECT=0
INSTALL=0
OPTIMIZED=0
for arg in "$@"; do
  case $arg in
    --direct) DIRECT=1 ;;
    --install) INSTALL=1 ;;
    --optimized) OPTIMIZED=1 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done

FLAVOUR_SETTINGS=()
CONFIGURATION=Debug
CONDITIONS=
if (( DIRECT )); then
  DERIVED=$ROOT/build/DerivedDataDirect
  APP=$ROOT/build/Direct/Topsail.app
  CONDITIONS=DIRECT
  FLAVOUR_SETTINGS=(
    CODE_SIGN_ENTITLEMENTS=Topsail/Resources/Topsail-Direct.entitlements
    PRODUCT_BUNDLE_IDENTIFIER=app.topsail.Topsail.direct
    # Only the direct build reads Bluetooth (headphones' battery), so only it asks. Generated keys
    # are merged into Info.plist.
    GENERATE_INFOPLIST_FILE=YES
    'INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription=Topsail shows your headphones’ battery when they connect.'
  )
else
  DERIVED=$ROOT/build/DerivedData
  APP=$ROOT/build/Topsail.app
fi
if (( OPTIMIZED )); then
  if (( INSTALL )); then echo "--optimized builds are for the continuity suite and are not installed."; exit 2; fi
  CONFIGURATION=Release
  DERIVED=$ROOT/build/DerivedDataContinuity
  APP=$ROOT/build/Continuity/Topsail.app
  CONDITIONS="$CONDITIONS DEBUG CONTINUITY_OPTIMIZED"
fi
if [[ -n $CONDITIONS ]]; then
  FLAVOUR_SETTINGS+=("SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) $CONDITIONS")
fi

xcodebuild -project $ROOT/Topsail.xcodeproj -scheme Topsail -configuration $CONFIGURATION \
  -derivedDataPath $DERIVED \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  ENABLE_DEBUG_DYLIB=NO \
  "${FLAVOUR_SETTINGS[@]}" \
  build 2>&1 | tee $LOGS/build.log | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | sort -u
build_status=${pipestatus[1]}

grep -E -A4 "error:" $LOGS/build.log | grep -v "^--$" > $LOGS/errors.log
if (( build_status != 0 )); then
  echo "\nBUILD FAILED: $(grep -c 'error:' $LOGS/build.log) error lines (see build/logs/errors.log)"
  exit $build_status
fi

rm -rf $APP
mkdir -p ${APP:h}
cp -R $DERIVED/Build/Products/$CONFIGURATION/Topsail.app $APP

# With an Apple Development certificate (signed in to Xcode), every dev build has the same
# identity, so macOS privacy permissions (Input Monitoring, Accessibility) and keychain access
# survive rebuilds. Without one it's ad hoc, and macOS asks again after each rebuild: a stable
# ad-hoc identity would be one any other ad-hoc binary could claim, permissions and all.
# Release builds are signed by release.sh / release-direct.sh.
ENTITLEMENTS=$(mktemp "${TMPDIR:-/tmp}/topsail-entitlements.XXXXXX")
codesign -d --entitlements - --xml $APP > $ENTITLEMENTS 2>/dev/null
DEV_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/"Apple Development: / {print $2; exit}')

# The direct flavour carries its Low Power Mode helper, signed like the app and before it.
if (( DIRECT )); then
  if ! $ROOT/scripts/embed-helper.sh $APP ${DEV_IDENTITY:--}; then
    echo "\nBUILD FAILED: could not build the Low Power Mode helper"
    exit 1
  fi
fi

if [[ -n $DEV_IDENTITY ]]; then
  codesign --force --sign "$DEV_IDENTITY" --options runtime --timestamp=none \
    --entitlements $ENTITLEMENTS $APP \
    || echo "warning: could not sign with $DEV_IDENTITY"
else
  codesign --force --sign - --options runtime --entitlements $ENTITLEMENTS $APP \
    || echo "warning: could not re-sign the app"
fi
rm -f $ENTITLEMENTS
echo "\nBUILD OK -> ${APP#$ROOT/}"

if (( INSTALL )); then
  DEST=/Applications/Topsail.app
  # Only ever replace a previous Topsail, never another app that happens to share the name.
  if [[ -e $DEST ]]; then
    EXISTING_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" $DEST/Contents/Info.plist 2>/dev/null)
    if [[ $EXISTING_ID != app.topsail.Topsail* ]]; then
      echo "Refusing to replace $DEST: it is '$EXISTING_ID', not Topsail."
      exit 1
    fi
  fi
  # Quit the installed copy, and any test build running from build/ (either flavour): two Topsails
  # draw two islands over the notch, one on top of the other.
  pkill -f "^$DEST/Contents/MacOS/Topsail" && sleep 1
  pkill -f "^$ROOT/build/(Direct/)?Topsail.app/Contents/MacOS/Topsail" && sleep 1
  rm -rf $DEST
  ditto $APP $DEST
  open $DEST
  echo "INSTALLED -> $DEST"
fi
