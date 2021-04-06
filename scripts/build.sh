#!/bin/bash

set -e
set -o pipefail
set -x

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIRECTORY="${SCRIPT_DIRECTORY}/.."

PROJECT_PATH="${ROOT_DIRECTORY}/ios/Bookmarks.xcodeproj"

# TODO: Re-enable test builds if possible using a locally generated signing key.

function build_scheme {
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$1" \
        clean \
        build \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
}

build_scheme Stuff
