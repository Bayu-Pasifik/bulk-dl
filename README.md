# bulk_dl

Android app (Flutter) that bulk-downloads videos: playlists, single video pages
and direct file links, with a queue, background service, retry and resume.

Docs: [PRD](docs/PRD.md) · [Style](docs/STYLE.md) · [Tasks](docs/TASKS.md)

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
