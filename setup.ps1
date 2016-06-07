$ErrorActionPreference = "Stop"

# Load secret credentials
. $PSScriptRoot\secrets.ps1

# Load settings
. $PSScriptRoot\settings.ps1

Write-Output "Performing one-time setup"

# Check for prerequisites
if($PSVersionTable -eq $null -or $PSVersionTable.PSVersion.Major -lt 3){
  Write-Output "Whale in a Box requires PowerShell version 3 or higher."
  Exit 1
}

$webClient = New-Object net.webclient

# Install carina
if((Get-Command carina.exe -ErrorAction SilentlyContinue) -eq $null -and !(Test-Path("$PSScriptRoot\bin\carina.exe"))){
  Write-Output "Installing the carina cli"
  mkdir $PSScriptRoot\bin -ErrorAction SilentlyContinue >$null
  $webClient.DownloadFile("https://download.getcarina.com/carina/latest/Windows/x86_64/carina.exe", "$PSScriptRoot\bin\carina.exe")
}

# Install dvm
if((Get-Command dvm -ErrorAction SilentlyContinue) -eq $null){
  if(Test-Path("$env:UserProfile\.dvm\dvm.ps1")){
    Write-Output "Loading dvm"
    . $env:UserProfile\.dvm\dvm.ps1
  }
  else{
    Write-Output "Installing dvm"
    Invoke-WebRequest https://download.getcarina.com/dvm/latest/install.ps1 -UseBasicParsing | Invoke-Expression
    . $env:UserProfile\.dvm\dvm.ps1
  }
}

# Install docker-compose
if((Get-Command "docker-compose.exe" -ErrorAction SilentlyContinue) -eq $null -and !(Test-Path("$PSScriptRoot\bin\carina.exe"))){
  Write-Output "Installing docker-compose"
  mkdir $PSScriptRoot\bin -ErrorAction SilentlyContinue >$null
  $webClient.DownloadFile("https://github.com/docker/compose/releases/download/1.7.1/docker-compose-Windows-x86_64.exe", "$PSScriptRoot\bin\docker-compose.exe")
}

# Add downloaded tools to path
$env:PATH="$PSScriptRoot\bin;$env:PATH"

# Create a cluster on Carina
if(((carina get $env:JUPYTERHUB_CLUSTER) | Out-String) -notlike "*$env:JUPYTERHUB_CLUSTER*"){
  Write-Output "Creating a Carina cluster..."
  carina create --wait $env:JUPYTERHUB_CLUSTER
}
carina env $env:JUPYTERHUB_CLUSTER --shell powershell | Invoke-Expression

# Workaround quirk in Carina
$env:DOCKER_VERSION=$env:DOCKER_VERSION.trim()

# Use the right docker client for the cluster
dvm use >$null

# Login to Docker Hub
docker login

# Print out the IP address of the cluster
Write-Output "`n##########`n"
Write-Output "All done!"
Write-Output "If you are running JupyterHub with a domain name, add an A record to your DNS now pointing to the IP address below:"
Write-Output "##########`n"
docker run --rm --net=host -e constraint:node==*-n1 racknet/ip public ipv4
