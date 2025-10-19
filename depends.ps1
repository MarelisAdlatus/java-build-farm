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

# Set parameters
$installDir = '.build'

# Applications to download and install
$apps = @(
    @{
        'name' = '7-Zip'
        'url' = 'https://www.7-zip.org/a/'
        'file' = '7z2500-x64.exe'
        'type' = 'exe' 
        'params' = '/S'
        'exe' = 'C:\\Program Files\\7-Zip\\7z.exe'
        'username' = ''
        'password' = ''
        'postinstall' = ''
    },
    @{
        'name' = 'Java JDK 21'
        'url' = 'https://download.oracle.com/java/21/latest/'
        'file' = 'jdk-21_windows-x64_bin.exe'
        'type' = 'exe' 
        'params' = '/s'
        'exe' = 'C:\\Program Files\\Java\\jdk-21\\bin\\java.exe'
        'username' = ''
        'password' = ''
        'postinstall' = ''
    },
    @{
        'name' = 'Inno Setup'
        'url' = 'https://jrsoftware.org/download.php/'
        'file' = 'innosetup-6.4.3.exe'
        'type' = 'exe' 
        'params' = '/VERYSILENT /NORESTART'
        'exe' = 'C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe'
        'username' = ''
        'password' = ''
        'postinstall' = ''
    }
)

# Delete installation directory if it exists
if (Test-Path $installDir) {
    Write-Host "Deleting existing installation directory..." 
    try {
        Remove-Item -Recurse -Force $installDir
        Write-Host "Installation directory deleted." 
    }
    catch {
        Write-Error "Error deleting installation directory." 
    }
}

# Create installation directory
Write-Host "Creating installation directory..." 
try {
    New-Item -ItemType Directory -Path $installDir | Out-Null
    Write-Host "Installation directory created." 
}
catch {
    Write-Error "Error creating installation directory." 
}

# Download and install applications
foreach ($app in $apps) {
    $appName = $app['name']
    $appUrl = $app['url'] + $app['file']
    $installerPath = Join-Path $installDir $app['file']
    $installerType = $app['type'] 
    $installParams = $app['params']
    $username = $app['username']
    $password = $app['password']
    $postinstall = $app['postinstall']

    if (-not (Test-Path $app['exe'])) { # Check if application is already installed
        # Download the installer file
        try {
            Write-Host "Downloading $appName..." 
            $wc = New-Object System.Net.WebClient
            # Create credentials only if username or password is provided
            if (![string]::IsNullOrEmpty($username) -or ![string]::IsNullOrEmpty($password)) {
                $wc.Credentials = New-Object System.Net.NetworkCredential($username, $password)
            } 
            $wc.DownloadFile($appUrl, $installerPath)
            Write-Host "Download of $appName completed." 
        }
        catch {
            Write-Error "Error downloading $appName. Download path: $appUrl"
        }

        # Install the application
        Write-Host "Installing $appName..."
        try {
            if ($installerType -eq 'msi') {
                Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$installerPath`" $installParams" -Wait -NoNewWindow
            } else {
                Start-Process -FilePath $installerPath -ArgumentList $installParams -Wait -NoNewWindow
            }
            Write-Host "Installation of $appName completed."

            # Execute post-installation command if defined
            if (![string]::IsNullOrEmpty($postinstall)) {
                Write-Host "Executing post-installation command for $appName..."
                Invoke-Expression $postinstall
                Write-Host "Post-installation command executed."
            }
        }
        catch {
            Write-Error "Error installing $appName."
        }
    }
    else {
        Write-Host "$appName is already installed. Skipping..." 
    }
}
