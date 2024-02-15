#!/bin/bash

# Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe
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
RELEASE_NOTES_TEMPLATE_PATH="${SCRIPTS_DIRECTORY}/release-notes.markdown"
HISTORY_PATH="${SCRIPTS_DIRECTORY}/history.yaml"
RELEASE_NOTES_DIRECTORY="${ROOT_DIRECTORY}/docs/release-notes"
RELEASE_NOTES_PATH="${RELEASE_NOTES_DIRECTORY}/index.markdown"

source "${SCRIPTS_DIRECTORY}/environment.sh"


cd "$ROOT_DIRECTORY"

mkdir -p "$RELEASE_NOTES_DIRECTORY"
changes notes --all --released --history "$HISTORY_PATH" --template "$RELEASE_NOTES_TEMPLATE_PATH" > "$RELEASE_NOTES_PATH"
