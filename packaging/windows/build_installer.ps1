# =============================================================================
#  Build the Windows installer with Inno Setup (ISCC).
#
#  Reads the version from the VERSION file and the product naming from the
#  values below (keep them in sync with CMakeLists.txt), locates the built
#  artifacts in the CMake build tree, stages them into a clean layout and then
#  invokes ISCC against that staging directory.
#
#  Staging (rather than pointing Inno straight at the build tree) keeps the
#  .iss simple and makes a missing artifact a loud error instead of a silently
#  empty installer. It mirrors the Linux/macOS packaging scripts.
#
#  Usage:
#    pwsh packaging/windows/build_installer.ps1 [-Config Release] [-BuildDir ..\..\build]
#
#  Requires Inno Setup 6+ (iscc.exe on PATH, or set -Iscc).
# =============================================================================
[CmdletBinding()]
param(
    [string]$Config   = "Release",
    [string]$BuildDir = "",
    [string]$Iscc     = "iscc"
)

$ErrorActionPreference = "Stop"

$Here        = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $Here "..\..")).Path

if ([string]::IsNullOrEmpty($BuildDir)) {
    $BuildDir = Join-Path $ProjectRoot "build"
}

# Keep these in sync with CMakeLists.txt.
$ProjectName = "YupPlugin"
$ProductName = "YUP Instrument"
$Company     = "YUP Audio"
$Url         = "https://github.com/kunitoki/yup-plugin-template"

$Version = (Get-Content (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
$DistDir = Join-Path $ProjectRoot "dist"
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# -----------------------------------------------------------------------------
# Locate built artifacts in the build tree, skipping third-party bundles under
# externals/ and _deps/ and preferring the requested configuration directory.
# -----------------------------------------------------------------------------
function Find-Artifact([string]$Pattern) {
    Get-ChildItem -Path $BuildDir -Recurse -Force -Filter $Pattern -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/](externals|_deps)[\\/]' -and
            $_.FullName -match "[\\/]$([regex]::Escape($Config))[\\/]"
        } |
        Select-Object -First 1
}

$Stage = Join-Path $DistDir "win-stage"
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

$defines = @()
$staged  = @()

function Stage-Artifact([string]$Pattern, [string]$SubDir, [string]$Define, [string]$DestName = "") {
    $item = Find-Artifact $Pattern
    if ($null -eq $item) {
        Write-Host "warning: no artifact matching '$Pattern' for $Config; skipping."
        return
    }
    $destRoot = Join-Path $Stage $SubDir
    New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
    $target = if ($DestName) { Join-Path $destRoot $DestName } else { Join-Path $destRoot $item.Name }
    if ($item.PSIsContainer) {
        Copy-Item -Recurse -Force $item.FullName $target
    } else {
        Copy-Item -Force $item.FullName $target
    }
    Write-Host "==> Staged $($item.Name) -> $SubDir"
    $script:defines += "/D$Define=1"
    $script:staged  += $SubDir
}

# VST3 on Windows (SMTG default) is a single "<name>.vst3" DLL; with a bundle it
# would be a directory. Copy-Item handles either form.
Stage-Artifact "*_vst3_plugin.vst3" "VST3"       "HaveVst3"
Stage-Artifact "*_clap_plugin.clap" "CLAP"       "HaveClap"
Stage-Artifact "*_lv2_plugin.lv2"   "LV2"        "HaveLv2"
Stage-Artifact "$ProductName.exe"   "Standalone" "HaveStandalone" "$ProductName.exe"

if ($staged.Count -eq 0) {
    throw "No artifacts found under '$BuildDir' for config '$Config'. Build the plugin first (e.g. 'just build')."
}

$Iss = Join-Path $Here "installer.iss"

Write-Host "==> Building Windows installer $ProductName $Version ($Config)"

$isccArgs = @(
    "/DMyAppName=$ProductName",
    "/DMyAppProject=$ProjectName",
    "/DMyAppVersion=$Version",
    "/DMyCompany=$Company",
    "/DMyAppURL=$Url",
    "/DStageDir=$Stage",
    "/DOutputDir=$DistDir",
    "/DIconFile=$(Join-Path $ProjectRoot 'assets\app-icon.ico')"
) + $defines + @($Iss)

& $Iscc @isccArgs

if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

Write-Host "==> Installer written to $DistDir"
