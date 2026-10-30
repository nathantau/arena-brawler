#!/bin/sh
# Bumps the iOS build number, exports the Xcode project, archives and uploads to TestFlight.
# Needs an App Store Connect API key: ASC_KEY_ID + ASC_ISSUER_ID, key at
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8. Commits the bump.
set -eu
cd "$(dirname "$0")/../.."
presets=export_presets.cfg

build=$(sed -n 's/^application\/version="\([0-9]*\)"/\1/p' $presets)
next=$((build + 1))
sed -i '' "s/^application\/version=\"[0-9]*\"/application\/version=\"$next\"/" $presets

auth="-authenticationKeyPath $HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID:?set ASC_KEY_ID}.p8 -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID ${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
out=$(mktemp -d)
rm -rf build/ios && mkdir -p build/ios
godot --path . --headless --export-release "iOS" build/ios/ArenaBrawler.xcodeproj > "$out/export.log" 2>&1 \
  && [ -d build/ios/ArenaBrawler.xcodeproj ] || { tail -20 "$out/export.log"; git checkout $presets; exit 1; }

archive="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/ArenaBrawler-build$next.xcarchive"
xcodebuild archive -project build/ios/ArenaBrawler.xcodeproj -scheme ArenaBrawler \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  -allowProvisioningUpdates $auth CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" > "$out/archive.log" 2>&1 \
  || { tail -20 "$out/archive.log"; git checkout $presets; exit 1; }
xcodebuild -exportArchive -archivePath "$archive" \
  -exportOptionsPlist tools/release/ExportOptions.plist \
  -exportPath "$out/export" -allowProvisioningUpdates $auth > "$out/upload.log" 2>&1 \
  || { tail -20 "$out/upload.log"; git checkout $presets; exit 1; }

git commit -qm "Bump iOS build to $next" $presets
echo "Uploaded build $next"
