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

### Signing & notarization

The default build is **unsigned** — every signing step is skipped unless you provide credentials, so
the template builds out of the box. Provide the values below to opt in.

#### macOS

`packaging/macos/build_pkg.sh` reads these environment variables:

| Variable | Purpose |
|----------|---------|
| `APPLICATION_SIGNING_IDENTITY` | `Developer ID Application: ...` — codesigns the plugin/app bundles with the hardened runtime. |
| `INSTALLER_SIGNING_IDENTITY` | `Developer ID Installer: ...` — signs the `.pkg`. Required before notarization. |
| `NOTARY_KEYCHAIN_PROFILE` | A stored `notarytool` keychain profile, **or**… |
| `NOTARY_APPLE_ID` / `NOTARY_TEAM_ID` / `NOTARY_PASSWORD` | …an Apple ID + Team ID + app-specific password triple. |

Notarization (`xcrun notarytool submit --wait` + `xcrun stapler staple`) runs only when the installer
is signed **and** notarization credentials are present.

In CI (`.github/workflows/build_macos.yml`) set these repository secrets to enable signing:
`APPLE_DEVELOPER_ID_CERT_P12` (base64 of the exported `.p12`), `APPLE_DEVELOPER_ID_CERT_PASSWORD`,
`APPLE_APPLICATION_IDENTITY`, `APPLE_INSTALLER_IDENTITY`, and for notarization
`APPLE_NOTARY_APPLE_ID`, `APPLE_NOTARY_TEAM_ID`, `APPLE_NOTARY_PASSWORD`.

#### Windows

Generate your own `AppId` GUID in `windows/installer.iss` for a real product. CI
(`.github/workflows/build_windows.yml`) signs the installer with
[Azure Trusted Signing](https://learn.microsoft.com/azure/trusted-signing/) when these repository
secrets are set: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
`AZURE_SIGNING_ENDPOINT`, `AZURE_SIGNING_ACCOUNT`, `AZURE_SIGNING_CERT_PROFILE`. To sign locally
instead, use `signtool` against `dist/*.exe`.
