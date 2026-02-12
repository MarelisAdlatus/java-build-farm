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

# Function to check OS details
check_os() {
    os_line=$(hostnamectl | grep "Operating System:")
    os_version=$(echo "$os_line" | awk -F': ' '{print $2}')

    # Split into words for analysis
    IFS=' ' read -ra words <<< "$os_version"

    # Initialize variables
    distro=""
    version=""
    os="linux"

    # Iterate through words to identify distro and version
    for (( i=0; i<${#words[@]}; i++ )); do
        word=${words[i]}

        # Check for known distros
        if [[ "$word" == "Rocky" || "$word" == "CentOS" || "$word" == "AlmaLinux" || "$word" == "Oracle" ]]; then
            distro="$word"
            version="${words[*]:i+2}"  # Combine remaining words after "Rocky Linux" (or similar)
            break
        elif [[ "$word" == "openSUSE" ]]; then
            distro="$word"
            version="${words[*]:i+1}"  # Combine remaining words for version
            break
        elif [[ "$word" == "Arch" ]]; then
            distro="Arch"
            version="${words[*]:i+1}"
            break            
        elif [[ "$word" == "Debian" || "$word" == "Ubuntu" || "$word" == "Fedora" || "$word" == "Mint" ]]; then
            distro="$word"
            # Check for GNU/Linux or Linux following the distro name
            if [[ "${words[i+1]}" == "GNU/Linux" || "${words[i+1]}" == "Linux" ]]; then
                version="${words[*]:i+2}"  # Combine remaining words after "GNU/Linux" or "Linux"
            else
                version="${words[*]:i+1}"  # Combine remaining words
            fi
            break          
        fi
    done

    # Cleanup: Remove extra spaces from version
    version=$(echo "$version" | xargs)  

    # Extract major version from version
    major_version=$(echo "$version" | grep -oE '^[0-9]+' || echo "0")  # Extract first number or 0

    # Convert to lowercase (if desired)
    distro=$(echo "$distro" | tr '[:upper:]' '[:lower:]')
    version=$(echo "$version" | tr '[:upper:]' '[:lower:]')

    echo "os: $os, distro: $distro, version: $version, major version: $major_version"
    echo "architecture: $(hostnamectl | grep "Architecture:" | awk '{print $2}')"
}

# Function to check for and install the highest available Java version
install_java() {
    echo "Checking for the highest available Java version on $os $distro $version..."

    case "$distro" in
        debian)
            # Debian supports Java 8, 11 and 17
            if [[ $major_version -ge 10 ]]; then
                sudo apt-get install -y openjdk-17-jdk
            else
                sudo apt-get install -y openjdk-11-jdk
            fi
            sudo update-alternatives --config java
            ;;
        ubuntu | mint)
            # Ubuntu supports Java 8, 11, 17, and 21
            sudo apt-get install -y openjdk-21-jdk
            sudo update-alternatives --config java
            ;;
        rocky | centos | alma)
            # RHEL-based distros support Java 11, 17, and 21
            if [[ $major_version -ge 9 ]]; then
                sudo dnf install -y java-21-openjdk java-21-openjdk-devel java-21-openjdk-jmods
            else
                sudo dnf install -y java-17-openjdk java-17-openjdk-devel java-17-openjdk-jmods
            fi
            sudo alternatives --config java
            ;;
        fedora)
            # Fedora supports Java 11, 17, and 21
            sudo dnf install -y java-21-openjdk java-21-openjdk-devel java-21-openjdk-jmods
            sudo alternatives --config java
            ;;
        arch)
            sudo pacman -S --noconfirm jdk-openjdk
            sudo archlinux-java status
            ;;
        opensuse*)
            # openSUSE supports Java 8, 11, 17, and 21
            sudo zypper install -y java-21-openjdk java-21-openjdk-devel java-21-openjdk-jmods
            sudo update-alternatives --config java
            # Get the path to the currently selected Java executable (after user interaction)
            java_path=$(sudo update-alternatives --query java | grep 'Value:' | awk '{print $2}') 
            # Extract the base directory of the JDK from the Java path
            jdk_base_dir=$(dirname "$(dirname "$java_path")") 
            # Add jpackage to PATH only if it's not already there
            if ! grep -q "$jdk_base_dir/bin" ~/.bashrc; then
                echo "export PATH=\$PATH:$jdk_base_dir/bin" >> ~/.bashrc
                source ~/.bashrc 
            fi
                ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: $distro. Java installation skipped.${NC}" >&2
            return 1
            ;;
    esac

    # Check if Java is installed
    if ! output=$(java -version 2>&1); then
        echo -e "${RED}Java does not appear to be installed.${NC}"
        return 1  # Indicate an error
    else
        echo -e "${GREEN}Currently used Java version:${NC}"
        echo "$output"
    fi
}

# Function to update/upgrade packages and autoremove
update_system() {

    echo "Updating and upgrading packages on $os $distro $version..." 

    case "$distro" in
        debian | ubuntu | mint)
            sudo apt-get update
            sudo apt-get upgrade -y
            sudo apt-get autoremove -y
            ;;
        rocky | centos | alma)
            # Enable EPEL repository for RHEL-based distros if not already enabled
            if ! sudo dnf repolist | grep -q "epel"; then
                sudo dnf install epel-release -y
            fi

            sudo dnf upgrade --refresh -y 
            sudo dnf autoremove -y
            ;;
        fedora)
            sudo dnf upgrade --refresh -y 
            sudo dnf autoremove -y
            ;;
        arch)
            sudo pacman -Syu --noconfirm
            ;;            
        opensuse*)
            sudo zypper refresh
            sudo zypper update -y 
            sudo zypper clean --all
            ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: $distro. System update skipped.${NC}" >&2
            return 1
            ;;
    esac
}

# Function to install apps
install_apps() {

    echo "Installing apps on $os $distro $version..."

    case "$distro" in
        debian | ubuntu | mint)
            sudo apt-get install -y p7zip-full binutils fakeroot
            ;;
        rocky | centos | alma)
            sudo dnf install -y p7zip p7zip-plugins binutils fakeroot rpm-build rpmlint
            ;;
        fedora)
            sudo dnf install -y p7zip p7zip-plugins binutils fakeroot rpm-build rpmlint
            ;;
        arch)
            sudo pacman -S --noconfirm p7zip binutils fakeroot rpm-tools rpmlint
            ;;            
        opensuse*)
            sudo zypper install -y 7zip binutils fakeroot rpm-build rpmlint
            ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: $distro. Application installation skipped.${NC}" >&2
            return 1
            ;;
    esac
}

# Get the hostname of the current machine
hostname=$(hostname)

check_os  # Call the function to check OS details

# Update system and install Java
if ! update_system; then
    echo -e "${RED}Error updating system on $hostname${NC}\n" # Red for error
else
    echo -e "${GREEN}System updated and unused packages removed successfully on $hostname${NC}\n" # Green for success
fi

# Install Java
if ! install_java; then
    echo -e "${RED}Error installing Java on $hostname${NC}\n" # Red for error
else
    echo -e "${GREEN}Java installed successfully on $hostname${NC}\n" # Green for success
fi

# Install applications
if ! install_apps; then
    echo -e "${RED}Error installing applications on $hostname${NC}\n" # Red for error
else
    echo -e "${GREEN}Applications installed successfully on $hostname${NC}\n" # Green for success
fi
