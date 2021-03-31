#!/bin/bash

set -e
set -o pipefail
set -x

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIRECTORY="${SCRIPT_DIRECTORY}/.."

PROJECT_PATH="${ROOT_DIRECTORY}/ios/Stuff.xcodeproj"

# macOS
# TODO: Re-enable when a macOS 11 builder is available.
# xcodebuild \
#     -project "$PROJECT_PATH" \
#     -scheme Bookmarks \
#     clean build test | xcpretty

# iOS
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme Stuff \
    clean build-for-testing | xcpretty

# TODO: Re-enable 'test'