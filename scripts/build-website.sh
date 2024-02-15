#!/bin/bash

# Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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
WEBSITE_DIRECTORY="${ROOT_DIRECTORY}/docs"
WEBSITE_SIMULATOR_DIRECTORY="${ROOT_DIRECTORY}/docs/simulator"
SIMULATOR_WEB_DIRECTORY="${ROOT_DIRECTORY}/simulator/web"

RELEASE_NOTES_TEMPLATE_PATH="${SCRIPTS_DIRECTORY}/release-notes.markdown"
HISTORY_PATH="${SCRIPTS_DIRECTORY}/history.yaml"
RELEASE_NOTES_DIRECTORY="${ROOT_DIRECTORY}/docs/release-notes"
RELEASE_NOTES_PATH="${RELEASE_NOTES_DIRECTORY}/index.markdown"

source "${SCRIPTS_DIRECTORY}/environment.sh"

cd "$ROOT_DIRECTORY"
if [ -d "${RELEASE_NOTES_DIRECTORY}" ]; then
    rm -r "${RELEASE_NOTES_DIRECTORY}"
fi
mkdir -p "${RELEASE_NOTES_DIRECTORY}"
changes notes --pre-release --all --released --template "$RELEASE_NOTES_TEMPLATE_PATH" > "$RELEASE_NOTES_PATH"

# Install the Jekyll dependencies.
export GEM_HOME="${ROOT_DIRECTORY}/.local/ruby"
mkdir -p "$GEM_HOME"
export PATH="${GEM_HOME}/bin":$PATH
gem install bundler
cd "${WEBSITE_DIRECTORY}"
bundle install

# Build the website.
cd "${WEBSITE_DIRECTORY}"
bundle exec jekyll build
