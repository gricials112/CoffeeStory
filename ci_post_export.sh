#!/bin/sh
# Xcode Cloud post-export script
# Automatically uploads to App Store Connect

xcrun xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$CI_APP_STORE_SIGNED_EXPORT_OPTIONS_PLIST" \
  -exportPath "/tmp/AppExport" \
  -allowProvisioningUpdates
