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

echo "This script is for building applications on remote VMs and hosts"
echo ""

# Verbose mode (optional)
if [[ $1 == "--verbose" ]]; then
    set -x
fi

# Function to check if a command exists
check_command() {
    local command=$1
    if ! command -v "$command" &> /dev/null; then
        echo -e "${RED}Error: $command is not installed. Exiting script.${NC}"
        exit 1
    fi
}

# Check for required applications
check_command ssh
check_command scp
check_command sudo
check_command bash
check_command tar
check_command find
check_command awk
check_command sed
check_command cut
check_command head
check_command tr
check_command rm
check_command mkdir
check_command chmod

# all command line arguments
arguments="$@"

# Proxmox server configuration is optional.
# If these variables are not set, VM-related menu options will be hidden.
# Target machines are contacted directly via SSH, with configurations defined in:
# - conf/vms.cfg (for VMs)
# - conf/hosts.cfg (for other hosts)

# Load global configuration settings
source config/global.cfg

# Check if Proxmox server configuration is loaded
if [[ -n "$proxmox_server" && -n "$proxmox_user" ]]; then
    echo "Proxmox VM Manager ($proxmox_server)"
fi

# Load VM configuration
declare -A stations

while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^[^#].* ]]; then
        IFS=' ' read -r vm_id user_at_ip os_type os_name <<< "$line"
        stations["$user_at_ip"]="$vm_id $os_type $os_name"
#        echo "DEBUG: Loaded VM: $user_at_ip ($vm_id, $os_type, $os_name)"
    fi
done < config/vms.cfg

sorted_stations=($(printf '%s\n' "${!stations[@]}" | sort -t . -k 3,3n -k 4,4n))

# Load host configuration
declare -A hosts
while IFS= read -r line; do  # Use default IFS (space, tab, newline) to read whole lines
    if [[ $line =~ ^[^#].*@.* ]]; then  # Check if line is not a comment
        IFS=' ' read -r user_at_ip os_type os_name <<< "$line" 
        hosts["$user_at_ip"]="$os_type $os_name"
#        echo "DEBUG: Loaded HOST: $user_at_ip ($os_type, $os_name)"
    fi
done < config/hosts.cfg

sorted_hosts=($(printf '%s\n' "${!hosts[@]}" | sort -t . -k 3,3n -k 4,4n))

# Main ssh connection function
check_ssh_connection() {
    echo -e "${YELLOW}Checking SSH connections to VMs... ${NC}"
    for s in "${sorted_stations[@]}"; do
        echo -n -e " - ${BOLD}$s${NC}: "
        if ssh -o ConnectTimeout=5 -q "$s" exit; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
    done
    echo -e "${YELLOW}Checking SSH connections to Hosts... ${NC}"
    for h in "${sorted_hosts[@]}"; do
        echo -n -e " - ${BOLD}$h${NC}: "
        if ssh -o ConnectTimeout=5 -q "$h" exit; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
    done
}

check_conditions_target_win() {
    local target=$1

    # Test for internet connectivity on Windows
    echo -n "    * Test Internet: "
    if ssh -q "$target" "ping -n 1 www.google.com 2>NUL" >/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}Failed${NC}"
    fi

    # Test for PowerShell on Windows
    echo -n "    * Test PowerShell: "
    if ssh -q "$target" "pwsh --version 2>NUL" >/dev/null; then
        local pwsh_version
        pwsh_version=$(ssh -q "$target" "pwsh --version 2>NUL" | tr -d '\r\n' | head -n 1 | awk '{print $2}')
        echo -e "${GREEN}OK (version $pwsh_version)${NC}"
    else
        echo -e "${RED}Failed${NC}"
    fi

    # Test for PowerShell execution policy
    echo -n "    * Test PowerShell Execution Policy: "
    local execution_policy
    execution_policy=$(ssh -q "$target" "pwsh -Command \"Get-ExecutionPolicy\" 2>NUL" | tr -d '\r\n')
    if [[ "$execution_policy" == "Restricted" ]]; then
        echo -e "${YELLOW}Restricted (scripts cannot be run)${NC}"
    else
        echo -e "${GREEN}$execution_policy${NC}"
    fi

    # Test for Java availability and version (Windows; User PATH only; java preferred)
    echo -n "    * Test Java: "

    local out
    out=$(ssh -q "$target" \
    "pwsh -NoProfile -Command \"\
        \$p=[Environment]::GetEnvironmentVariable('Path','User') -split ';'; \
        foreach(\$d in \$p){ \
        \$java  = Join-Path \$d 'java.exe'; \
        \$javac = Join-Path \$d 'javac.exe'; \
        if(Test-Path \$java){ \
            \$line = (& \$java -version 2>&1 | Select-Object -First 1); \
            Write-Output ('JAVA|' + \$line); exit 0 \
        } \
        if(Test-Path \$javac){ \
            \$line = (& \$javac -version 2>&1 | Select-Object -First 1); \
            Write-Output ('JAVAC|' + \$line); exit 0 \
        } \
        } \
        Write-Output 'NONE|'; exit 0\"" \
    2>/dev/null \
    | tr -d '\r' \
    | sed -r 's/\x1B\[[0-9;]*[mK]//g') # strip ANSI colors

    case "$out" in
    JAVA\|*)
        echo -e "${GREEN}OK (${out#JAVA|})${NC}"
        ;;
    JAVAC\|*)
        echo -e "${YELLOW}JRE not found, JDK present (${out#JAVAC|})${NC}"
        ;;
    *)
        echo -e "${RED}Not installed${NC}"
        ;;
    esac
}

check_conditions_target_lin() {
    local target=$1

    # Test for internet connectivity on Linux
    echo -n "    * Test Internet: "
    if ssh -q "$target" "bash -c 'exec 3<>/dev/tcp/1.1.1.1/443'" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}Failed${NC}"
    fi

    # Test for sudo on Linux
    echo -n "    * Test Sudo: "
    if ssh -q "$target" "sudo -n true" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}Failed${NC}"
    fi

    # Test for Bash availability and path
    echo -n "    * Test Bash: "
    if ssh -q "$target" "command -v bash" >/dev/null 2>&1; then
        bash_path=$(ssh -q "$target" "command -v bash" | tr -d '\r\n')
        echo -e "${GREEN}OK (path: $bash_path)${NC}"
    else
        echo -e "${RED}Failed${NC}"
    fi

    # Test for Java availability and version
    echo -n "    * Test Java: "
    if ssh -q "$target" "command -v java" >/dev/null 2>&1; then
        java_version=$(ssh -q "$target" "java -version 2>&1 | head -n 1" | tr -d '\r')
        echo -e "${GREEN}OK ($java_version)${NC}"
    elif ssh -q "$target" "command -v javac" >/dev/null 2>&1; then
        javac_version=$(ssh -q "$target" "javac -version 2>&1" | tr -d '\r\n')
        echo -e "${YELLOW}JRE not found, JDK present ($javac_version)${NC}"
    else
        echo -e "${RED}Not installed${NC}"
    fi    
}

# Test conditions on a target (VM or host)
check_conditions_target() {
    local target=$1
    local os_type=$2

    echo -e " - ${BOLD}$target:${NC}"

    case "$os_type" in
        win) check_conditions_target_win "$target" ;;
        lin) check_conditions_target_lin "$target" ;;
        *)   echo -e "    * Unsupported OS" ;;
    esac
}

# Main check function
check_conditions() {
    echo -e "${YELLOW}Testing conditions on all VMs... ${NC}"
    for s in "${sorted_stations[@]}"; do
        local os_type
        os_type=$(echo "${stations[$s]}" | cut -d' ' -f2)
        check_conditions_target "$s" "$os_type"
    done

    echo -e "${YELLOW}Testing conditions on all hosts... ${NC}"
    for h in "${sorted_hosts[@]}"; do
        local os_type
        os_type=$(echo "${hosts[$h]}" | cut -d' ' -f1)
        check_conditions_target "$h" "$os_type"
    done
}

# Helper function to install dependencies on a target (VM or host)
install_dependencies_target() {
    # Uses external variable defined in config/global.cfg:
    # - build_dir: Default directory for storing build artifacts on remote machines

    local target=$1
    local os_type=$2

    echo -e " - ${BOLD}$target${NC}:"

    # upload

   # OS-specific commands
    if [[ "$os_type" == "lin" ]]; then
        local ssh_mkdir_cmd="mkdir -p '$build_dir'"
        local scp_cmd="scp depends.sh $target:$build_dir"
        local chmod_cmd="chmod -R 777 '$build_dir'"
    elif [[ "$os_type" == "win" ]]; then
        # Ensure the remote directory exists
        local ssh_mkdir_cmd="if not exist \"$build_dir\" mkdir \"$build_dir\""
        local scp_cmd="scp depends.ps1 $target:$build_dir"
    else
        echo -e "${RED}Unsupported OS: $os_type${NC}"
        return 1  # Indicate an error
    fi

    # Execute commands on the remote server, handle errors
    if ! ssh -q $target "$ssh_mkdir_cmd" >/dev/null; then
        echo -e "${RED}Error: Could not connect to $target (mkdir). Skipping...${NC}"
        return 1
    fi

    if ! $scp_cmd; then
        echo -e "${RED}Error: Could not upload to $target. Skipping...${NC}"
        return 1
    fi

    if [[ "$os_type" != "win" ]]; then  # Only execute chmod on Linux
        ssh -q $target "$chmod_cmd" >/dev/null || echo "Warning: Could not set permissions on $target."
    fi

    # execute
    if [[ "$os_type" == "lin" ]]; then
        ssh -t "$target" "$build_dir/depends.sh"
    elif [[ "$os_type" == "win" ]]; then
        local ps_command="pwsh -NoProfile -c \"Set-ExecutionPolicy Bypass -Scope Process -Force; & '${build_dir//\\/\\\\}\\depends.ps1'\""
        ssh -t "$target" "$ps_command"
    else
        echo "Unsupported OS: $os_type"
    fi
}

# Main install dependencies function
install_dependencies() {
    echo -e "${YELLOW}:: Install dependencies to VMs...${NC}"
    for s in "${sorted_stations[@]}"; do
        IFS=' ' read -r vm_id os_type os_name <<< "${stations[$s]}"
        install_dependencies_target "$s" "$os_type" || echo "Error installing dependencies $s: SSH connection failed."
    done
    echo -e "${YELLOW}:: Install dependencies to hosts...${NC}"
    for s in "${sorted_hosts[@]}"; do  # Iterate over the keys (user@ip) of the hosts array
        # Extract os_type and os_name directly from the hosts array
        IFS=' ' read -r os_type os_name <<< "${hosts[$s]}" # Use the key to get the value
        
        install_dependencies_target "$s" "$os_type" || echo "Error installing dependencies $s: SSH connection failed."
    done
}

# Start virtual machines
vm_start() {
    # Uses external variables defined in config/global.cfg:
    # - proxmox_server: IP address of the Proxmox server used for managing virtual machines
    # - proxmox_user: SSH user for accessing the Proxmox server

    echo -e "${YELLOW}Starting VMs... ${NC}"
    for s in "${sorted_stations[@]}"; do
        local vm_id=$(echo "${stations[$s]}" | cut -d' ' -f1)
        echo -en " - ${BOLD}VM $vm_id:${NC} "

        if ssh "$proxmox_user"@"$proxmox_server" "qm status $vm_id" | grep -q "status: running"; then
            echo -e "${YELLOW}Already running${NC}"
        else
            if ssh "$proxmox_user"@"$proxmox_server" "qm start $vm_id" >/dev/null 2>&1; then
                echo -e "${GREEN}OK (started)${NC}"
            else
                echo -e "${RED}Failed to start${NC}"
            fi
        fi
    done
}

# Stop virtual machines
vm_stop() {
    # Uses external variables defined in config/global.cfg:
    # - proxmox_server: IP address of the Proxmox server used for managing virtual machines
    # - proxmox_user: SSH user for accessing the Proxmox server

    echo -e "${YELLOW}Stopping VMs... ${NC}"
    for s in "${sorted_stations[@]}"; do
        local vm_id=$(echo "${stations[$s]}" | cut -d' ' -f1)
        echo -en " - ${BOLD}VM $vm_id:${NC} "

        if ssh "$proxmox_user"@"$proxmox_server" "qm status $vm_id" | grep -q "status: stopped"; then
            echo -e "${YELLOW}Already stopped${NC}"
        else
            if ssh "$proxmox_user"@"$proxmox_server" "qm stop $vm_id" >/dev/null 2>&1; then
                echo -e "${GREEN}OK (stopped)${NC}"
            else
                echo -e "${RED}Failed to stop${NC}"
            fi
        fi
    done
}

# Get VM status
vm_status() {
    # Uses external variables defined in config/global.cfg:
    # - proxmox_server: IP address of the Proxmox server used for managing virtual machines
    # - proxmox_user: SSH user for accessing the Proxmox server

    echo -e "${YELLOW}Get VMs status ... ${NC}"
    for s in "${sorted_stations[@]}"; do
        local vm_id=$(echo "${stations[$s]}" | cut -d' ' -f1)
        if [ -n "$vm_id" ]; then  # If VM ID is not empty (VM is available)
            local status=$(ssh "$proxmox_user"@"$proxmox_server" "qm status $vm_id" 2>/dev/null | awk '/status:/ {print $2}')
        else
            local status="unavailable (SSH connection failed)"
        fi
        echo -en " - ${BOLD}VM $vm_id:${NC} "
        if [[ "$status" == "running" ]]; then
            echo -e "${GREEN}$status${NC}"
        elif [[ "$status" == "stopped" ]]; then
            echo -e "${YELLOW}$status${NC}"
        else
            echo -e "${RED}$status${NC}"
        fi
    done
}

# application selection
select_application () {
    # Uses external variable defined in config/global.cfg:
    # - apps_dir: Directory where application source files and configurations are stored

    declare -A app_paths

    # Finds all applications and their versions
    while IFS= read -r -d '' app; do
        app_name=$(basename "$app")
        while IFS= read -r -d '' version; do
        version_name=$(basename "$version")
        app_paths["$app_name $version_name"]="$version"
        done < <(find "$app" -mindepth 1 -maxdepth 1 -type d -print0)
    done < <(find "$apps_dir" -mindepth 1 -maxdepth 1 -type d -print0)

    # Application selection
    echo "Application ?"
    select name in "${!app_paths[@]}"; do
        if [[ -n "$name" ]]; then
        app_name=$(echo "$name" | cut -d' ' -f1)
        app_version=$(echo "$name" | cut -d' ' -f2)
        echo "Selected app '$app_name' version '$app_version'"
        break
        else
        echo "Invalid selection. Try again."
        fi
    done
}

# Helper function to clean on a target (VM or host)
clean_target() {
    # Uses external variable defined in config/global.cfg:
    # - build_dir: Default directory for storing build artifacts on remote machines

    local target=$1
    local os_type=$2
    local clean_cmd=""  # Initialize clean_cmd

    echo "Cleaning $target..."

    # Determine appropriate clean command based on OS type
    if [[ "$os_type" == "lin" ]]; then
        clean_cmd="rm -rf \"$build_dir/$app_name/$app_version\""
    elif [[ "$os_type" == "win" ]]; then
        clean_cmd="if exist \".\\$build_dir\\$app_name\\$app_version\" (rmdir /s /q \".\\$build_dir\\$app_name\\$app_version\")"
    else
        echo -e "${RED}Unsupported OS: $os_type${NC}"
        return 1  # Indicate an error
    fi

    # Robust SSH connection handling with better error messages
    if ssh -q "$target" "$clean_cmd"; then  # -q suppresses standard output
        echo -e "${GREEN}Successfully cleaned $target${NC}"  # Success message
    else
        # Detailed error output
        ssh_exit_status=$?
        echo -e "${RED}Error cleaning $target: SSH command failed with exit code $ssh_exit_status${NC}"
        if [[ $ssh_exit_status -eq 255 ]]; then
            echo -e "${RED}Possible SSH connection issue. Check if the server is reachable and your credentials are correct.${NC}"
        fi
    fi
}

# Main clean function
clean_all() {
    echo -e "${YELLOW}:: Cleaning VMs...${NC}"
    for s in "${sorted_stations[@]}"; do
        IFS=' ' read -r vm_id os_type os_name <<< "${stations[$s]}"
        clean_target "$s" "$os_type" || echo "Error cleaning $s: SSH connection failed."
    done
    
    echo -e "${YELLOW}:: Cleaning hosts...${NC}"
    for s in "${sorted_hosts[@]}"; do  # Iterate over the keys (user@ip) of the hosts array
        # Extract os_type and os_name directly from the hosts array
        IFS=' ' read -r os_type os_name <<< "${hosts[$s]}" # Use the key to get the value
        clean_target "$s" "$os_type" || echo "Error cleaning $s: SSH connection failed."
    done

    # Remove release directory for current app/version

    local dir_app_name
    local dir_app_version

    if [[ "$release_url_paths" == "yes" ]]; then
        dir_app_name=$(url_path "$app_name")
        dir_app_version=$(url_path "$app_version")
    else
        dir_app_name="$app_name"
        dir_app_version="$app_version"
    fi

    local target_release_dir="$release_dir/$dir_app_name/$dir_app_version"

    if [[ -d "$target_release_dir" ]]; then
        echo -e "${YELLOW}:: Removing release directory $target_release_dir${NC}"
        rm -rf "$target_release_dir"
        echo -e "${GREEN}:: Release directory removed.${NC}"
    else
        echo -e "${YELLOW}:: No release directory to remove at $target_release_dir${NC}"
    fi    
}

# Helper function to create the application archive (once)
create_app_archive() {
    # Uses external variable defined in config/global.cfg:
    # - apps_dir: Directory where application source files and configurations are stored

    local temp_dir=$(mktemp -d)
    local temp_archive="$temp_dir/temp_upload.tar.gz"
    (cd "$apps_dir/$app_name/$app_version" && tar -czf "$temp_archive" .)
    echo "$temp_archive"  # Return path to the created archive
}

# Helper function to upload and extract on a target (VM or host)
upload_and_extract_archive() {
    # Uses external variable defined in config/global.cfg:
    # - build_dir: Default directory for storing build artifacts on remote machines

    local s=$1             # Target server (VM or host)
    local os_type=$2       # OS type of the target
    local temp_archive=$3  # Path to the temporary archive

    # OS-specific commands
    if [[ "$os_type" == "lin" ]]; then
        # Linux:
        local remote_build_dir="$build_dir/$app_name/$app_version"

        local ssh_mkdir_cmd="mkdir -p '$remote_build_dir'"
        local scp_cmd="scp $temp_archive $s:$remote_build_dir"
        local ssh_extract_cmd="bash -c 'cd $remote_build_dir && tar -xzf temp_upload.tar.gz && rm temp_upload.tar.gz'"
        local chmod_cmd="chmod -R 777 '$remote_build_dir'"
    elif [[ "$os_type" == "win" ]]; then
        # Windows:
        local win_build_dir="$build_dir\\$app_name\\$app_version"
        local win_temp_archive="$win_build_dir\\temp_upload.tar.gz"

        # 7-Zip bin directory path (adjust as needed)
        local sevenZipPath="C:\\Users\\Worker\\AppData\\Local\\7-Zip\\7za.exe"

        # Ensure the remote directory exists
        local ssh_mkdir_cmd="mkdir \"$win_build_dir\""
        local scp_cmd="scp $temp_archive $s:$win_build_dir"
        local ssh_extract_cmd="\"$sevenZipPath\" x \"$win_temp_archive\" -so | \"$sevenZipPath\" x -bso0 -aoa -si -ttar -o\"$win_build_dir\" && del /Q \"$win_temp_archive\""
    else
        echo -e "${RED}Unsupported OS: $os_type${NC}"
        return 1  # Indicate an error
    fi

    # Execute commands on the remote server, handle errors
    if ! ssh -q $s "$ssh_mkdir_cmd" 2>/dev/null; then
        echo -e "${RED}Error: Could not connect to $s (mkdir). Skipping...${NC}"
        return 1
    fi

    if ! $scp_cmd; then
        echo -e "${RED}Error: Could not upload to $s. Skipping...${NC}"
        return 1
    fi

    if ! ssh -q $s "$ssh_extract_cmd" 2>/dev/null; then
        echo -e "${RED}Error: Could not extract on $s. Skipping...${NC}"
        return 1 
    fi

    if [[ "$os_type" != "win" ]]; then  # Only execute chmod on Linux
        ssh -q $s "$chmod_cmd" 2>/dev/null || echo "Warning: Could not set permissions on $s."
    fi
}

# Main upload function
stations_upload() {
    local temp_archive=$(create_app_archive) # Create archive once

    if [[ -z "$temp_archive" ]]; then  # Check if archive creation failed
        echo -e "${RED}Error: Failed to create application archive.${NC}"
        return 1
    fi

    echo -e "${YELLOW}:: Uploading to VMs...${NC}"
    for s in "${sorted_stations[@]}"; do
        echo -e " - ${BOLD}$s${NC} (VM ${stations[$s]%% *}):"
        IFS=' ' read -r vm_id os_type os_name <<< "${stations[$s]}"
        if ! upload_and_extract_archive "$s" "$os_type" "$temp_archive"; then
            echo -e "${RED}Error uploading to $s${NC}"
        else
            echo -e "${GREEN}Upload to $s completed successfully.${NC}"
        fi
    done

    echo -e "${YELLOW}:: Uploading to hosts...${NC}"
    for s in "${sorted_hosts[@]}"; do
        echo -e " - ${BOLD}$s${NC}:"
        IFS=' ' read -r os_type os_name <<< "${hosts[$s]}"
        if ! upload_and_extract_archive "$s" "$os_type" "$temp_archive"; then
            echo -e "${RED}Error uploading to $s${NC}"
        else
            echo -e "${GREEN}Upload to $s completed successfully.${NC}"
        fi
    done

    if ! rm -rf "$temp_archive"; then  # Check if archive removal failed
        echo -e "${RED}Error: Failed to remove temporary archive.${NC}"
    fi
}

# Helper function to build on a target (VM or host)
build_on_target() {
    # Uses external variable defined in config/global.cfg:
    # - build_dir: Default directory for storing build artifacts on remote machines

    local target=$1
    local os_type=$2

    echo "  - $target..."

    if [[ "$os_type" == "lin" ]]; then
        ssh -t "$target" "cd $build_dir/$app_name/$app_version && ./$app_name.sh $arguments"
    elif [[ "$os_type" == "win" ]]; then
        local ps_command="pwsh -NoProfile -c \"cd '${build_dir//\\/\\\\}\\${app_name}\\${app_version}'; Set-ExecutionPolicy Bypass -Scope Process -Force; .\\${app_name}.ps1\""
        ssh -t "$target" "$ps_command"
    else
        echo "Unsupported OS: $os_type"
    fi
}

# Main build function
stations_build () {
    echo -e "${YELLOW}Building on VMs...${NC}"
    for s in "${sorted_stations[@]}"; do
        IFS=' ' read -r vm_id os_type os_name <<< "${stations[$s]}"
        if build_on_target "$s" "$os_type"; then
            echo -e "${GREEN}Success building on $s${NC}"
        else
            echo -e "${RED}Error building on $s${NC}"
        fi
    done
    echo -e "${YELLOW}Building on hosts...${NC}"
    for s in "${sorted_hosts[@]}"; do
        IFS=' ' read -r os_type os_name <<< "${hosts[$s]}"
        if build_on_target "$s" "$os_type"; then
            echo -e "${GREEN}Success building on $s${NC}"
        else
            echo -e "${RED}Error building on $s${NC}"
        fi
    done
}

# Converts a string to lowercase and replaces spaces with dashes
url_path() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/-/g'
}

# Helper function to download build from a target (VM or host)
download_from_target() {
    # Uses external variable defined in config/global.cfg:
    # - release_dir: Directory where built application packages will be stored locally
    # - release_url_paths: "yes" = convert name to lowercase and replace spaces with dashes    
    # - build_dir: Default directory for storing build artifacts on remote machines

    local s=$1         # Target (user@ip)
    local os_type=$2   # OS type (lin, win)
    local os_name=$3   # OS name

    echo -e "${YELLOW}:: Download '$os_name' from $s${NC}"

    local dir_app_name
    local dir_app_version
    local dir_os_name

    # Format app name and version for URL compatibility if requested
    if [[ "$release_url_paths" == "yes" ]]; then
        dir_app_name=$(url_path "$app_name")
        dir_app_version=$(url_path "$app_version")
        dir_os_name=$(url_path "$os_name")
    else
        dir_app_name="$app_name"
        dir_app_version="$app_version"
        dir_os_name="$os_name"
    fi

    local download_dir="$release_dir/$dir_app_name/$dir_app_version/$dir_os_name"

    rm -rf "$download_dir"
    mkdir --parents "$download_dir"

    local source_dir="$build_dir/$app_name/$app_version/$release_dir"

    if [[ "$os_type" == "lin" ]]; then
        if [ "$(ssh $s ls -A $source_dir)" ]; then
            echo "info: get files"
            scp -r $s:"${source_dir}/*" "${download_dir}"
            echo "info: set permissions to 775"
            chmod -R 775 "$download_dir"
        fi
    elif [[ "$os_type" == "win" ]]; then
        if ssh $s "cmd.exe /c if exist \"$source_dir\" (exit 0) else (exit 1)" ; then
            echo "info: get files"
            scp -r "$s:$source_dir/*" "${download_dir}"
            echo "info: set permissions to 775"
            chmod -R 775 "$download_dir"
        fi
    else
        echo -e "${RED}Unsupported OS: $os_type${NC}"
        return 1
    fi

    # Convert file and folder names to lowercase if required
    if [[ "$release_url_paths" == "yes" && -d "$download_dir" ]]; then
        echo "info: converting filenames to lowercase"

        find "$download_dir" -depth | while IFS= read -r path; do
            dir=$(dirname "$path")
            base=$(basename "$path")
            lowerbase=$(echo "$base" | tr '[:upper:]' '[:lower:]')

            if [[ "$base" != "$lowerbase" ]]; then
                mv -T "$path" "$dir/$lowerbase"
            fi
        done
    fi
}

# Main download function
stations_download () {
    for s in "${sorted_stations[@]}"; do
        IFS=' ' read -r vm_id os_type os_name <<< "${stations[$s]}"
        download_from_target "$s" "$os_type" "$os_name" || echo "Error downloading from $s"
    done
    for s in "${sorted_hosts[@]}"; do
        IFS=' ' read -r os_type os_name <<< "${hosts[$s]}"
        download_from_target "$s" "$os_type" "$os_name" || echo "Error downloading from $s"
    done
}

# Run remote command (quiet wrapper)
export_sshq() {
    local cmd=$1
    ssh -q "$export_target" "bash -lc '$cmd'"
}

# Run remote command with TTY (for pinentry/passphrase cases)
export_sshtty() {
    local cmd=$1
    ssh -t "$export_target" "bash -lc '$cmd'"
}

# Resolve app/version directories (url-path aware)
export_resolve_paths() {
    if [[ "$release_url_paths" == "yes" ]]; then
        export_dir_app_name=$(url_path "$app_name")
        export_dir_app_version=$(url_path "$app_version")
    else
        export_dir_app_name="$app_name"
        export_dir_app_version="$app_version"
    fi

    export_local_src_dir="$release_dir/$export_dir_app_name/$export_dir_app_version"
    export_remote_release_dir="$export_dir/$export_dir_app_name/$export_dir_app_version"
}

# Upload local release dir to remote
export_upload_release_dir() {
    echo "info: mirror directory to $export_target:$export_remote_release_dir"

    # Ensure remote target exists
    if ! export_sshq "set -e; mkdir -p \"$export_remote_release_dir\""; then
        echo -e "${RED}Error: remote mkdir failed.${NC}"
        return 1
    fi

    # Prefer rsync for incremental "mirror" behavior (overwrite changed only)
    if command -v rsync >/dev/null 2>&1; then
        if ! rsync -a --partial --delete --info=stats2,progress2 -e ssh \
            "$export_local_src_dir"/ "$export_target:$export_remote_release_dir/"; then
            echo -e "${RED}Error: rsync upload failed.${NC}"
            return 1
        fi
        return 0
    fi

    # Fallback: scp (overwrites, but cannot do incremental diff)
    echo -e "${YELLOW}warn: rsync not found locally, using scp -r fallback (less efficient).${NC}"
    if ! scp -r "$export_local_src_dir"/* "$export_target:$export_remote_release_dir/"; then
        echo -e "${RED}Error: scp upload failed.${NC}"
        return 1
    fi

    return 0
}

# Upload export.sh to target (temporary)
export_upload_remote_script() {
    local local_script="./export.sh"
    local remote_script="/tmp/farm_export.sh"

    if [[ ! -f "$local_script" ]]; then
        echo -e "${RED}Error: export.sh not found next to farm.sh${NC}"
        return 1
    fi

    echo "info: upload export.sh to $export_target:$remote_script"
    if ! scp "$local_script" "$export_target:$remote_script"; then
        echo -e "${RED}Error: export.sh upload failed.${NC}"
        return 1
    fi

    # ensure executable
    if ! export_sshq "set -e; chmod +x \"$remote_script\""; then
        echo -e "${RED}Error: remote chmod export.sh failed.${NC}"
        return 1
    fi

    export_remote_script_path="$remote_script"
    return 0
}

# Run remote export post-process via export.sh
export_run_remote_postprocess() {
    local tty="no"
    [[ "$export_sign_rpms" == "yes" ]] && tty="yes"

    # Validate values that will be injected into remote shell
    for v in \
        "$export_remote_release_dir" \
        "$export_dir" \
        "$export_url_prefix" \
        "$export_chmod" \
        "$export_chown" \
        "$export_gpg_key_id"
    do
        if [[ "$v" == *$'\n'* || "$v" == *"'"* ]]; then
            echo -e "${RED}Error: invalid characters in export config (newline or single quote).${NC}"
            return 1
        fi
    done

    local envs=""
    envs+="EXPORT_RELEASE_DIR=\"$export_remote_release_dir\" "
    envs+="EXPORT_ROOT_DIR=\"$export_dir\" "
    envs+="EXPORT_URL_PREFIX=\"$export_url_prefix\" "
    envs+="EXPORT_SIGN_RPMS=\"$export_sign_rpms\" "
    envs+="EXPORT_SHA256=\"$export_generate_sha256\" "
    envs+="EXPORT_INDEX=\"$export_generate_index\" "
    envs+="EXPORT_CHMOD=\"$export_chmod\" "
    envs+="EXPORT_CHOWN=\"$export_chown\" "
    envs+="EXPORT_GPG_KEY_ID=\"$export_gpg_key_id\" "

    echo "info: remote post-process (export.sh)"

    if [[ "$tty" == "yes" ]]; then
        if ! export_sshtty "set -e; $envs \"$export_remote_script_path\""; then
            echo -e "${RED}Error: remote export.sh failed.${NC}"
            return 1
        fi
    else
        if ! export_sshq "set -e; $envs \"$export_remote_script_path\""; then
            echo -e "${RED}Error: remote export.sh failed.${NC}"
            return 1
        fi
    fi

    return 0
}

# Remove temporary export script from target
export_cleanup_remote_script() {
    if [[ -n "$export_remote_script_path" ]]; then
        export_sshq "rm -f \"$export_remote_script_path\"" >/dev/null 2>&1 || true
    fi
}

# Export release to remote target and run signing + sha256 there
export_release() {
    echo -e "${YELLOW}:: Export release (remote sign + sha256).${NC}"

    # Uses external variables defined in config/global.cfg:
    # - release_dir
    # - release_url_paths
    # - export_gpg_key_id
    # - export_target
    # - export_dir
    # - export_sign_rpms
    # - export_generate_sha256
    # - export_chmod
    # - export_chown
    # - export_clean_remote

    export_remote_script_path=""

    if [[ -z "$export_target" || -z "$export_dir" ]]; then
        echo -e "${RED}Error: export_target/export_dir not set. Define it in config/global.cfg${NC}"
        return 0
    fi

    export_resolve_paths

    if [[ ! -d "$export_local_src_dir" ]]; then
        echo -e "${YELLOW}No release directory found for $app_name $app_version (looked in $export_local_src_dir)${NC}"
        return 0
    fi

    echo "info: local source: $export_local_src_dir"
    echo "info: remote target: $export_remote_release_dir"

    if ! export_upload_release_dir; then
        return 1
    fi

    # Validate remote dir exists (quick)
    if ! export_sshq "set -e; d=\"$export_remote_release_dir\"; [[ -d \"\$d\" ]] || { echo \"Error: export dir not found: \$d\"; exit 1; }"; then
        echo -e "${RED}Error: remote validation failed.${NC}"
        return 1
    fi

    if ! export_upload_remote_script; then
        return 1
    fi

    trap 'export_cleanup_remote_script' EXIT INT TERM

    # Always cleanup remote helper script
    if ! export_run_remote_postprocess; then
        export_cleanup_remote_script
        return 1
    fi

    export_cleanup_remote_script

    trap - EXIT INT TERM

    echo -e "${GREEN}:: Export completed.${NC}"
}

# Main menu
show_menu() {
    echo ""
    echo "Action ?"
    echo "1) Check"
    echo "2) Dependencies"
    echo "3) Clean"
    echo "4) Build"
    echo "5) Download $( [ "$release_url_paths" == "yes" ] && echo "(URL paths)" )"
    echo "6) Export"

    # Show VM options only if Proxmox is configured
    if [[ -n "$proxmox_server" && -n "$proxmox_user" ]]; then
        echo "7) VMs Status"
        echo "8) VMs Start"
        echo "9) VMs Stop"
    fi

    echo "q) Quit"
}

while true; do
    show_menu  # Show the menu at the beginning of the loop
    read -p "#? " choice

    case $choice in
        1) check_ssh_connection && check_conditions ;;
        2) install_dependencies ;;
        3) select_application && clean_all ;;
        4) select_application && stations_upload && stations_build ;;
        5) select_application && stations_download ;;
        6) select_application && export_release ;;
        
        # Execute VM-related actions only if Proxmox is configured
        7) [[ -n "$proxmox_server" && -n "$proxmox_user" ]] && vm_status ;;
        8) [[ -n "$proxmox_server" && -n "$proxmox_user" ]] && vm_start ;; 
        9) [[ -n "$proxmox_server" && -n "$proxmox_user" ]] && vm_stop ;; 
        
        q) exit 0 ;;
        *) echo -e "${RED}Invalid choice${NC}" ;;
    esac
done
