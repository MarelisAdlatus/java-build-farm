#!/bin/bash

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

# script termination on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# command line - verbosity
if [[ $1 == "--verbose" ]] ; then
  set -x
fi

# Build configuration for Java application
app_name="RadioRec"
app_version="1.0"
app_desc="Application for playing and recording internet radio stations."
app_vendor="Marelis Adlatus"
app_copyright="2025 Marek Liška <adlatus@marelis.cz>"
main_jar="RadioRec-1.0.jar"
main_class="cz.marelis.radiorec.RadioRec"
java_options="--java-options '-Dhttps.protocols=TLSv1.2'"
app_icon="icons/RadioRec.ico" # or icons/RadioRec-512.png for Linux

build_dir="build"
runtime_dir="runtime"
temp_dir="temp"
release_dir="release"

clean () {
  echo "info: prepare build"
  rm -Rf "$temp_dir" "$runtime_dir" "$release_dir" "$app_name"
  rm -f modules-*
  mkdir "$release_dir"
}

get_used_modules () {
  echo "info: list of all jdk modules"
  java --list-modules | cut -f1 -d"@" | sed 's/^ *//;s/ *$//' | tr -d '\r' > modules-jdk
  #echo "info: finding the required modules with module-info"
  #jar --file="${build_dir}/${main_jar}" --describe-module | grep "requires" | cut -d' ' -f2 | tr -d '\r' > modules-app
  echo "info: finding the required modules"
  jdeps --multi-release base --module-path "${build_dir}/libs" --list-reduced-deps \
  --ignore-missing-deps "${build_dir}/${main_jar}" | sed 's/^ *//;s/ *$//' | tr -d '\r' > modules-app
  echo "info: required in jdk modules"
  grep -f modules-jdk modules-app > modules-list
  # comma-separated list
  modules=$(cat modules-list | paste -d',' -s)
}

build_java_runtime () {
    echo "info: build java runtime"
    manual_modules=",jdk.crypto.ec,jdk.localedata"
    # First attempt with zip-9 compression
    jlink --no-header-files --no-man-pages --compress=zip-9 --strip-debug \
        --add-modules $modules$manual_modules --include-locales=en,de --output "$runtime_dir" || {
        # Check for the specific error
        if [[ ${PIPESTATUS[0]} == 1 ]] && grep -q "Error: Invalid compression level" <<< "${BASH_COMMAND}"; then
            echo "warning: Invalid compression level, retrying with --compress=2"
            # Second attempt with compression 2
            jlink --no-header-files --no-man-pages --compress=2 --strip-debug \
                --add-modules $modules$manual_modules --include-locales=en,de --output "$runtime_dir"
        else
            # Other error, let the script exit due to set -e
            return 1 
        fi
    }
}

build_app_image () {
  echo "info: build app image"
  jpackage --type app-image --name "$app_name" --app-version "$app_version" \
  --description "$app_desc" --vendor "$app_vendor" --copyright "$app_copyright" \
  --main-jar "$main_jar" --main-class "$main_class" $java_options \
  --icon "$app_icon" --input "$build_dir" --temp "$temp_dir" --runtime-image "$runtime_dir"
}

archive_app_image () {
  echo "info: archive app image to zip"
  7z a -tzip -bso0 "${release_dir}/${app_name}-${app_version}-image.zip" ${app_name}
  echo "info: archive app image to tar.gz"
  7z a -ttar -so "${release_dir}/${app_name}-${app_version}-image.tar" ${app_name} | gzip > "${release_dir}/${app_name}-${app_version}-image.tar.gz"
}

build_debian () {
  echo "info: build debian package"
  rm -Rf "$temp_dir"
  jpackage --type deb --name "$app_name" --app-version "$app_version" --license-file "addons/License.txt" \
  --description "$app_desc" --vendor "$app_vendor" --copyright "$app_copyright" \
  --main-jar "$main_jar" --main-class "$main_class" $java_options \
  --icon "$app_icon" --input "$build_dir" --temp "$temp_dir" --runtime-image "$runtime_dir" \
  --dest "${release_dir}" --file-associations ${app_name}.properties --linux-shortcut \
  --linux-menu-group "Audio;Network;Recorder" --linux-deb-maintainer "adlatus@marelis.cz" \
  --linux-app-release "1" --linux-app-category "Sound" --linux-package-deps "chromium-browser"
}

build_rpm () {
  echo "info: build rpm package"
  rm -Rf "$temp_dir"
  jpackage --type rpm --name "$app_name" --app-version "$app_version" --license-file "addons/License.txt" \
  --description "$app_desc" --vendor "$app_vendor" --copyright "$app_copyright" \
  --main-jar "$main_jar" --main-class "$main_class" $java_options \
  --icon "$app_icon" --input "$build_dir" --temp "$temp_dir" --runtime-image "$runtime_dir" \
  --dest "${release_dir}" --file-associations ${app_name}.properties --linux-shortcut \
  --linux-menu-group "Audio;Network;Recorder" --linux-rpm-license-type "ASL 2.0" \
  --linux-app-release "1" --linux-app-category "Sound" --linux-package-deps "chromium-browser"
}

build_pkg () {
  echo "info: build pkg package"
  rm -Rf "$temp_dir"
  jpackage --type pkg --name "$app_name" --app-version "$app_version" --license-file "addons/License.txt" \
  --description "$app_desc" --vendor "$app_vendor" --copyright "$app_copyright" \
  --main-jar "$main_jar" --main-class "$main_class" $java_options \
  --icon "$app_icon" --input "$build_dir" --temp "$temp_dir" --runtime-image "$runtime_dir" \
  --dest "${release_dir}" --file-associations ${app_name}.properties --linux-shortcut \
  --linux-menu-group "Audio;Network;Recorder" --linux-app-release "1" \
  --linux-app-category "Sound" --linux-package-deps "chromium-browser"
}

set_permissions () {
  echo "info: set permissions"
  chmod -R 777 ./*
}

build_linux () {
  if [ -x "$(command -v apt)" ]; then
    build_debian
  elif [ -x "$(command -v zypper)" ]; then
    build_rpm
  elif [ -x "$(command -v yum)" ]; then
    build_rpm
  elif [ -x "$(command -v pkg)" ]; then
    build_pkg
  elif [ -x "$(command -v pacman)" ]; then
    echo "error: the pacman package manager is not supported"
  fi
}

echo "info: current dir" $(pwd)

system_name=$(uname)

if [[ "$system_name" == Linux* ]]; then
    app_icon="icons/${app_name}-512.png"
    clean && get_used_modules && build_java_runtime && build_app_image \
    && archive_app_image && build_linux && set_permissions
else
    # Display error message for unsupported operating systems
    echo -e "${RED}Error: Unsupported operating system ($system_name)${NC}" 
fi
