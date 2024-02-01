#!/bin/bash

# Copyright (c) 2020-2024 InSeven Limited
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

# This script expects the iOS IPA to be passed as the first argument, the macOS PKG as the second argument, and any
# additional files to be attached to the GitHub release to be passed as subsequent arguments.

# Validate and upload the iOS build.
xcrun altool --validate-app \
    -f "$1" \
    --apiKey "$APPLE_API_KEY_ID" \
    --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
    --output-format json \
    --type ios
xcrun altool --upload-app \
    -f "$1" \
    --primary-bundle-id "uk.co.inseven.bookmarks" \
    --apiKey "$APPLE_API_KEY_ID" \
    --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
    --type ios

# Validate and upload the macOS build.
xcrun altool --validate-app \
    -f "$2" \
    --apiKey "$APPLE_API_KEY_ID" \
    --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
    --output-format json \
    --type macos
xcrun altool --upload-app \
    -f "$2" \
    --primary-bundle-id "uk.co.inseven.bookmarks" \
    --apiKey "$APPLE_API_KEY_ID" \
    --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
    --type macos

# Actually make the release.
FLAGS=()
if $CHANGES_INITIAL_DEVELOPMENT ; then
    FLAGS+=("--prerelease")
elif $CHANGES_PRE_RELEASE ; then
    FLAGS+=("--prerelease")
fi
gh release create "$CHANGES_TAG" --title "$CHANGES_QUALIFIED_TITLE" --notes-file "$CHANGES_NOTES_FILE" "${FLAGS[@]}"

# Upload the attachments.
for attachment in "$@"
do
    gh release upload "$CHANGES_TAG" "$attachment"
done
