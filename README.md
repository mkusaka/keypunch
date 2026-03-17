# Keypunch

A macOS menu bar app that launches applications via global keyboard shortcuts.

<p align="center">
  <img src="assets/screenshot.png" alt="Keypunch Settings Window" width="400">
</p>

## Features

- Register global keyboard shortcuts to launch any macOS application
- Menu bar icon with Show / Start at Login / Quit controls
- Settings window to add, edit, and remove shortcuts with app icons and shortcut badges
- Persistent storage — shortcuts survive app restarts
- Duplicate app detection

## Install

### Homebrew

```bash
brew install --cask mkusaka/tap/keypunch
```

### Manual Download

Download the latest `.zip` from [GitHub Releases](https://github.com/mkusaka/keypunch/releases), extract it, and move `Keypunch.app` to `/Applications`.

GitHub Releases and the Homebrew cask are signed with a Developer ID certificate and notarized by Apple, so Gatekeeper should allow normal launch after download.

## Requirements

- macOS 15.5+
- Xcode 16+

## Tooling

This repository uses `mise` to pin the CLI tools used for linting.

```bash
brew install mise
mise trust
mise install
```

## Release Automation

This workflow uses a locally exported `Developer ID Application` certificate for signing and an App Store Connect API key for `notarytool`.

Signed releases require these GitHub repository secrets:

- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_DEVELOPER_ID_P12_BASE64`: Base64-encoded `Developer ID Application` certificate exported as `.p12`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`: Password used when exporting the `.p12`
- `APPLE_KEYCHAIN_PASSWORD`: Random password used for the temporary GitHub Actions keychain
- `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`: Base64-encoded App Store Connect API key (`.p8`) used for `notarytool`
- `APPLE_APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID
- `APPLE_APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID

The Apple account used for release automation must have a valid `Developer ID Application` certificate and access to App Store Connect API keys.

### App Store Connect Setup

1. Sign in to App Store Connect as the Apple Developer Account Holder and open `Users and Access`.
2. Open `Integrations` and request access to the App Store Connect API if it is not enabled yet.
3. Create a Team API key and download the `.p8` file. This workflow expects a Team key, not an Individual key, because `notarytool` uses the issuer ID.
4. Export the local `Developer ID Application` certificate from Keychain Access as a `.p12` file.
5. Add `APPLE_TEAM_ID`, `APPLE_DEVELOPER_ID_P12_BASE64`, `APPLE_DEVELOPER_ID_P12_PASSWORD`, `APPLE_KEYCHAIN_PASSWORD`, `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`, `APPLE_APP_STORE_CONNECT_KEY_ID`, `APPLE_APP_STORE_CONNECT_ISSUER_ID`, and `HOMEBREW_TAP_TOKEN` to the repository's GitHub Actions secrets.
6. Base64-encode the contents of `AuthKey_XXXXXX.p8` and store the result in `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`.
7. Base64-encode the exported `.p12` file and store the result in `APPLE_DEVELOPER_ID_P12_BASE64`.
8. Run the workflow manually or with a test tag once to confirm that archive, export, and notarization all succeed.

### Certificate Export

1. Open Keychain Access and select `login` -> `My Certificates`.
2. Select `Developer ID Application: <your name>`.
3. Choose `File` -> `Export Items...`.
4. Export as `Personal Information Exchange (.p12)`.
5. Set a strong export password and store it in `APPLE_DEVELOPER_ID_P12_PASSWORD`.
6. Generate a separate random password for `APPLE_KEYCHAIN_PASSWORD`. This is only used for the temporary keychain created inside GitHub Actions.

### Certificate Rotation And Monitoring

Developer ID certificates expire and must be renewed manually. When you create a replacement certificate, export a new `.p12` file and update `APPLE_DEVELOPER_ID_P12_BASE64` and `APPLE_DEVELOPER_ID_P12_PASSWORD`.

Apple's App Store Connect webhooks do not expose a dedicated certificate-expiry event, so there is no built-in way for Apple to push a "certificate is about to expire" notification directly to SNS or Slack.

In practice, that leaves two options:

- Track the certificate expiry date manually and rotate the `.p12` before it expires
- Add your own monitoring, such as a scheduled GitHub Actions run or Lambda job that checks the certificate expiry date and sends failures to SNS or Slack

### Manual Validation Run

The `Release` workflow also supports `workflow_dispatch`. Manual runs use the `version` input as `MARKETING_VERSION` and execute `archive` -> `exportArchive` -> `notarytool` -> `stapler` using the `.p12` certificate from GitHub Actions secrets. The `version` input only accepts digits and dots, for example `1.2.3`.

Manual runs skip these publication steps:

- GitHub Release creation
- `repository_dispatch` to the Homebrew tap

`notarytool submit` uses `--wait --timeout 1h`, so the workflow waits for notarization to finish but fails after one hour if Apple has not returned a result.

Local `xcodebuild` builds remain unsigned unless you sign them with your own Apple certificate.

## Build

```bash
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' build
```

## Run

Open in Xcode and press Cmd+R, or:

```bash
open "$(xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -showBuildSettings | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/Keypunch.app"
```

## Lint

```bash
mise exec -- swiftformat --lint .
mise exec -- swiftlint lint --quiet
```

## Test

```bash
# All tests
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' test

# Unit tests only
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' -only-testing:KeypunchTests test

# UI tests only
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' -only-testing:KeypunchUITests test
```

## Tech Stack

- SwiftUI (`NSStatusItem` + `NSWindow`)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for global hotkey registration
- `@Observable` for state management
- UserDefaults for persistence

## License

MIT
