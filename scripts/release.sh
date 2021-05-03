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

# List the current tags which (by now) should include one for the release we're about to create.
echo "All tags:"
git tag

# Log the state for debugging.
echo "CHANGES_TAG: $CHANGES_TAG"
echo "CHANGES_TITLE: $CHANGES_TITLE"
echo "CHANGES_NOTES: $CHANGES_NOTES"
echo "CHANGES_NOTES_FILE: $CHANGES_NOTES_FILE"
cat "$CHANGES_NOTES_FILE"

# Actually make the release.
# Disappointingly, there seems to be an issue where the release create step doesn't use the specified tag if a set of
# files are also provided for upload. To work around this, we instead perform a secondary upload step.
gh release create "$CHANGES_TAG" --prerelease --title "$CHANGES_TITLE" --notes-file "$CHANGES_NOTES_FILE"
gh release upload "$CHANGES_TAG" build/Bookmarks-macOS*.zip
