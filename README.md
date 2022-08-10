# Bookmarks

[![Build](https://github.com/inseven/bookmarks/actions/workflows/build.yaml/badge.svg?branch=main)](https://github.com/inseven/bookmarks/actions/workflows/build.yaml)

[Pinboard](https://pinboard.in) client for iOS and macOS.

![Bookmarks screenshot](screenshot.png)

## Development

Bookmarks follows the version numbering, build and signing conventions for InSeven Limited apps. Further details can be found [here](https://github.com/inseven/build-documentation).

### Builds

In order to make continuous integration easy the `scripts/build.sh` script builds the full project, including submitting the macOS app for notarization. In order to run this script (noting that you probably don't want to use it for regular development cycles), you'll need to configure your environment accordingly, by setting the following environment variables:

- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` -- base64 encoded PKCS 12 certificate for iOS App Store builds (see above for details)
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` -- password used to protect the iOS certificate
- `MACOS_DEVELOPER_INSTALLER_CERTIFICATE` -- base64 encoded PKCS 12 certificate for macOS Developer ID builds (see above for details)
- `MACOS_DEVELOPER_INSTALLER_CERTIFICATE_PASSWORD` -- password used to protect the macOS certificate
- `APPLE_API_KEY` -- base64 encoded App Store Connect API key (see https://appstoreconnect.apple.com/access/api)
- `APPLE_API_KEY_ID` -- App Store Connect API key id (see https://appstoreconnect.apple.com/access/api)
- `APPLE_API_KEY_ISSUER_ID` -- App Store connect API key issuer id (see https://appstoreconnect.apple.com/access/api)
- `NOTARIZE` -- boolean indicating whether to attempt notarize the build (conditionally set based on the current branch using `${{ github.ref == 'refs/heads/main' }}`)
- `TRY_RELEASE` -- boolean indicating whether to attempt a release (conditionally set based on the current branch using `${{ github.ref == 'refs/heads/main' }}`)
- `GITHUB_TOKEN` -- [GitHub token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) used to create the release

The script (like Fastlane) will look for and source an environment file in the Fastlane directory (`Fastlane/.env`) which you can add your local details to. This file is, of course, in `.gitignore`. For example,

```bash
# Certificate store
export APPLE_DISTRIBUTION_CERTIFICATE_BASE64=
export APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD=
export MACOS_DEVELOPER_INSTALLER_CERTIFICATE=
export MACOS_DEVELOPER_INSTALLER_CERTIFICATE_PASSWORD=

# Developer account
export APPLE_API_KEY=
export APPLE_API_KEY_ID=
export APPLE_API_KEY_ISSUER_ID=

# GitHub (only required if publishing releases locally)
export GITHUB_TOKEN=
```

Once you've added your environment variables to this, run the script from the root of the project directory as follows:

```bash
./scripts/build.sh
```

You can publish a build locally by specifying the `--release` parameter:

```bash
./scripts/build.sh --release
```

## Licensing

Bookmarks is licensed under the MIT License (see [LICENSE](LICENSE)).

During development, the plan is to make builds available for free through the [Releases](https://github.com/inseven/bookmarks/releases) section of the GitHub project. Once we reach something robust and ready for release, we'll make a paid version available through the [App Store](https://www.apple.com/app-store/) to fund on-going costs of development. The app will remain Open Source, and anyone is free to contribute or build their own copies, and we'll figure out a way to give free licenses to contributors.
