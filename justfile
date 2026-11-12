alias c := clean

gtest_filter := "*"

[doc("list available recipes")]
default:
  @just --list

[confirm("Are you sure you want to clean the build folder? [y/N]")]
[doc("clean project build artifacts")]
clean:
  rm -Rf build/*

[doc("generate and open project using Ninja multi config")]
ninja PROFILING="OFF":
  cmake -G "Ninja Multi-Config" -B build -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON

[doc("generate and open project in macOS using Xcode")]
mac PROFILING="OFF":
  cmake -G Xcode -B build -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON
  -open build/YupPlugin.xcodeproj

[doc("generate and open project in Windows using Visual Studio")]
win PROFILING="OFF":
  cmake -G "Visual Studio 18 2026" -B build -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON
  -start build/YupPlugin.slnx

[doc("generate project in Linux using Ninja")]
linux PROFILING="OFF":
  @just ninja {{PROFILING}}

[doc("generate and open project for iOS using Xcode")]
[macos]
ios PLATFORM="OS64":
  cmake -G Xcode -B build -DCMAKE_TOOLCHAIN_FILE=yup/cmake/toolchains/ios.cmake -DPLATFORM={{PLATFORM}}
  -open build/YupPlugin.xcodeproj

[doc("generate and open project for iOS Simulator macOS using Xcode")]
[macos]
ios_simulator PLATFORM="SIMULATORARM64":
  @just ios {{PLATFORM}}

[doc("generate and open project for Android using Android Studio (macos)")]
[macos]
android:
  cmake -G Xcode -B build -DYUP_TARGET_ANDROID=ON
  -open -a /Applications/Android\ Studio.app build/YupPlugin

[doc("generate and open project for Android using Android Studio (windows)")]
[windows]
android:
  cmake -G "Visual Studio 18 2026" -B build -DYUP_TARGET_ANDROID=ON
  -start "C:\\Program Files\\Android\\Android Studio\\bin\\studio64.exe" build\\YupPlugin

[doc("generate and open project for Android using Android Studio (linux)")]
[linux]
android:
  cmake -G "Unix Makefiles" -B build -DYUP_TARGET_ANDROID=ON

[doc("generate and build project for WASM")]
emscripten CONFIG="Debug":
  emcc -v
  emcmake cmake -G "Ninja Multi-Config" -B build
  cmake --build build --config {{CONFIG}}

[doc("run tests for WASM")]
emscripten_test CONFIG="Debug":
  @just emscripten {{CONFIG}}
  cd build/tests/{{CONFIG}} && node YupPlugin_tests.js --gtest_filter={{gtest_filter}}

[doc("serve project for WASM")]
emscripten_serve:
  python3 -m http.server -d .

# =============================================================================
# BUILD / TEST / PACKAGE
# =============================================================================

[doc("build the plugin (all enabled formats)")]
build CONFIG="Release":
  cmake --build build --config {{CONFIG}} --target YupPlugin

[doc("build and run the test suite")]
test CONFIG="Debug":
  cmake --build build --config {{CONFIG}} --target YupPlugin_tests
  ctest --test-dir build/tests -C {{CONFIG}} --output-on-failure

[doc("build and run the DSP micro-benchmarks (google/benchmark)")]
bench CONFIG="Release":
  cmake -G "Ninja Multi-Config" -B build -DBUILD_BENCHMARKS=ON
  cmake --build build --config {{CONFIG}} --target YupPlugin_benchmarks
  ./build/benchmarks/{{CONFIG}}/YupPlugin_benchmarks

[doc("generate platform icons (.icns/.ico) from assets/app-icon.png")]
icons:
  ./packaging/icons/generate_icons.sh

[doc("build a macOS installer package (.pkg)")]
[macos]
package CONFIG="Release":
  ./packaging/macos/build_pkg.sh {{CONFIG}}

[doc("build a Linux tarball and Debian package")]
[linux]
package CONFIG="Release":
  ./packaging/linux/build_archive.sh {{CONFIG}}
  ./packaging/linux/build_deb.sh {{CONFIG}}

[doc("build a Windows installer (requires Inno Setup)")]
[windows]
package CONFIG="Release":
  pwsh packaging/windows/build_installer.ps1 -Config {{CONFIG}}

[doc("archive the Emscripten WASM standalone build (.tar.gz)")]
package-wasm CONFIG="Release":
  ./packaging/wasm/build_archive.sh {{CONFIG}}

# =============================================================================
# TEMPLATE / DEVELOPER TOOLING
# =============================================================================

[doc("rename the template for your own plugin (interactive)")]
bootstrap:
  ./scripts/bootstrap.sh

[doc("format all source files with clang-format")]
format:
  find source tests -type f \( -name '*.h' -o -name '*.cpp' \) -print0 | xargs -0 clang-format -i

[doc("check source formatting without modifying files")]
format-check:
  find source tests -type f \( -name '*.h' -o -name '*.cpp' \) -print0 | xargs -0 clang-format --dry-run --Werror

