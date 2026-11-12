# Configuration Guide

Complete reference for configuring your YUP application template.

## Required Customization

Before building, you **must** change these values in `CMakeLists.txt`:

### Basic Identity

```cmake
set(PROJECT_NAME "YupApp")              # Change to your app name (no spaces)
set(PRODUCT_NAME "YUP Application")     # Display name (spaces OK)
set(COMPANY_NAME "Your Company Name")   # Your company/author name
set(BUNDLE_ID "com.yourcompany.yupapp") # Reverse domain (must be unique)
```

### Version Management

Edit the `VERSION` file in the root directory:
```
1.0.0
```

Format: `MAJOR.MINOR.PATCH` (semantic versioning)

## Build Options

### CMake Cache Variables

Pass these to cmake with `-D` flag:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `TARGET_VERSION` | String | From VERSION file | Override version |
| `BUILD_TESTS` | Bool | ON | Build test suite |
| `ENABLE_COVERAGE` | Bool | OFF | Enable code coverage analysis |
| `ENABLE_CODE_SIGNING` | Bool | OFF | Enable platform code signing |
| `ENABLE_PACKAGING` | Bool | OFF | Enable installer generation |
| `ENABLE_NOTARIZATION` | Bool | OFF | Enable macOS notarization |
| `MACOS_SIGNING_IDENTITY` | String | "" | macOS signing identity name |
| `IOS_SIGNING_IDENTITY` | String | "iPhone Developer" | iOS signing identity |
| `DEVELOPMENT_TEAM_ID` | String | "" | Apple Developer Team ID |
| `INSTALLER_NAME` | String | PRODUCT_NAME | Name for installers |
| `PACKAGE_VENDOR` | String | COMPANY_NAME | Vendor name in packages |

### Example Commands

**Development build:**
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

**Release build with tests:**
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
cd build && ctest --output-on-failure
```

**Production build with signing (macOS):**
```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_CODE_SIGNING=ON \
  -DMACOS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  -DDEVELOPMENT_TEAM_ID="TEAMID"
cmake --build build --config Release
```

**Full production build with packaging:**
```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_CODE_SIGNING=ON \
  -DENABLE_PACKAGING=ON \
  -DMACOS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  -DDEVELOPMENT_TEAM_ID="TEAMID"
cmake --build build --config Release
cd build && cpack
```

## Code Signing Details

### macOS

**Finding Your Signing Identity:**
```bash
security find-identity -v -p codesigning
```

Look for entries like:
```
1) ABCD1234... "Developer ID Application: Your Name (TEAMID)"
2) EFGH5678... "Apple Development: your.email@example.com (TEAMID)"
```

**Signing Identities:**
- **Developer ID Application**: For distribution outside the Mac App Store
- **Apple Development**: For development and testing
- **Mac App Store**: For Mac App Store distribution

**Hardened Runtime:**
When `ENABLE_NOTARIZATION=ON`, hardened runtime is automatically enabled.

### iOS

**Configuration:**
```cmake
# In CMakeLists.txt, these are set automatically when ENABLE_CODE_SIGNING=ON
set(IOS_SIGNING_IDENTITY "iPhone Developer")
set(DEVELOPMENT_TEAM_ID "YOUR_TEAM_ID")
```

**Finding Your Team ID:**
```bash
# List provisioning profiles
security find-identity -v -p codesigning | grep iPhone
```

Or check your Apple Developer account at https://developer.apple.com/account

### Windows

Windows code signing requires:
- Code signing certificate (.pfx or .p12 file)
- Certificate password

Configure via `signtool` in post-build steps or CI/CD.

## Notarization (macOS)

Notarization is required for Gatekeeper on macOS 10.15+.

### Prerequisites

1. Code signing with "Developer ID Application" certificate
2. Apple ID with app-specific password
3. Xcode command-line tools installed

### Setup Notarization Profile

```bash
# Store credentials in keychain
xcrun notarytool store-credentials "notary" \
  --apple-id "your.email@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

### Notarize Your App

```bash
# 1. Build with hardened runtime
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_CODE_SIGNING=ON \
  -DENABLE_NOTARIZATION=ON \
  -DMACOS_SIGNING_IDENTITY="Developer ID Application: ..."

cmake --build build --config Release

# 2. Create distributable (DMG or ZIP)
cd build
cpack  # Creates DMG

# 3. Submit for notarization
xcrun notarytool submit YupApp.dmg --keychain-profile "notary" --wait

# 4. Staple the ticket
xcrun stapler staple YupApp.dmg

# 5. Verify
xcrun stapler validate YupApp.dmg
spctl -a -vv -t install YupApp.dmg
```

## Packaging & Installers

### Windows (NSIS)

Creates a Windows installer (.exe):

```bash
cmake -B build -DENABLE_PACKAGING=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
cd build && cpack -G NSIS
```

**Customization:**
- Edit `packaging/installer.iss` for Inno Setup
- Customize CPACK_NSIS_* variables in CMakeLists.txt

### macOS (DMG)

Creates a disk image (.dmg):

```bash
cmake -B build -DENABLE_PACKAGING=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
cd build && cpack -G DragNDrop
```

**Customization:**
- Add `packaging/dmg.json` for window layout
- Add `packaging/dmg_background.png` for custom background
- Customize CPACK_DMG_* variables in CMakeLists.txt

### Linux (DEB/RPM)

Creates Linux packages:

```bash
cmake -B build -DENABLE_PACKAGING=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Create all formats
cd build && cpack

# Or specific format
cd build && cpack -G DEB  # Debian/Ubuntu
cd build && cpack -G RPM  # Fedora/RHEL
```

## YUP Modules

Available YUP modules you can add to your application:

```cmake
MODULES
    yup::yup_core       # Core utilities and base classes
    yup::yup_events     # Event handling system
    yup::yup_graphics   # Graphics rendering
    yup::yup_gui        # GUI components and widgets
    # Optional modules:
    # yup::yup_audio    # Audio processing
    # yup::yup_network  # Network communication
```

## Testing

Tests are built by default. To disable:

```bash
cmake -B build -DBUILD_TESTS=OFF
```

Run tests:
```bash
cd build && ctest --output-on-failure
```

Or run the test executable directly:
```bash
./build/tests/template_tests
```

## Code Coverage

Code coverage analysis helps identify which parts of your code are exercised by tests and which are not.

### Prerequisites

**Linux:**
```bash
sudo apt-get install lcov
```

**macOS:**
```bash
brew install lcov
```

**Requirements:**
- GCC or Clang compiler
- lcov (for coverage report generation)
- Debug build (optimizations can affect coverage accuracy)

### Basic Usage

Enable coverage and build tests:
```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Debug \
  -DENABLE_COVERAGE=ON

cmake --build build --config Debug
```

Run tests to collect coverage data:
```bash
cd build
ctest --output-on-failure
```

Generate coverage report:
```bash
make coverage
```

This creates `build/coverage/coverage_final.info` with coverage data.

### HTML Coverage Report

Generate a browsable HTML report:
```bash
make coverage_html
```

Open the report:
```bash
# Linux
xdg-open build/coverage/html/index.html

# macOS
open build/coverage/html/index.html
```

The HTML report shows:
- Overall coverage percentage
- Per-file coverage breakdown
- Line-by-line coverage highlighting
- Uncovered code paths

### Coverage Targets

The build system provides several coverage targets:

| Target | Description |
|--------|-------------|
| `coverage_clean` | Clean coverage data |
| `coverage` | Generate coverage report (lcov) |
| `coverage_html` | Generate HTML coverage report |

### Workflow Example

```bash
# 1. Configure with coverage
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON

# 2. Build tests
cmake --build build --config Debug

# 3. Clean previous coverage data
cd build && make coverage_clean

# 4. Run tests
ctest --output-on-failure

# 5. Generate coverage report
make coverage

# 6. View results in terminal
# (automatically displayed after make coverage)

# 7. Generate HTML report for detailed view
make coverage_html
open coverage/html/index.html
```

### Understanding Coverage Metrics

**Line Coverage**: Percentage of code lines executed during tests
- **Good**: 70-80%+
- **Excellent**: 85%+

**Coverage ≠ Quality**: High coverage doesn't guarantee bug-free code, but low coverage indicates untested code paths.

### CI/CD Integration

The template includes a GitHub Actions workflow (`.github/workflows/coverage.yml`) that:
1. Runs tests with coverage enabled
2. Generates coverage reports
3. Uploads reports to Codecov
4. Comments on pull requests with coverage changes

**Setup Codecov:**
1. Sign up at https://codecov.io
2. Connect your GitHub repository
3. Add `CODECOV_TOKEN` secret to your repository:
   - Go to Settings → Secrets and variables → Actions
   - Add new secret: `CODECOV_TOKEN` with value from Codecov

**Coverage Badge:**
Add to your README.md:
```markdown
[![codecov](https://codecov.io/gh/username/repo/branch/main/graph/badge.svg)](https://codecov.io/gh/username/repo)
```

### Configuration

Coverage settings are in `codecov.yml`:
- Target coverage: 60% (configurable)
- Ignore patterns: tests, build files, dependencies
- Component tracking: Application source code

Adjust targets based on your project:
```yaml
coverage:
  status:
    project:
      default:
        target: 80%  # Change this
        threshold: 5%
```

### Troubleshooting

**"lcov not found":**
```bash
# Install lcov
sudo apt-get install lcov  # Linux
brew install lcov          # macOS
```

**No coverage data generated:**
- Ensure `-DENABLE_COVERAGE=ON` was used during configuration
- Use Debug build (`-DCMAKE_BUILD_TYPE=Debug`)
- Run tests before generating reports
- Check that tests actually execute your code

**Coverage shows 0% for all files:**
- Verify GCC/Clang is being used (not MSVC)
- Check `.gcda` files exist in build directory after running tests
- Ensure tests are actually running (check ctest output)

**Permission errors:**
```bash
# Clean build directory
rm -rf build
# Reconfigure from scratch
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON
```

## CI/CD

GitHub Actions workflows are ready to use. Configure secrets:

### macOS Signing Secrets
- `MACOS_CERTIFICATE` - Base64 encoded certificate
- `MACOS_CERTIFICATE_PWD` - Certificate password
- `APPLE_ID` - Apple ID email
- `APPLE_PASSWORD` - App-specific password
- `TEAM_ID` - Developer Team ID

### Windows Signing Secrets
- `WINDOWS_CERTIFICATE` - Base64 encoded PFX
- `WINDOWS_CERTIFICATE_PWD` - Certificate password

## Platform-Specific Deployment Targets

Configured in CMakeLists.txt:
- **iOS**: 11.0+
- **macOS**: 12.0+
- **Windows**: Windows 10+
- **Linux**: Ubuntu 20.04+ (or equivalent)

Adjust `CMAKE_OSX_DEPLOYMENT_TARGET` and platform-specific settings as needed.

## Troubleshooting

### Code Signing Issues

**macOS "identity not found":**
```bash
# Verify certificate is in keychain
security find-identity -v -p codesigning
# Import if needed
security import certificate.p12 -k ~/Library/Keychains/login.keychain-db
```

**iOS provisioning profile errors:**
- Ensure DEVELOPMENT_TEAM_ID matches your Apple Developer account
- Check Xcode is properly signed in with your Apple ID

### Notarization Issues

**"Invalid Developer ID":**
- Use "Developer ID Application" certificate, not "Apple Development"
- Certificate must be issued by Apple Developer Relations

**"The binary is not signed with a valid Developer ID":**
- Ensure ENABLE_CODE_SIGNING=ON before building
- Verify code signature: `codesign -dv --verbose=4 YourApp.app`

### Build Issues

**"YUP not found":**
- Check internet connection (YUP is fetched from GitHub)
- Verify GIT_TAG in FetchContent_Declare points to valid branch/tag

## Resources

- [YUP Framework](https://github.com/kunitoki/yup)
- [CMake Documentation](https://cmake.org/documentation/)
- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
