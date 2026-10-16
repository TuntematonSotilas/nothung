<p align="center">
  <img src="game/assets/app_icon/icon.svg" alt="Nothung icon: the sword Nothung through the Ring" width="160">
</p>

# Nothung: The Ring Card Game

A single-player collectible card game for Android, themed on Richard Wagner's *Der Ring des Nibelungen*. Built with Godot 4.7.2 and GDScript.

## Documentation

All design and technical documentation lives in [docs/](docs/README.md):

- [Functional documentation](docs/README.md#functional-documentation) — vision, lore, rules, cards, modes, UX
- [Technical documentation](docs/README.md#technical-documentation) — architecture, data model, engine, AI, build
- [Architecture Decision Records](docs/README.md#architecture-decision-records)
- [Roadmap](docs/roadmap.md) — milestones and progress

## Installation

### 1. Godot 4.7.2

Download **Godot 4.7.2 stable**, standard build (not the .NET one), from the [official archive](https://godotengine.org/download/archive/4.7.2-stable/). The version is pinned ([ADR-0001](docs/adr/0001-godot-gdscript-android.md)): don't use another one.

- Windows: keep the main exe under its original name, `Godot_v4.7.2-stable_win64.exe`, next to the `_console.exe` wrapper: the wrapper looks for that exact name. Command-line tools (tests, export) use the main exe.
- To build for Android, also install the matching **export templates** (*Editor → Manage Export Templates*), JDK 17 and the Android SDK: see [local setup](docs/technical/10-build-and-release.md#local-setup).

### 2. Clone and install the test framework

```sh
git clone https://github.com/TuntematonSotilas/nothung.git
cd nothung
bash tools/install_gdunit4.sh
```

The script installs [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) **v6.2.2** in `game/addons/gdUnit4/` (git-ignored). Run it **before opening the editor**: the plugin is enabled in the project and Godot reports it missing otherwise. It needs `bash`, `curl` and `tar` (on Windows: Git Bash).

### 3. Open the project

Open `game/project.godot` in Godot 4.7.2. The first import takes a moment.

### 4. Run the tests

In the editor, the gdUnit4 panel discovers the suites in `tests/` automatically a few seconds after opening the project. To refresh the list manually, click the circular-arrows button in the panel. Or run headless from `game/`:

```sh
export GODOT_BIN=/path/to/Godot_v4.7.2-stable   # main executable, not _console.exe
"$GODOT_BIN" --headless --path . --import
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
```

Details: [testing](docs/technical/09-testing.md#running-headless).

### 5. Play a duel

Run the project in Godot and press **Start Match** on the splash screen. The first playable build pairs the Gods starter deck (Wotan) against the Nibelungs starter deck (Alberich); select cards/targets by tapping and use **End Turn** to pass to the Easy AI.
