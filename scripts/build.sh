#!/bin/bash

set -e
set -o pipefail
set -x

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIRECTORY="${SCRIPT_DIRECTORY}/.."

# TODO: Re-enable test builds if possible using a locally generated signing key.

function build_scheme {
    xcodebuild \
        -workspace Bookmarks.xcworkspace \
        -scheme "$1" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO "${@:2}" | xcpretty
}

cd "$ROOT_DIRECTORY"

xcrun instruments -s devices

build_scheme "BookmarksCore iOS" clean build build-for-testing test \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 12 Pro,OS=14.4'
build_scheme "BookmarksCore macOS" clean build build-for-testing test
build_scheme "Bookmarks iOS" clean build
build_scheme "Bookmarks macOS" clean build
