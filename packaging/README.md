# Packaging

Scripts that collect the built plugin artifacts into native installers. Build the plugin first
(`just build` or `cmake --build build --config Release --target YupPlugin`), then run the packaging
recipe for your platform. All installers are written to the top-level `dist/` directory.

```
packaging/
├── common.sh                 # Shared config + artifact discovery (sourced by the *.sh scripts)
├── icons/generate_icons.sh   # Generate app-icon.icns / app-icon.ico from assets/app-icon.png
├── macos/build_pkg.sh        # Build a macOS .pkg installer
├── linux/build_archive.sh    # Build a Linux .tar.gz
├── linux/build_deb.sh        # Build a Debian .deb package
├── linux/app.desktop.in      # Desktop entry template for the standalone app
└── windows/
    ├── installer.iss         # Inno Setup script
    └── build_installer.ps1   # Helper that invokes ISCC with the right defines
```

## Usage

```bash
just icons               # regenerate the platform icons (optional)
just package             # build the installer for the current OS
just package Debug       # ...from a specific build configuration
```

Or call the scripts directly (they accept `[CONFIG] [BUILD_DIR]` and honour the overrides below):

```bash
packaging/macos/build_pkg.sh Release
packaging/linux/build_archive.sh Release
packaging/linux/build_deb.sh Release
pwsh packaging/windows/build_installer.ps1 -Config Release
```

## Install locations

| Format | macOS | Linux | Windows |
|--------|-------|-------|---------|
| VST3 | `/Library/Audio/Plug-Ins/VST3` | `/usr/lib/vst3` | `%CommonProgramFiles%\VST3` |
| CLAP | `/Library/Audio/Plug-Ins/CLAP` | `/usr/lib/clap` | `%CommonProgramFiles%\CLAP` |
| AU   | `/Library/Audio/Plug-Ins/Components` | — | — |
| LV2  | `/Library/Audio/Plug-Ins/LV2` | `/usr/lib/lv2` | `%CommonProgramFiles%\LV2` |
| Standalone | `/Applications` | `/usr/bin` (+ `.desktop`) | `%ProgramFiles%\<Company>\<Product>` |

The scripts glob the build tree by file extension, so only the formats you actually built are
included. Missing formats are skipped with a warning.

## Requirements

- **macOS**: `pkgbuild` / `productbuild` (Xcode command line tools). `sips` + `iconutil` for icons.
- **Linux**: `dpkg-deb` for `.deb`. `tar` for the archive.
- **Windows**: [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`ISCC.exe`). ImageMagick to
  regenerate the `.ico`.

## Customisation & overrides

Product naming defaults mirror `CMakeLists.txt` (`PROJECT_NAME`, `PRODUCT_NAME`, `COMPANY_NAME`,
`BUNDLE_ID`). Override any value, plus the build/output locations, via environment variables:

```bash
PRODUCT_NAME="My Synth" BUILD_DIR=/path/to/build DIST_DIR=/tmp/out \
  packaging/macos/build_pkg.sh Release
```

### Signing

- **macOS**: set `INSTALLER_SIGNING_IDENTITY` to a `Developer ID Installer: ...` identity to sign the
  `.pkg`. (Sign the plugin bundles themselves via `ENABLE_CODE_SIGNING` at build time.)
- **Windows**: generate your own `AppId` GUID in `windows/installer.iss` for a real product, and sign
  the resulting installer with `signtool`.
