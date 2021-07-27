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

scripts_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
root_directory="${scripts_directory}/.."
changes_directory="${scripts_directory}/changes"
build_tools_directory="${scripts_directory}/build-tools"

environment_path="${scripts_directory}/environment.sh"

source "$environment_path"

# Install the Python dependencies
pip3 install --user pipenv
PIPENV_PIPFILE="$changes_directory/Pipfile" pipenv install
PIPENV_PIPFILE="$build_tools_directory/Pipfile" pipenv install

# Install the Ruby dependencies
cd "$root_directory"
gem install bundler
bundle install

# Install the GitHub CLI
github_cli_url="https://github.com"`curl -s -L https://github.com/cli/cli/releases/latest | grep -o -e "/.*macOS.*tar.gz"`
if [ -d "$GITHUB_CLI_PATH" ] ; then
    rm -r "$GITHUB_CLI_PATH"
fi
mkdir -p "$GITHUB_CLI_PATH"
curl --location "$github_cli_url" --output "cli.tar.gz"
tar --strip-components 1 -zxv -f "cli.tar.gz" -C "$GITHUB_CLI_PATH"
unlink "cli.tar.gz"
