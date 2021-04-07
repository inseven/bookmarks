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
        clean \
        build \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
}

cd "$ROOT_DIRECTORY"
build_scheme Bookmarks
