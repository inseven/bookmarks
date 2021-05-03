#!/bin/bash

# Copyright (c) 2018-2021 InSeven Limited
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e
set -o pipefail
set -x
set -u

# TODO: Re-enable test builds if possible using a locally generated signing key.

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPT_DIRECTORY}/.."
BUILD_DIRECTORY="${ROOT_DIRECTORY}/build"
TEMPORARY_DIRECTORY="${ROOT_DIRECTORY}/temp"

KEYCHAIN_PATH="${TEMPORARY_DIRECTORY}/temporary.keychain-db"
ARCHIVE_PATH="${BUILD_DIRECTORY}/Bookmarks.xcarchive"
FASTLANE_ENV_PATH="${ROOT_DIRECTORY}/fastlane/.env"

CHANGES_SCRIPT="${ROOT_DIRECTORY}/changes/changes"
BUILD_TOOLS_SCRIPT="${ROOT_DIRECTORY}/scripts/build-tools"

# Process the command line arguments.
POSITIONAL=()
NOTARIZE=true
RELEASE=false
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -N|--skip-notarize)
        NOTARIZE=false
        shift
        ;;
        -r|--release)
        RELEASE=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

# iPhone to be used for smoke test builds and tests.
# This doesn't specify the OS version to allow the build script to recover from minor build changes.
IPHONE_DESTINATION="platform=iOS Simulator,name=iPhone 12 Pro"

# Generate a random string to secure the local keychain.
export TEMPORARY_KEYCHAIN_PASSWORD=`openssl rand -base64 14`

# Source the Fastlane .env file if it exists to make local development easier.
if [ -f "$FASTLANE_ENV_PATH" ] ; then
    echo "Sourcing .env..."
    source "$FASTLANE_ENV_PATH"
fi

function build_scheme {
    xcodebuild \
        -workspace Bookmarks.xcworkspace \
        -scheme "$1" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO "${@:2}" | xcpretty
}

cd "$ROOT_DIRECTORY"

# List the available schemes.
xcrun instruments -s devices

# Smoke test builds.

# BookmarksCore
build_scheme "BookmarksCore iOS" clean build build-for-testing test \
  -sdk iphonesimulator \
  -destination "$IPHONE_DESTINATION"
build_scheme "BookmarksCore macOS" clean build build-for-testing test

# iOS
build_scheme "Bookmarks iOS" clean build build-for-testing test \
  -sdk iphonesimulator \
  -destination "$IPHONE_DESTINATION"

# macOS
build_scheme "Bookmarks macOS" clean build build-for-testing

# Build the macOS archive.

# Clean up the build directory.
if [ -d "$BUILD_DIRECTORY" ] ; then
    rm -r "$BUILD_DIRECTORY"
fi
mkdir -p "$BUILD_DIRECTORY"

# Create the a new keychain.
if [ -d "$TEMPORARY_DIRECTORY" ] ; then
    rm -rf "$TEMPORARY_DIRECTORY"
fi
mkdir -p "$TEMPORARY_DIRECTORY"
echo "$TEMPORARY_KEYCHAIN_PASSWORD" | "$BUILD_TOOLS_SCRIPT" create-keychain "$KEYCHAIN_PATH" --password

function cleanup {
    # Cleanup the temporary files and keychain.
    cd "$ROOT_DIRECTORY"
    "$BUILD_TOOLS_SCRIPT" delete-keychain "$KEYCHAIN_PATH"
    rm -rf "$TEMPORARY_DIRECTORY"
}

trap cleanup EXIT

# Determine the version and build number.
VERSION_NUMBER=`"$CHANGES_SCRIPT" --scope macOS current-version`
GIT_COMMIT=`git rev-parse --short HEAD`
TIMESTAMP=`date +%s`
BUILD_NUMBER="${GIT_COMMIT}.${TIMESTAMP}"

# Import the certificates into our dedicated keychain.
fastlane import_certificates keychain:"$KEYCHAIN_PATH"

# Install the provisioning profile.
file="macos/Bookmarks_Developer_ID_Application.provisionprofile"
uuid=`grep UUID -A1 -a "$file" | grep -io "[-A-F0-9]\{36\}"`
extension="${file##*.}"
PROFILE_DESTINATION=~/"Library/MobileDevice/Provisioning Profiles/$uuid.$extension"
if [ ! -f "$PROFILE_DESTINATION" ] ; then
    echo "Installing provisioning profile '$PROFILE_DESTINATION'..."
    mkdir -p ~/"Library/MobileDevice/Provisioning Profiles/"
    cp "$file" "$PROFILE_DESTINATION"
else
    echo "Provisioning profile installed; skipping"
fi

# Archive and export the build.
xcodebuild -workspace Bookmarks.xcworkspace -scheme "Bookmarks macOS" -config Release -archivePath "$ARCHIVE_PATH" OTHER_CODE_SIGN_FLAGS="--keychain=\"${KEYCHAIN_PATH}\"" BUILD_NUMBER=$BUILD_NUMBER MARKETING_VERSION=$VERSION_NUMBER archive | xcpretty
xcodebuild -archivePath "$ARCHIVE_PATH" -exportArchive -exportPath "$BUILD_DIRECTORY" -exportOptionsPlist "macos/ExportOptions.plist"

APP_BASENAME="Bookmarks.app"
APP_PATH="$BUILD_DIRECTORY/$APP_BASENAME"

# Show the code signing details.
codesign -dvv "$APP_PATH"

# Notarize the release build.
if $NOTARIZE ; then
    fastlane notarize_release package:"$APP_PATH"
fi

# Belt-and-braces check that the bundle is actually correctly notarized.
spctl -a -v "$APP_PATH" && echo "Bundle passed signing checks 🎉"

# Archive the results.
pushd "$BUILD_DIRECTORY"
zip -r --symlinks "Bookmarks-macOS-${VERSION_NUMBER}.zip" "$APP_BASENAME"
"$BUILD_TOOLS_SCRIPT" verify-notarized-zip "Bookmarks-macOS-${VERSION_NUMBER}.zip"
rm -r "$APP_BASENAME"
zip -r "Artifacts.zip" "."
popd
