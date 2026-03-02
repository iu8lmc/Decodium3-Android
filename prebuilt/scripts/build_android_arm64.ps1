# ============================================================================
# build_android_arm64.ps1
# Windows wrapper: cross-compile wsjt_fort + FFTW3 for Android ARM64
#
# Strategies (tried in order):
#   1. WSL2 Ubuntu  - if Hyper-V enabled and Ubuntu available
#   2. Docker       - if Docker Desktop is running
#   3. Manual       - prints instructions for Linux/CI build
#
# Usage:
#   .\build_android_arm64.ps1 [-Strategy wsl|docker|auto] [-NdkPath C:\path\to\ndk]
# ============================================================================

param(
    [ValidateSet('auto', 'wsl', 'docker')]
    [string]$Strategy = 'auto',

    [string]$NdkPath = '',
    [switch]$SkipDeps,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceDir = (Resolve-Path (Join-Path $ScriptDir '..\..\')).Path
$OutputDir = Join-Path $SourceDir 'prebuilt\android-arm64-v8a'
$BashScript = 'prebuilt/scripts/build_android_arm64.sh'

function Write-Header {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " Decodium3 Android ARM64 Cross-Compilation" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " Source:   $SourceDir" -ForegroundColor Gray
    Write-Host " Output:   $OutputDir" -ForegroundColor Gray
    Write-Host " Strategy: $Strategy" -ForegroundColor Gray
    Write-Host ""
}

function Test-WSL {
    try {
        $result = wsl --list --verbose 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        # Check if Ubuntu is available and WSL2 is functional
        $distro = $result | Select-String -Pattern 'Ubuntu' -Quiet
        if (-not $distro) { return $false }

        # Quick test: can we actually execute something?
        $test = wsl -d Ubuntu-22.04 -- echo "OK" 2>&1
        return ($test -match "OK")
    } catch {
        return $false
    }
}

function Test-Docker {
    try {
        $result = docker info 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Convert-ToWslPath([string]$WinPath) {
    $WinPath = $WinPath -replace '\\', '/'
    if ($WinPath -match '^([A-Za-z]):(.*)') {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2]
        return "/mnt/$drive$rest"
    }
    return $WinPath
}

# ============================================================================
# Strategy 1: Build via WSL2
# ============================================================================
function Invoke-WSLBuild {
    Write-Host "[BUILD] Using WSL2 Ubuntu..." -ForegroundColor Green

    $wslSource = Convert-ToWslPath $SourceDir
    $wslScript = "$wslSource/$BashScript"

    # Make script executable
    wsl -d Ubuntu-22.04 -- chmod +x $wslScript

    # Build NDK path arg
    $ndkArg = ""
    if ($NdkPath) {
        $wslNdk = Convert-ToWslPath $NdkPath
        $ndkArg = "--ndk-path $wslNdk"
    }

    $skipArg = ""
    if ($SkipDeps) { $skipArg = "--skip-deps" }

    # Run the build
    $cmd = "bash $wslScript --source $wslSource $ndkArg $skipArg"
    Write-Host "[BUILD] Running: wsl -d Ubuntu-22.04 -- $cmd" -ForegroundColor Gray
    wsl -d Ubuntu-22.04 -- bash -c $cmd

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] WSL build failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}

# ============================================================================
# Strategy 2: Build via Docker
# ============================================================================
function Invoke-DockerBuild {
    Write-Host "[BUILD] Using Docker..." -ForegroundColor Green

    $dockerSource = $SourceDir -replace '\\', '/'

    # Create a temporary Dockerfile
    $dockerfile = @"
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    gfortran-aarch64-linux-gnu \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    libboost-dev \
    wget make \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
ENTRYPOINT ["bash"]
"@

    $dockerfilePath = Join-Path $SourceDir 'prebuilt\scripts\Dockerfile.arm64'
    Set-Content -Path $dockerfilePath -Value $dockerfile -Encoding UTF8

    # Build Docker image
    Write-Host "[BUILD] Building Docker image..." -ForegroundColor Gray
    docker build -t decodium3-arm64-builder -f $dockerfilePath $ScriptDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker image build failed" -ForegroundColor Red
        exit 1
    }

    # Build NDK volume mount
    $ndkMount = ""
    $ndkArg = ""
    if ($NdkPath) {
        $ndkMount = "-v `"${NdkPath}:/ndk:ro`""
        $ndkArg = "--ndk-path /ndk"
    }

    $skipArg = ""
    if ($SkipDeps) { $skipArg = "--skip-deps" }

    # Run build in container
    $cmd = "docker run --rm -v `"${dockerSource}:/src`" $ndkMount decodium3-arm64-builder /src/$BashScript --source /src --skip-deps $ndkArg"
    Write-Host "[BUILD] Running: $cmd" -ForegroundColor Gray
    Invoke-Expression $cmd

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker build failed" -ForegroundColor Red
        exit 1
    }
}

# ============================================================================
# Strategy 3: Manual instructions
# ============================================================================
function Show-ManualInstructions {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host " MANUAL BUILD REQUIRED" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Neither WSL2 nor Docker are available." -ForegroundColor White
    Write-Host "You need a Linux environment to cross-compile Fortran for ARM64." -ForegroundColor White
    Write-Host ""
    Write-Host "Option A: Enable WSL2" -ForegroundColor Cyan
    Write-Host "  1. Open PowerShell as Administrator" -ForegroundColor Gray
    Write-Host "  2. Run: dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -ForegroundColor Gray
    Write-Host "  3. Run: dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -ForegroundColor Gray
    Write-Host "  4. Reboot" -ForegroundColor Gray
    Write-Host "  5. Run: wsl --set-default-version 2" -ForegroundColor Gray
    Write-Host "  6. Run this script again" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option B: Use Docker Desktop" -ForegroundColor Cyan
    Write-Host "  1. Install Docker Desktop for Windows" -ForegroundColor Gray
    Write-Host "  2. Start Docker Desktop" -ForegroundColor Gray
    Write-Host "  3. Run this script again with: -Strategy docker" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option C: Build on a Linux machine or CI" -ForegroundColor Cyan
    Write-Host "  1. Copy the Decodium3 source to a Linux machine" -ForegroundColor Gray
    Write-Host "  2. Run: bash prebuilt/scripts/build_android_arm64.sh --source /path/to/Decodium3" -ForegroundColor Gray
    Write-Host "  3. Copy prebuilt/android-arm64-v8a/ back to Windows" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option D: Use GitHub Actions CI" -ForegroundColor Cyan
    Write-Host "  See: prebuilt/scripts/ci_build_arm64.yml" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# Install Android NDK if missing
# ============================================================================
function Install-AndroidNDK {
    $sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"

    if (-not $NdkPath) {
        # Check if NDK already exists
        $ndkDir = Get-ChildItem -Path "$sdkRoot\ndk" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($ndkDir) {
            $NdkPath = $ndkDir.FullName
            Write-Host "[INFO] Found existing NDK: $NdkPath" -ForegroundColor Gray
            return
        }
    }

    if ($NdkPath -and (Test-Path $NdkPath)) {
        Write-Host "[INFO] Using NDK: $NdkPath" -ForegroundColor Gray
        return
    }

    Write-Host "[INFO] Android NDK not found." -ForegroundColor Yellow
    Write-Host "[INFO] Install it with:" -ForegroundColor Yellow
    Write-Host "  sdkmanager 'ndk;27.0.12077973'" -ForegroundColor Gray
    Write-Host "  Or via Android Studio > SDK Manager > SDK Tools > NDK" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[INFO] The NDK is optional for Fortran cross-compilation" -ForegroundColor Gray
    Write-Host "[INFO] (cross-gcc will be used instead of NDK Clang for C files)" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# Verify results
# ============================================================================
function Test-BuildResults {
    Write-Host ""
    Write-Host "[BUILD] Verifying outputs..." -ForegroundColor Green
    $allOk = $true

    $files = @('libwsjt_fort.a', 'libfftw3f.a', 'libgfortran.a')
    foreach ($f in $files) {
        $path = Join-Path $OutputDir $f
        if (Test-Path $path) {
            $size = (Get-Item $path).Length
            $sizeKB = [math]::Round($size / 1024)
            Write-Host "  OK    $f  (${sizeKB} KB)" -ForegroundColor Green
        } else {
            Write-Host "  MISS  $f" -ForegroundColor Red
            $allOk = $false
        }
    }

    Write-Host ""
    if ($allOk) {
        Write-Host "[BUILD] All libraries built successfully!" -ForegroundColor Green
        Write-Host "[BUILD] Output: $OutputDir" -ForegroundColor Gray
    } else {
        Write-Host "[ERROR] Some libraries are missing." -ForegroundColor Red
    }
    return $allOk
}

# ============================================================================
# Main
# ============================================================================

if ($Help) {
    Write-Host @"
build_android_arm64.ps1 - Cross-compile Fortran/FFTW3 for Android ARM64

USAGE:
    .\build_android_arm64.ps1 [-Strategy auto|wsl|docker] [-NdkPath PATH] [-SkipDeps]

PARAMETERS:
    -Strategy   Build method: auto (try WSL then Docker), wsl, or docker
    -NdkPath    Path to Android NDK (optional, for C files)
    -SkipDeps   Skip installing prerequisites
    -Help       Show this help

EXAMPLES:
    .\build_android_arm64.ps1
    .\build_android_arm64.ps1 -Strategy docker
    .\build_android_arm64.ps1 -NdkPath C:\Android\ndk\27.0.12077973
"@
    exit 0
}

Write-Header
Install-AndroidNDK

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

switch ($Strategy) {
    'wsl' {
        if (Test-WSL) {
            Invoke-WSLBuild
        } else {
            Write-Host "[ERROR] WSL2 not available or not functional" -ForegroundColor Red
            Show-ManualInstructions
            exit 1
        }
    }
    'docker' {
        if (Test-Docker) {
            Invoke-DockerBuild
        } else {
            Write-Host "[ERROR] Docker not available" -ForegroundColor Red
            Show-ManualInstructions
            exit 1
        }
    }
    'auto' {
        if (Test-WSL) {
            Write-Host "[INFO] WSL2 detected and functional" -ForegroundColor Gray
            Invoke-WSLBuild
        } elseif (Test-Docker) {
            Write-Host "[INFO] Docker detected" -ForegroundColor Gray
            Invoke-DockerBuild
        } else {
            Show-ManualInstructions
            exit 1
        }
    }
}

Test-BuildResults
