# Build & release

> Producing Android builds, signing and publishing on Google Play.
> Status: Draft · Last updated: 2026-10-16

## Local setup

| Tool | Notes |
|------|-------|
| Godot 4.7.2 | Editor + matching **export templates** |
| JDK 17 | Required by the Android build tools |
| Android SDK | Platform-tools, build-tools, platform matching Godot's target API; set path in *Editor Settings → Export → Android* |
| Debug keystore | Generated once per machine (`keytool`) for debug builds |

Follow the official guide: *Exporting for Android* in the Godot docs for the pinned version.

## Export presets

| Preset | Output | Use |
|--------|--------|-----|
| `Android Debug` | `build/nothung-debug.apk` | Install on device for testing (one-click deploy from the editor) |
| `Android Release` | `build/nothung-release.aab` (Gradle build) | Google Play upload |

- Both presets live in `game/export_presets.cfg` and share every option except the output format. `build/` (repo root) is git-ignored.
- Both exclude `tests/*`, `addons/gdUnit4/*` and `reports/*`: test code never ships.
- `Android Release` uses the Gradle build: install the Android build template once (*Project → Install Android Build Template*, creates `game/android/`) before the first release export.
- **Close the Godot editor before editing `export_presets.cfg` by hand**: the editor keeps the presets in memory and rewrites the file when it saves, which silently reverts manual changes.
- Command line: `godot --headless --path game --export-debug "Android Debug" ../build/nothung-debug.apk`.

- App name (`application/config/name` and Android launcher label): **Nothung** — the launcher has little room; the store listing uses the full *Nothung: The Ring Card Game*.
- Launcher icons (`launcher_icons/*`): `res://assets/app_icon/` — `icon_192.png` (legacy), `icon_foreground_432.png`, `icon_background_432.png`, `icon_monochrome_432.png` (adaptive). The PNGs are exported from the SVG sources next to them with Inkscape (`inkscape icon_foreground.svg -w 432 -o icon_foreground_432.png`); re-export after any SVG change. `icon.svg` is also the project icon (`application/config/icon`).
- Package name: **`io.github.tuntematonsotilas.nothung`**. **It can never change once published on Google Play.**
- Architectures: `arm64-v8a` (required); `armeabi-v7a` optional for old devices.
- Permissions: none beyond defaults (no Internet needed — disable `INTERNET` in release if possible).
- Target SDK: as required by Google Play at release time.

> **Decision (2026-10-15):** Publisher identifier = developer name → package `io.github.tuntematonsotilas.nothung` (no domain to own or renew).

## Signing & secrets

- The **release keystore is never committed**. `export_presets.cfg` must not contain passwords.
- Locally: use `.godot/export_credentials.cfg` (Godot 4 stores credentials there, ignored by git) or environment variables.
- Use **Play App Signing** (Google holds the app signing key; we keep the upload key) — losing the upload key is recoverable.

## Versioning

- `version/name`: semantic version `MAJOR.MINOR.PATCH` (e.g. `0.3.0`).
- `version/code`: integer, strictly increasing at every Play upload (bumped in both presets before each upload).
- Git tag `vX.Y.Z` per release; changelog in `CHANGELOG.md`.

## Checks before committing

> **Decision (2026-10-16):** No CI server. Checks run **locally**, before each commit: the gdUnit4 suite ([testing](09-testing.md#running-headless)), then lint and card regeneration once they exist (milestone 2). Builds are exported from the editor or the command line.

## Release tracks

Internal testing → Closed testing (friends/playtesters) → Open testing → Production.

## Store requirements checklist

- [x] App icon (adaptive)
- [ ] Feature graphic, screenshots (phone), 512 × 512 store icon (export `icon.svg`)
- [ ] Short / full description and screenshots (EN, DE, ES, FR)
- [ ] Privacy policy URL (even with no data collection)
- [ ] Data safety form (no data collected)
- [ ] Content rating questionnaire (target PEGI 12)
- [ ] Asset licences verified ([functional/08-art-and-audio.md](../functional/08-art-and-audio.md#asset-rights-checklist))
