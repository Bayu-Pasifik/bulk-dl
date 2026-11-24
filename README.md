# Bulk DL

[![Release](https://img.shields.io/github/v/release/Bayu-Pasifik/bulk-dl)](https://github.com/Bayu-Pasifik/bulk-dl/releases/latest)
[![Website](https://img.shields.io/badge/website-bayu--pasifik.github.io-2E7D32)](https://bayu-pasifik.github.io/bulk-dl/)

Android app (Flutter) that downloads files, videos and whole playlists from a
link. It has a queue, background service, retry and resume.

**Website:** <https://bayu-pasifik.github.io/bulk-dl/> ·
**Docs:** [PRD](docs/PRD.md) · [Style](docs/STYLE.md) · [Tasks](docs/TASKS.md)

> Bulk DL is only a download tool. Download only content you have the right to
> keep, and follow the law and each site's terms. DRM-protected content is not
> supported.

## Install

1. Open the [latest release](https://github.com/Bayu-Pasifik/bulk-dl/releases/latest).
2. Download the APK for your device:
   - `app-arm64-v8a-release.apk` for most phones,
   - `app-armeabi-v7a-release.apk` for older 32-bit phones,
   - `app-x86_64-release.apk` for emulators.
3. Optional: check the file against its `.sha256` next to it.
4. Open the APK and allow installing from this source when asked.

The app can check for new releases itself and shows the SHA-256 in the update
dialog.

## Features

- **Sources**
  - Direct files, HLS (`.m3u8`, AES-128) and generic pages (`og:video`,
    `<video>`, JSON-LD, media links).
  - Site extractors, see [Supported sites](#supported-sites).
  - Multi-URL input (one link per line) and share-sheet intake.
- **Queue**: parallel downloads, multi-connection segments, resume (`Range`),
  retry with backoff (2s, 6s, 15s), search and status filter.
- **Background**: foreground service, Wi-Fi-only mode, daily download schedule
  (time window, wraps midnight).
- **Network**: DNS-over-HTTPS with fallback, per-site cookies, proxy and
  WireGuard VPN.
- **UI**: Material You theme (light/dark/system, optional dynamic color),
  English and Indonesian.

## Supported sites

Extractors live in [`lib/extractors/`](lib/extractors/). The in-app
"Supported sites" screen and the website show the same list.

| Family | Sites |
|---|---|
| XVideos | XVideos, XNXX |
| Media definitions | Pornhub, RedTube, YouPorn, Tube8 |
| KVS | ThisVid, PornTrex, SunPorno, Rule34Video |
| Single-site | xHamster, TNAFlix, PornOne, Eporner, HQPorner, HentaiCity, WatchHentai |
| Photos and video | Mitaku (galleries and Byse-hosted videos) |

Other pages with direct video links may also work through the generic
extractor. A site that sits behind an anti-bot check or builds its player
entirely in JavaScript is not supported.

## Build and run

Requires the Flutter SDK.

```
flutter pub get
flutter run
```

Local mock site for emulator tests (the emulator reaches the host as
`10.0.2.2`):

```
node tool/mock_server.js
```

### Test

```
flutter test
flutter analyze
```

### Website

The landing page is a Vite app in [`site/`](site/), deployed to GitHub Pages by
`.github/workflows/pages.yml` when a push to `main` changes `site/`. Keep
[`site/src/sites.js`](site/src/sites.js) in sync with
[`lib/sites.dart`](lib/sites.dart) when adding a site.

## Release signing

Release APKs are signed with a private keystore, not the debug key.

- Local: `android/key.properties` (gitignored) points at the keystore:
  `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Without it the
  release build falls back to the debug key and prints a warning.
- Back up the keystore and its passwords somewhere safe. Losing it means
  installed apps can never be updated in place.
- CI (`.github/workflows/release.yml`, runs on `v*` tags) needs repo secrets
  `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
  It builds per-ABI APKs, writes a `.sha256` file for each and publishes them.
- Release flow: bump `version` in `pubspec.yaml`, commit, `git tag vX.Y.Z`,
  `git push --tags`.
- Signer SHA-256: `f64afe1736604fdc42f4a12c0f6fd66df10b0c73375f98737b286df66b9f2923`
  (`apksigner verify --print-certs <apk>`).
