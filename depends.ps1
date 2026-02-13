#
# Copyright 2025 Marek Liška <adlatus@marelis.cz>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# CONFIG
# -----------------------------------------------------------------------------

$WorkDir = ".build"

# Per-user install roots (run this script as Worker to affect Worker)
$SevenZipDir = Join-Path $env:LOCALAPPDATA "7-Zip"
$JdkDir      = Join-Path $env:LOCALAPPDATA "EclipseAdoptium\jdk-21.0.9.10-hotspot"
$InnoDir     = Join-Path $env:LOCALAPPDATA "Inno Setup 6"

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------

function New-CleanDirectory {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (Test-Path $Path) {
        Write-Host "Deleting existing directory: $Path"
        Remove-Item -Recurse -Force $Path
    }

    Write-Host "Creating directory: $Path"
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Ensure-Dir {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Download-File {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$OutFile
    )

    Write-Host "Downloading: $Url"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($Url, $OutFile)
    Write-Host "Download completed: $OutFile"
}

function Expand-Zip {
    param(
        [Parameter(Mandatory=$true)][string]$ZipPath,
        [Parameter(Mandatory=$true)][string]$Dest
    )
    Ensure-Dir $Dest
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $Dest -Force
}

function Expand-7zWith7zr {
    param(
        [Parameter(Mandatory=$true)][string]$SevenZPath,
        [Parameter(Mandatory=$true)][string]$Dest,
        [Parameter(Mandatory=$true)][string]$SevenZrExe
    )
    Ensure-Dir $Dest
    & $SevenZrExe x "-o$Dest" -y $SevenZPath | Out-Host
}

function Flatten-SingleTopFolder {
    param(
        [Parameter(Mandatory=$true)][string]$Dest,
        [Parameter(Mandatory=$true)][string]$ProbeRelativePath
    )

    $inner = Get-ChildItem -Path $Dest -Directory | Select-Object -First 1
    if ($inner -and (Test-Path (Join-Path $inner.FullName $ProbeRelativePath))) {
        Get-ChildItem -Path $inner.FullName -Force | ForEach-Object {
            Move-Item -Force -Path $_.FullName -Destination $Dest
        }
        Remove-Item -Recurse -Force $inner.FullName
    }
}

function Set-UserEnvVar {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value
    )
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
}

function Add-UserPathPrefixIfMissing {
    param([Parameter(Mandatory=$true)][string]$Prefix)

    $path = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrEmpty($path)) { $path = "" }

    if ($path -notlike "*$Prefix*") {
        [Environment]::SetEnvironmentVariable("Path", "$Prefix;$path", "User")
    }
}

function Set-UserPathFirst {
    param([Parameter(Mandatory=$true)][string]$Prefix)

    $path = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrEmpty($path)) { $path = "" }

    $parts = $path -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    # remove any existing occurrences (simple match)
    $parts = $parts | Where-Object { $_ -ne $Prefix }

    $newPath = ($Prefix + ';' + ($parts -join ';')).TrimEnd(';')
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

function Find-FirstExistingExe {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string[]]$Names
    )

    foreach ($n in $Names) {
        $hit = Get-ChildItem -Path $Root -Recurse -File -Filter $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

# -----------------------------------------------------------------------------
# PREPARE WORKDIR
# -----------------------------------------------------------------------------

New-CleanDirectory -Path $WorkDir

# -----------------------------------------------------------------------------
# 1) 7-Zip CLI (portable, per-user)
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "=== 1/3 Installing 7-Zip CLI (portable, per-user) ==="

$SevenZrUrl  = "https://www.7-zip.org/a/7zr.exe"
$SevenZrPath = Join-Path $WorkDir "7zr.exe"
$SevenZipUrl = "https://www.7-zip.org/a/7z2600-extra.7z"
$SevenZipPkg = Join-Path $WorkDir "7z2600-extra.7z"

# Marker file to skip re-extract
$SevenZipMarker = Join-Path $SevenZipDir ".installed"

if (-not (Test-Path $SevenZipMarker)) {
    Ensure-Dir $SevenZipDir

    if (-not (Test-Path $SevenZrPath)) {
        Download-File -Url $SevenZrUrl -OutFile $SevenZrPath
    }
    Download-File -Url $SevenZipUrl -OutFile $SevenZipPkg

    Expand-7zWith7zr -SevenZPath $SevenZipPkg -Dest $SevenZipDir -SevenZrExe $SevenZrPath

    # find usable CLI
    $SevenZipCli = Find-FirstExistingExe -Root $SevenZipDir -Names @("7z.exe","7za.exe","7zr.exe")
    if (-not $SevenZipCli) {
        throw "7-Zip CLI not found under: $SevenZipDir"
    }

    Add-UserPathPrefixIfMissing -Prefix (Split-Path -Parent $SevenZipCli)

    # sanity
    & $SevenZipCli | Out-Null

    New-Item -ItemType File -Path $SevenZipMarker -Force | Out-Null
    Write-Host "OK: 7-Zip CLI installed to $SevenZipDir (CLI: $SevenZipCli)"
} else {
    $SevenZipCli = Find-FirstExistingExe -Root $SevenZipDir -Names @("7z.exe","7za.exe","7zr.exe")
    Write-Host "7-Zip already present under: $SevenZipDir (CLI: $SevenZipCli) (skipping)"
}

# -----------------------------------------------------------------------------
# 2) OpenJDK 21 (Temurin, per-user ZIP) + enforce PATH priority for Worker
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "=== 2/3 Installing OpenJDK 21 (Temurin, per-user) ==="

$JdkUrl   = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_x64_windows_hotspot_21.0.9_10.zip"
$JdkZip   = Join-Path $WorkDir "OpenJDK21U-jdk_x64_windows_hotspot_21.0.9_10.zip"
$JavaExe  = Join-Path $JdkDir "bin\java.exe"
$JdkBin   = Join-Path $JdkDir "bin"

if (-not (Test-Path $JavaExe)) {
    Download-File -Url $JdkUrl -OutFile $JdkZip

    Expand-Zip -ZipPath $JdkZip -Dest $JdkDir
    Flatten-SingleTopFolder -Dest $JdkDir -ProbeRelativePath "bin\java.exe"

    Set-UserEnvVar -Name "JAVA_HOME" -Value $JdkDir

    # Ensure Worker user PATH has JDK21 bin first (so it wins over system JDK 17)
    Set-UserPathFirst -Prefix $JdkBin

    # Keep other per-user tools in PATH
    Add-UserPathPrefixIfMissing -Prefix $SevenZipDir

    # sanity (explicit path)
    & $JavaExe -version
    Write-Host "OK: OpenJDK installed to $JdkDir"
} else {
    # Even if already installed, still enforce PATH priority
    Set-UserEnvVar -Name "JAVA_HOME" -Value $JdkDir
    Set-UserPathFirst -Prefix $JdkBin
    Add-UserPathPrefixIfMissing -Prefix $SevenZipDir

    Write-Host "OpenJDK already present: $JavaExe (PATH priority enforced) (skipping)"
}

# -----------------------------------------------------------------------------
# 3) Inno Setup 6 (attempt per-user) + add to PATH for Worker
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "=== 3/3 Installing Inno Setup 6 (per-user) ==="

$InnoUrl = "https://jrsoftware.org/download.php/innosetup-6.7.0.exe"
$InnoExe = Join-Path $WorkDir "innosetup-6.7.0.exe"
$ISCC    = Join-Path $InnoDir "ISCC.exe"

if (-not (Test-Path $ISCC)) {
    Download-File -Url $InnoUrl -OutFile $InnoExe

    $args = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /DIR=`"$InnoDir`""
    Start-Process -FilePath $InnoExe -ArgumentList $args -Wait -NoNewWindow

    if (Test-Path $ISCC) {
        Add-UserPathPrefixIfMissing -Prefix $InnoDir
        Write-Host "OK: Inno Setup installed to $InnoDir"
    } else {
        Write-Warning "Inno Setup did not install ISCC.exe to expected path: $ISCC"
        Write-Warning "Installer may have ignored /CURRENTUSER or /DIR. Check its default install location."
    }
} else {
    Add-UserPathPrefixIfMissing -Prefix $InnoDir
    Write-Host "Inno Setup already present: $ISCC (PATH updated) (skipping)"
}

Write-Host ""
Write-Host "Done."
