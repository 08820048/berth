<p align="center">
  <img src="docs/design/berth-icon-modern.png" width="88" alt="Berth icon" />
</p>

<h1 align="center">Berth</h1>

<p align="center">
  <strong>Your dev ports, berthed in the menu bar.</strong><br>
  See which process holds a port, decide whether it can go, stop it, and confirm the berth is free.
</p>

<p align="center">
  <a href="README.en.md">English</a> · <a href="README.md">简体中文</a>
</p>

<p align="center">
  <a href="https://berth.fyi">berth.fyi</a> ·
  <a href="#-download">Download</a> ·
  <a href="#-features">Features</a> ·
  <a href="#-development">Development</a> ·
  <a href="THIRD_PARTY_NOTICES.md">Third-party notices</a>
</p>

<p align="center">
  <a href="https://github.com/08820048/berth/releases"><img src="https://img.shields.io/badge/version-0.1.0-blue" alt="version" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple" alt="macOS 14+" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-green" alt="Apache-2.0" /></a>
  <a href="https://berth.fyi"><img src="https://img.shields.io/badge/web-berth.fyi-orange" alt="berth.fyi" /></a>
</p>

<p align="center">
  <img src="https://berth.fyi/app-hero.png" width="560" alt="Berth panel screenshot" />
</p>

## ⬇️ Download

Get the latest `Berth-*.dmg` from [berth.fyi](https://berth.fyi) — signed and notarized.

Already installed? You never need to update by hand: Berth checks for updates via [Sparkle](https://sparkle-project.org), downloads them in the background, and all you do is click "Restart to Update" in the panel.

## ✨ Features

- **Berth grid** — pin the ports you use every day; green dot means free, amber means taken
- **Projects, not PIDs** — ports are grouped by project with the real process, PID, and path, so you always know what you're stopping
- **Release with confidence** — a clear confirmation before anything is stopped; force-kill only when you explicitly ask
- **Search like a terminal** — jump to a port, open its localhost URL, or type `release 3000` in the search field
- **In-panel updates** — check, auto-download, then a single teal "Restart to Update" click
- **Bilingual & dual appearance** — English / 简体中文, light / dark, follows your system

## 🛠 Development

Requirements: macOS 14+, Xcode 16+ (the project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)).

```bash
brew install xcodegen
make project   # generate Berth.xcodeproj
make test      # run unit tests (ad-hoc signing, no developer certificate needed)
make run       # build and launch
```

The app lives in the menu bar only — no Dock icon. Click the status item to open the panel; default shortcut is `⌥⌘P` (remappable in Settings).

Language: choose "System", "简体中文", or "English" under Settings → General; changes apply instantly. Process names, commands, paths, and raw diagnostics stay in their original language.

Standalone distribution: the App Sandbox is intentionally disabled, otherwise Berth cannot inspect other processes' listening ports.

## 🚀 Releasing

`scripts/release.sh` does the whole thing: Developer ID signing (including Sparkle's nested helpers) → Apple notarization → staple → package a zip (Sparkle update channel) + DMG (website download) → generate the EdDSA-signed `appcast.xml` → upload to Cloudflare R2.

```bash
# 1. Bump MARKETING_VERSION (major.minor.patch) and CURRENT_PROJECT_VERSION
#    (monotonically increasing integer) in project.yml
# 2. Release
./scripts/release.sh
# 3. Commit the updated appcast.xml
```

Prerequisites:

- Developer ID Application certificate in the local keychain
- Notarization credentials: `xcrun notarytool store-credentials berth-notary`
- Sparkle EdDSA private key in the local keychain (created with `generate_keys`)
- [wrangler](https://developers.cloudflare.com/workers/wrangler/) logged in (R2 uploads)

Sparkle private keys and notarization credentials live only in the release machine's keychain and must never be committed.

## 📄 License

[Apache License 2.0](LICENSE) · third-party notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

Copyright © 2026 xuyi
