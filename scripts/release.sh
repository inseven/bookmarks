#!/bin/bash

# Copyright (c) 2016-2022 InSeven Limited
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

# Upload the build to TestFlight.
bundle exec fastlane upload \
    api_key:"$API_KEY_PATH" \
    api_key_id:"$APPLE_API_KEY_ID" \
    api_key_issuer_id:"$APPLE_API_KEY_ISSUER_ID" \
    ipa:"$1" \
    changelog:"${CHANGES_NOTES}"

# Upload the build to TestFlight.
bundle exec fastlane upload \
    api_key:"$API_KEY_PATH" \
    api_key_id:"$APPLE_API_KEY_ID" \
    api_key_issuer_id:"$APPLE_API_KEY_ISSUER_ID" \
    pkg:"$2" \
    changelog:"${CHANGES_NOTES}"

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
