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
        CODE_SIGNING_ALLOWED=NO "${@:2}"
}

cd "$ROOT_DIRECTORY"
build_scheme "BookmarksCore iOS" clean build
build_scheme "BookmarksCore macOS" clean build
build_scheme "Bookmarks iOS" clean build
build_scheme "Bookmarks macOS" clean build
