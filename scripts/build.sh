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

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
BUILD_DIRECTORY="${ROOT_DIRECTORY}/build"
TEMPORARY_DIRECTORY="${ROOT_DIRECTORY}/temp"

KEYCHAIN_PATH="${TEMPORARY_DIRECTORY}/temporary.keychain"
ARCHIVE_PATH="${BUILD_DIRECTORY}/Bookmarks.xcarchive"
FASTLANE_ENV_PATH="${ROOT_DIRECTORY}/fastlane/.env"

CHANGES_DIRECTORY="${SCRIPTS_DIRECTORY}/changes"
BUILD_TOOLS_DIRECTORY="${SCRIPTS_DIRECTORY}/build-tools"

CHANGES_GITHUB_RELEASE_SCRIPT="${CHANGES_DIRECTORY}/examples/gh-release.sh"

PATH=$PATH:$CHANGES_DIRECTORY
PATH=$PATH:$BUILD_TOOLS_DIRECTORY

source "${SCRIPTS_DIRECTORY}/environment.sh"

# Check that the GitHub command is available on the path.
which gh || (echo "GitHub cli (gh) not available on the path." && exit 1)

# Process the command line arguments.
POSITIONAL=()
NOTARIZE=${NOTARIZE:-false}
RELEASE=${TRY_RELEASE:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -n|--notarize)
        NOTARIZE=true
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

function xcode_project {
    xcodebuild \
        -workspace Bookmarks.xcworkspace "$@"
}

function build_scheme {
    # Disable code signing for the build server.
    xcode_project \
        -scheme "$1" \
        "${@:2}" | xcpretty
}

cd "$ROOT_DIRECTORY"

# List the available schemes.
xcode_project -list

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
echo "$TEMPORARY_KEYCHAIN_PASSWORD" | build-tools create-keychain "$KEYCHAIN_PATH" --password

function cleanup {
    # Cleanup the temporary files and keychain.
    cd "$ROOT_DIRECTORY"
    build-tools delete-keychain "$KEYCHAIN_PATH"
    rm -rf "$TEMPORARY_DIRECTORY"
}

trap cleanup EXIT

# Determine the version and build number.
VERSION_NUMBER=`changes --scope macOS version`
GIT_COMMIT=`git rev-parse --short HEAD`
TIMESTAMP=`date +%s`
BUILD_NUMBER="${GIT_COMMIT}.${TIMESTAMP}"

# Import the certificates into our dedicated keychain.
bundle exec fastlane import_certificates keychain:"$KEYCHAIN_PATH"

# Install the provisioning profile.
# TODO: Convenience utility for installing a provisioning profile #105
#       https://github.com/inseven/bookmarks/issues/105
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
xcode_project \
    -scheme "Bookmarks macOS" \
    -config Release \
    -archivePath "$ARCHIVE_PATH" \
    OTHER_CODE_SIGN_FLAGS="--keychain=\"${KEYCHAIN_PATH}\"" \
    BUILD_NUMBER=$BUILD_NUMBER \
    MARKETING_VERSION=$VERSION_NUMBER \
    clean archive | xcpretty
xcodebuild \
    -archivePath "$ARCHIVE_PATH" \
    -exportArchive \
    -exportPath "$BUILD_DIRECTORY" \
    -exportOptionsPlist "macos/ExportOptions.plist"

APP_BASENAME="Bookmarks.app"
APP_PATH="$BUILD_DIRECTORY/$APP_BASENAME"

# Show the code signing details.
codesign -dvv "$APP_PATH"

# Notarize the release build.
if $NOTARIZE ; then
    fastlane notarize_release package:"$APP_PATH"
fi

# Archive the results.
pushd "$BUILD_DIRECTORY"
ZIP_BASENAME="Bookmarks-macOS-${VERSION_NUMBER}.zip"
zip -r --symlinks "$ZIP_BASENAME" "$APP_BASENAME"
build-tools verify-notarized-zip "$ZIP_BASENAME"
rm -r "$APP_BASENAME"
zip -r "Artifacts.zip" "."
popd

# Attempt to create a version tag and publish a GitHub release; fails quietly if there's no new release.
if $RELEASE ; then
    changes \
        --scope macOS \
        release \
        --skip-if-empty \
        --push \
        --exec "${CHANGES_GITHUB_RELEASE_SCRIPT}" \
        "${BUILD_DIRECTORY}/${ZIP_BASENAME}"
fi
