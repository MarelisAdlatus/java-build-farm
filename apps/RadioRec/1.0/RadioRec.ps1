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

# Requires PowerShell 5.1 or higher

# Command line verbosity (mimicking Bash's set -x)
if ($args[0] -eq "--verbose") {
    $VerbosePreference = "Continue" 
}

# Build configuration for Java application
$app_name = "RadioRec"
$app_version = "1.0"
$app_desc = "Application for playing and recording internet radio stations."
$app_vendor = "Marelis Adlatus"
$app_copyright = "2025 Marek Liška <adlatus@marelis.cz>"
$main_jar = "RadioRec-1.0.jar"
$main_class = "cz.marelis.radiorec.RadioRec"
$java_options = "-Dhttps.protocols=TLSv1.2"
$app_icon = "icons/RadioRec.ico"

# Build variables
$build_dir = "build"
$runtime_dir = "runtime"
$temp_dir = "temp"
$release_dir = "release"

# Java JDK bin directory path (adjust as needed)
$javaBinPath = "C:\Users\Worker\AppData\Local\EclipseAdoptium\jdk-21.0.9.10-hotspot\bin"

# 7-Zip bin directory path (adjust as needed)
$sevenZipPath = "C:\Users\Worker\AppData\Local\7-Zip"

# Inno Setup bin directory path (adjust as needed)
$innoSetupPath = "C:\Users\Worker\AppData\Local\Inno Setup 6"

$global:modules = "" 

# Check if Java binaries exist
$javaExecutables = @("java.exe", "jdeps.exe", "jlink.exe", "jpackage.exe")
foreach ($exe in $javaExecutables) {
    if (-Not (Test-Path "$javaBinPath\$exe")) {
        Write-Error "Java binary $exe not found at $javaBinPath. Please update the path in the script."
        exit 1
    }
}

# Check if 7-Zip bin directory exists
if (-Not (Test-Path "$sevenZipPath\7za.exe")) {
    Write-Error "7-Zip binary not found at $sevenZipPath. Please update the path in the script."
    exit 1
}

# Check if Inno Setup bin directory exists
if (-Not (Test-Path "$innoSetupPath\ISCC.exe")) {
    Write-Error "Inno Setup compiler not found at $innoSetupPath. Please update the path in the script."
    exit 1
}

function clean_build {
    Write-Output "info: prepare build"
    if (Test-Path $temp_dir) { Remove-Item $temp_dir -Recurse -Force }
    if (Test-Path $runtime_dir) { Remove-Item $runtime_dir -Recurse -Force }
    if (Test-Path $release_dir) { Remove-Item $release_dir -Recurse -Force }
    if (Test-Path $app_name) { Remove-Item $app_name -Recurse -Force }
    Remove-Item "modules-*" -Force -ErrorAction SilentlyContinue # Ignore if not present
    New-Item $release_dir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}

function get_used_modules {
    Write-Output "info: list of all jdk modules"
    & "$javaBinPath\java.exe" --list-modules | %{ $_.Split('@')[0].Trim() } > modules-jdk

    Write-Output "info: finding the required modules"
    & "$javaBinPath\jdeps.exe" --multi-release base --module-path "${build_dir}\libs" --list-reduced-deps `
        --ignore-missing-deps "${build_dir}\${main_jar}" | %{ $_.Trim() } > modules-app

    Write-Output "info: required in jdk modules"
    (Get-Content modules-jdk) | Where-Object { (Get-Content modules-app) -contains $_ } > modules-list
    $global:modules = (Get-Content modules-list) -join ','
}

function build_java_runtime {
    Write-Output "info: build java runtime"
    $manual_modules = ",jdk.crypto.ec,jdk.localedata"
    & "$javaBinPath\jlink.exe" --no-header-files --no-man-pages --compress=zip-9 --strip-debug `
        --add-modules ($global:modules + $manual_modules) --include-locales=en,de --output $runtime_dir
}

function build_app_image {
    Write-Output "info: build app image"
    & "$javaBinPath\jpackage.exe" --type app-image --name $app_name --app-version $app_version `
        --description $app_desc --vendor $app_vendor --copyright $app_copyright `
        --main-jar $main_jar --main-class $main_class --java-options $java_options `
        --icon $app_icon --input $build_dir --temp $temp_dir --runtime-image $runtime_dir
}

function archive_app_image {
    Write-Output "info: archive app image to zip"
    & "$sevenZipPath\7za.exe" a -tzip -bso0 "${release_dir}\${app_name}-${app_version}-image.zip" $app_name
}

function build_inno_setup {
    Write-Output "info: build inno setup"
    Copy-Item "addons\License.txt" "$app_name\" -Force
    Copy-Item "icons\Station.ico" "$app_name\" -Force
    & "$innoSetupPath\ISCC.exe" /q "${app_name}.iss"
    Move-Item *.exe $release_dir -Force
}

function set_permissions {
    Write-Output "info: set permissions"
    Get-ChildItem -Recurse | ForEach-Object { $_.Attributes = "Normal" } # Remove read-only
}

# Main execution
Write-Host "info: current dir $(Get-Location)"

$system_name = $env:OS # Get OS name on Windows

if ($system_name -match "Windows*") {
    $app_icon = "icons\${app_name}.ico"
    clean_build
    get_used_modules
    build_java_runtime
    build_app_image
    archive_app_image
    build_inno_setup
    set_permissions
} else {
    Write-Output "Error: Unsupported operating system ($system_name)"
}
