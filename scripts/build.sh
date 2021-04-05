#!/bin/bash

set -e
set -o pipefail
set -x

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIRECTORY="${SCRIPT_DIRECTORY}/.."

PROJECT_PATH="${ROOT_DIRECTORY}/ios/Bookmarks.xcodeproj"

# TODO: Re-enable test builds if possible using a locally generated signing key.

# macOS
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme Bookmarks \
    clean \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO

# iOS
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme Stuff \
    clean \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO
