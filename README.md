# YUP Plugin Template

A cross-platform **audio plugin** template built with the [YUP](https://github.com/kunitoki/yup)
framework. It ships as a small polyphonic instrument you can rename and extend, and builds to every
major plugin format plus a standalone application from a single source tree.

> Formats: **CLAP · VST3 · AU · AUv3 · LV2 · AAX · Standalone** — targeting macOS, Windows, Linux,
> iOS, Android and WebAssembly.

> [!TIP]
> This is a **template repository**. Click **Use this template** on GitHub to create your own plugin
> repository from it — see [Getting started](#getting-started).

---

## What's inside

The template is a complete, working synthesizer so you have something that makes sound on day one:

- **`PluginProcessor`** — a polyphonic instrument with four automatable parameters (`Gain`,
  `Waveform`, `Attack`, `Release`), each exposed to the host with proper units and value strings.
- **`PluginEditor`** — a resizable UI (knobs + playable keyboard) that preserves its aspect ratio and
  scales cleanly at any size.
- **`source/dsp/SynthVoice.h`** — a header-only, standard-library-only oscillator + envelope engine,
  trivial to unit test and to replace with your own DSP.
- **Tests** — a GoogleTest suite wired into YUP's shared test runner (no vendored `main.cpp`).
- **Packaging** — ready-to-run installer scripts for macOS, Windows and Linux.
- **CI** — GitHub Actions for every platform, including build, test, coverage and packaging.

## Prerequisites

- **CMake** ≥ 3.31
- A C++20 toolchain:
  - macOS: Xcode (with command line tools)
  - Windows: Visual Studio 2022/2026
  - Linux: GCC/Clang + the audio/X11/GL dev packages (see `.github/workflows/build_linux.yml`)
- [`just`](https://github.com/casey/just) *(optional, for the convenience recipes below)*

## Getting started

This is a **GitHub template repository** — don't fork it. Click
**[Use this template](https://github.com/kunitoki/yup-plugin-template/generate)** → *Create a new
repository* to start your own plugin from it, then clone your new repository.

Because the project uses YUP as a git submodule, clone recursively:

```bash
git clone --recursive https://github.com/<you>/<your-plugin>.git
cd <your-plugin>
```

Already cloned without `--recursive`? Pull the submodule in:

```bash
git submodule update --init --recursive
```

## Building

Using `just` (recommended):

```bash
just mac         # generate + open an Xcode project (macOS)
just win         # generate + open a Visual Studio solution (Windows)
just linux       # generate a Ninja build (Linux)
just build       # build every enabled format in Release
just build Debug # ...or a specific configuration
```

Using CMake directly:

```bash
cmake -G "Ninja Multi-Config" -B build
cmake --build build --config Release --target YupPlugin
```

Built artifacts land under `build/<Config>/` (VST3 under `build/VST3/<Config>/`). On macOS the plugins
are also copied into your user plugin folders automatically after each build.

## Testing

```bash
just test            # build + run the test suite via CTest
just test Release    # ...in a specific configuration
```

Or directly:

```bash
cmake --build build --config Debug --target YupPlugin_tests
ctest --test-dir build/tests -C Debug --output-on-failure
```

For WebAssembly: `just emscripten_test`.

## Packaging

The `packaging/` directory contains scripts that collect the built artifacts into native installers.
Build the plugin first, then:

```bash
just icons      # (re)generate app-icon.icns / app-icon.ico from assets/app-icon.png
just package    # build the platform installer for the current OS
```

| Platform | Output | Requires |
|----------|--------|----------|
| macOS   | `.pkg` installer (plugins + standalone app)       | Xcode command line tools |
| Linux   | `.tar.gz` archive **and** `.deb` package          | `dpkg-deb` |
| Windows | `.exe` installer                                  | [Inno Setup 6](https://jrsoftware.org/isinfo.php) |

Installers are written to `dist/`. See [`packaging/README.md`](packaging/README.md) for details,
signing options and layout.

## Configuration

Edit the variables near the top of `CMakeLists.txt` to make the template your own:

| Variable | Description |
|----------|-------------|
| `PROJECT_NAME` | Internal target name (no spaces) |
| `PRODUCT_NAME` | User-facing product / standalone app name |
| `COMPANY_NAME` | Vendor / author name |
| `BUNDLE_ID` | Reverse-domain bundle identifier |
| `PLUGIN_CODE` / `PLUGIN_MANUFACTURER_CODE` | Four-character AU/AAX codes (stable once shipped) |
| `PLUGIN_DESCRIPTION` / `PLUGIN_URL` / `PLUGIN_EMAIL` | Plugin metadata |

The version lives in the `VERSION` file (`MAJOR.MINOR.PATCH`) and can be overridden with
`-DTARGET_VERSION=...`.

Toggle formats and features with CMake options, e.g. `-DPLUGIN_BUILD_VST3=OFF`:

`PLUGIN_BUILD_CLAP`, `PLUGIN_BUILD_VST3`, `PLUGIN_BUILD_AU`, `PLUGIN_BUILD_AUV3`, `PLUGIN_BUILD_LV2`,
`PLUGIN_BUILD_STANDALONE`, `BUILD_TESTS`, `ENABLE_COVERAGE`, `ENABLE_CODE_SIGNING`.

See [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) and [`docs/COVERAGE.md`](docs/COVERAGE.md) for
the full reference.

## Project layout

```
.
├── CMakeLists.txt          # Plugin configuration and the yup_audio_plugin() target
├── VERSION                 # Single source of truth for the version
├── assets/                 # Application icon (png/ico/icns)
├── source/                 # Plugin processor, editor and DSP
│   └── dsp/                # Header-only synth engine
├── tests/                  # GoogleTest suite
├── packaging/              # macOS / Windows / Linux installer scripts
├── docs/                   # Configuration and coverage guides
├── .github/workflows/      # Per-platform CI
└── yup/                    # YUP framework (git submodule)
```

## License

This template is distributed under the terms of the [LICENSE](LICENSE) file. YUP has its own license;
see the [YUP repository](https://github.com/kunitoki/yup).
