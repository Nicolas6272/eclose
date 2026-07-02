# AGENTS.md

## Cursor Cloud specific instructions

Éclose is a **Flutter (Dart) mobile app** — a French plant-watering reminder app. It is
fully **offline/local**: no backend, no database server, no auth, and no payments are
wired up (the README's Firebase/Firestore/RevenueCat/SQLite stack is aspirational vision,
not the current code). Persistence uses `shared_preferences` (local key/value), and the
plant catalog is bundled as static assets. The only external dependency is the optional,
build-time `scripts/fetch_perenual_photos.py` used to regenerate the catalog (needs
`PERENUAL_API_KEY`); it is not needed to run or test the app.

### Toolchain

- The Flutter SDK (stable, Dart >= 3.12.2 as required by `pubspec.yaml`) is installed at
  `$HOME/flutter` and added to `PATH` via `~/.bashrc`. Interactive shells pick it up
  automatically; in non-interactive contexts invoke it as `$HOME/flutter/bin/flutter`.
- Android and Linux-desktop toolchains are **not** installed (no Android SDK, no
  ninja/GTK). Only the **web** target (Chrome, already present) is available for running
  the app in this VM. `flutter doctor` will report those toolchains as missing — this is
  expected, not a setup failure.

### Run / lint / test / build

Standard Flutter commands (see `pubspec.yaml`):

- Install deps: `flutter pub get`
- Lint/analyze: `flutter analyze` (config in `analysis_options.yaml`). Currently reports a
  few `info`-level hints only, no errors.
- Tests: `flutter test` — there is **no `test/` directory**, so this currently reports
  "Test directory not found". That is expected until tests are added.
- Run in dev mode (web): `flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0`
  then open `http://localhost:8080`. Use `-d web-server` (not `-d chrome`) since this is a
  headless VM; access the served URL via the Desktop/browser.
- Build (web): `flutter build web`.

### Gotchas

- First `flutter run`/build on web takes ~30–60s to compile; a blank white page during
  that time is normal — wait for it to render.
- Screen recordings of the web app in this VM can capture a zoomed/cropped viewport that
  makes the UI look broken even though it renders correctly. Prefer full-resolution
  screenshots as evidence when the recording looks off.
- The `git clone` used to install Flutter embedded an auth token in the SDK's git remote,
  so `flutter doctor` prints a non-standard-remote warning about `FLUTTER_GIT_URL`. It is
  harmless.
