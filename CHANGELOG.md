# Changelog

All notable user-visible changes to HarnessDock are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project intends to use semantic versioning after the first public release.

## [Unreleased]

### Changed

- Managed Harness processes now inherit `DEEPSEEK_API_KEY` from the HarnessDock launch environment, allowing the official model settings page to use environment authentication instead of asking for the same key again.

### Security and privacy

- Keychain-only balance credentials remain native-only; credential values are not copied into WebView scripts, project files, or Harness logs.

### Release blockers

- Select and add a repository license.
- Produce a Developer ID-signed and Apple-notarized macOS package.
- Verify the exact downloadable artifact on a clean Mac and record its SHA-256 checksum.
- Capture a clean Product Hunt gallery without account balance or development-session content.

## [0.1.0] - 2026-08-27

### Added

- Native SwiftUI and WebKit shell for the official DeepSeek Harness web interface.
- Local project selection, remembered workspaces, automatic Harness startup, recovery, logs, and process cleanup.
- Harness and official DeepSeek Chat surfaces with retained WebKit sessions.
- DeepSeek API balance display backed by macOS Keychain.
- Beijing-time peak/off-peak status, RMB model pricing, and locally available session token counters.
- Custom local background images with adjustable content dimming.
- System Default, Simplified Chinese, and English native interface options.
- Six-step settings guide for presets, permissions, appearance, send behavior, models, and plugins.
- `@harnessdock/pet` Harness plugin with DeepWhale and Marina, edge docking, drag interactions, and task-aware running/success/failure animations.
- Optional native Chat pet preview for compatible local pet packages.

### Changed

- Renamed the product, app bundle, Swift package/targets, build artifacts, plugin package, documentation, and launch copy from DS Harness to HarnessDock.
- Retained the legacy compatibility bundle identifier, Application Support location, Keychain service, and migrated the pet preference key so existing local data survives the rename.
- API key configuration, theme background, and language controls are consolidated in the native Settings window.
- Existing API credentials are represented by a configured state instead of being echoed into an input field.
- Chat Enter handling protects IME confirmation, modified Enter, single-line fields, and empty drafts from accidental submission.
- Balance and theme controls use compact sidebar layouts that remain aligned in collapsed mode.

### Security and privacy

- Balance credentials are read from `DEEPSEEK_API_KEY` or stored in macOS Keychain and are never written to project files or Harness logs.
- Balance lookup is limited to the official read-only `https://api.deepseek.com/user/balance` endpoint.
- The Harness pet observes session status only and does not read or transmit prompts, replies, command arguments, or tool output.
- Background images and imported pet packages remain local to the Mac.

### Known limitations

- The current source build is ad-hoc signed, not Apple-notarized, and has no automatic updater.
- The local candidate artifact is arm64; a public download still needs Universal 2 or clearly separated architecture-specific packages.
- DeepSeek Chat requires a normal DeepSeek account login.
- Chat pet task-state reactions are not included in this preview.
- DeepSeek Harness remains a developer preview and upstream UI changes may require compatibility updates.
