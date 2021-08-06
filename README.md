# Bookmarks

[![Build](https://github.com/inseven/bookmarks/actions/workflows/build.yaml/badge.svg?branch=main)](https://github.com/inseven/bookmarks/actions/workflows/build.yaml)

[Pinboard](https://pinboard.in) client for iOS and macOS.

![Bookmarks screenshot](screenshot.png)

## Development

### Build Numbers

The iOS and macOS apps use auto-generated build numbers that attempt to encode the build timestamp, along with some details of the commit used. They follow the format:

```
YYmmddHHMMxxxxxxxx
```

- `YY` -- two-digit year
- `mm` -- month
- `dd` -- day
- `HH` -- hours (24h)
- `MM` -- minutes
- `xxxxxxxx` -- zero-padded integer representation of a 6-character commit SHA

These can be quickly decoded using the `build-tools` script:

```
% scripts/build-tools/build-tools parse-build-number 210727192100869578
2021-07-27 19:21:00 (UTC)
0d44ca
```

### Managing Certificates

Builds use base64 encoded [PKCS 12](https://en.wikipedia.org/wiki/PKCS_12) certificate and private key containers specified in the `IOS_CERTIFICATE_BASE64` and `MACOS_CERTIFICATE_BASE64` environment variables (with the password given in the `IOS_CERTIFICATE_PASSWORD` and `MACOS_CERTIFICATE_PASSWORD` environment variables respectively). This loosely follows the GitHub approach to [managing certificates](https://docs.github.com/en/actions/guides/installing-an-apple-certificate-on-macos-runners-for-xcode-development).

Keychain Access can be used to export your certificate and private key in the PKCS 12 format, and the base64 encoded version is generated as follows:

```bash
base64 build_certificate.p12 | pbcopy
```

This, along with the password used to protect the certificate, can then be added to the GitHub project secrets.

### Builds

In order to make continuous integration easy the `scripts/build.sh` script builds the full project, including submitting the macOS app for notarization. In order to run this script (noting that you probably don't want to use it for regular development cycles), you'll need to configure your environment accordingly, by setting the following environment variables:

- `IOS_CERTIFICATE_BASE64` -- base64 encoded PKCS 12 certificate for iOS App Store builds (see above for details)
- `IOS_CERTIFICATE_PASSWORD` -- password used to protect the iOS certificate
- `MACOS_CERTIFICATE_BASE64` -- base64 encoded PKCS 12 certificate for macOS Developer ID builds (see above for details)
- `MACOS_CERTIFICATE_PASSWORD` -- password used to protect the macOS certificate
- `APPLE_DEVELOPER_ID` -- individual Apple Developer Account ID (used for notarization)
- `APPLE_API_KEY` -- base64 encoded App Store Connect API key (see https://appstoreconnect.apple.com/access/api)
- `APPLE_API_KEY_ID` -- App Store Connect API key id (see https://appstoreconnect.apple.com/access/api)
- `APPLE_API_KEY_ISSUER_ID` -- App Store connect API key issuer id (see https://appstoreconnect.apple.com/access/api)
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` -- [app-specific password](https://support.apple.com/en-us/HT204397) for the Developer Account
- `NOTARIZE` -- boolean indicating whether to attempt notarize the build (conditionally set based on the current branch using `${{ github.ref == 'refs/heads/main' }}`)
- `TRY_RELEASE` -- boolean indicating whether to attempt a release (conditionally set based on the current branch using `${{ github.ref == 'refs/heads/main' }}`)
- `GITHUB_TOKEN` -- [GitHub token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) used to create the release

The script (like Fastlane) will look for and source an environment file in the Fastlane directory (`Fastlane/.env`) which you can add your local details to. This file is, of course, in `.gitignore`. For example,

```bash
# Certificate store
export IOS_CERTIFICATE_BASE64=
export IOS_CERTIFICATE_PASSWORD=
export MACOS_CERTIFICATE_BASE64=
export MACOS_CERTIFICATE_PASSWORD=

# Developer account
export APPLE_DEVELOPER_ID=
export APPLE_API_KEY=
export APPLE_API_KEY_ID=
export APPLE_API_KEY_ISSUER_ID=
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=

# GitHub (only required if publishing releases locally)
export GITHUB_TOKEN=
```

Once you've added your environment variables to this, run the script from the root of the project directory as follows:

```bash
./scripts/build.sh
```

You can notarize local builds by specifying the `--notarize` parameter:

```bash
./scripts/build.sh --notarize
```

You can publish a build locally by specifying the `--release` parameter:

```bash
./scripts/build.sh --release
```

## Licensing

Bookmarks is licensed under the MIT License (see [LICENSE](LICENSE)).

During development, the plan is to make builds available for free through the [Releases](https://github.com/inseven/bookmarks/releases) section of the GitHub project. Once we reach something robust and ready for release, we'll make a paid version available through the [App Store](https://www.apple.com/app-store/) to fund on-going costs of development. The app will remain Open Source, and anyone is free to contribute or build their own copies, and we'll figure out a way to give free licenses to contributors.
