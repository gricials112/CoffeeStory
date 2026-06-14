#!/bin/sh
# Xcode Cloud pre-build script
# Auto-increment build number so we never hit "bundle version must be higher"

if [ -n "$CI_BUILD_NUMBER" ]; then
    agvtool new-version -all "$CI_BUILD_NUMBER"
fi
