# bulk_dl

Android app (Flutter) that bulk-downloads videos: playlists, single video pages
and direct file links, with a queue, background service, retry and resume.

Docs: [PRD](docs/PRD.md) · [Style](docs/STYLE.md) · [Tasks](docs/TASKS.md)

## Features

- Sources: Eporner, XVideos/XNXX, Pornhub family, xHamster, HQPorner,
  SunPorno, Rule34Video, HentaiCity, WatchHentai and more (see the in-app
  "Supported sites" list), Mitaku (photo galleries and Byse-hosted videos), direct
  files, HLS (`.m3u8`, AES-128) and generic pages (og:video, `<video>`,
  JSON-LD, media links). Multi-URL input and share-sheet intake.
- Queue: parallel downloads, multi-connection segments, resume (`Range`),
  retry with backoff (2s, 6s, 15s), search and status filter.
- Background: foreground service, Wi-Fi-only mode, daily download schedule
  (time window, wraps midnight).
- Network: DNS-over-HTTPS with fallback, per-site cookies, proxy and
  WireGuard VPN.
- UI: Material You theme (light/dark/system, optional dynamic color),
  English and Indonesian.
- In-app update check with SHA-256 shown in the update dialog.

## Run

```
flutter pub get
flutter run
```

Local mock site for emulator tests (emulator reaches host as `10.0.2.2`):

```
node tool/mock_server.js
```

## Test

```
flutter test
flutter analyze
```

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
