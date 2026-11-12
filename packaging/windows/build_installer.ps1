# =============================================================================
#  Build the Windows installer with Inno Setup (ISCC).
#
#  Reads the version from the VERSION file and the product naming from the
#  values below (keep them in sync with CMakeLists.txt), then invokes ISCC.
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

$Iss = Join-Path $Here "installer.iss"

Write-Host "==> Building Windows installer $ProductName $Version ($Config)"

& $Iscc `
    "/DMyAppName=$ProductName" `
    "/DMyAppProject=$ProjectName" `
    "/DMyAppVersion=$Version" `
    "/DMyCompany=$Company" `
    "/DMyAppURL=$Url" `
    "/DBuildDir=$BuildDir" `
    "/DConfig=$Config" `
    "/DOutputDir=$DistDir" `
    "/DIconFile=$(Join-Path $ProjectRoot 'assets\app-icon.ico')" `
    $Iss

if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

Write-Host "==> Installer written to $DistDir"
