# Bookmarks

[![Build](https://github.com/jbmorley/bookmarks/actions/workflows/test.yaml/badge.svg?branch=main)](https://github.com/jbmorley/bookmarks/actions/workflows/test.yaml)

[Pinboard](https://pinboard.in) client for iOS and macOS.

![Bookmarks screenshot](screenshot.png)

## Download

- [Version 0.1.0 for macOS](https://github.com/jbmorley/bookmarks/releases/download/macOS_0.1.0/Bookmarks-0.1.0.zip)

## Release Notes

- [iOS](documentation/release-notes/ios.markdown)
- [macOS](documentation/release-notes/macos.markdown)

## Development

### Test Plans

- [macOS](documentation/test-plans/macos.markdown)

### Pull Requests

### Making a Release

#### macOS

1. Increment the version number and build number in Xcode.

2. Update the release notes by adding a new heading for the release (copy the existing formatting), and move the `main` changes about to be released to this new section.

3. Raise a [Pull Request](#pull-requests) for the project and release note changes.

4. Once the Pull Request is approved and merged, check out `main`, and create an archive build with 'Product' > 'Archive'.

5. Export the new build from the 'Organizer' by selecting the build, and clicking the 'Distribute App' button. Choose 'Developer ID', followed by 'Upload', and then accept the subsequent defaults. Once the uploaded binary has been signed by Apple, you will receive a notification through Xcode, and repeating the export steps will allow you to save the binary to disk.

6. Compress the newly exported binary by right-click and selecting 'Compress' in Finder, and then rename to include the platform and version, separated by dashes (e.g., `Bookmarks-macOS-0.1.2.zip`).

7. Create a corresponding git tag of the format `<platform>_<version>` and push it to the server. For example,

   ```bash
   git tag macOS_0.1.2
   git push origin macOS_0.1.2
   ```

8. On the [GitHub Tags page](https://github.com/jbmorley/bookmarks/tags), select the ... to the right of the tag, and select 'Create release' option.

9. Update the title accordingly (e.g., 'Version 0.1.2'), copy-and-paste the release notes from step 3., and attach the compressed binary.

10. Update the download link in the README and raise a Pull Request for the change.

## Licensing

Bookmarks is licensed under the MIT License (see [LICENSE](LICENSE)).

During development, the plan is to make builds available for free through the [Releases](https://github.com/jbmorley/bookmarks/releases) section of the GitHub project. Once we reach something robust and ready for release, we'll make a paid version available through the [App Store](https://www.apple.com/app-store/) to fund on-going costs of development. The app will remain Open Source, and anyone is free to contribute or build their own copies, and we'll figure out a way to give free licenses to contributors.

