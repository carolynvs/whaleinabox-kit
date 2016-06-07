param (
    [bool]$debug = $false
 )

# Having trouble with this script? Use .\run.ps1 -debug=$true to see the logs

# Load secret credentials
. $PSScriptRoot\secrets.ps1

# Load settings
. $PSScriptRoot\settings.ps1

# Add downloaded tools to path
$env:PATH="$PSScriptRoot\bin;$env:PATH"

# Connect to the Carina cluster
carina env $env:JUPYTERHUB_CLUSTER --shell powershell | Invoke-Expression

# Workaround quirk in Carina
$env:DOCKER_VERSION=$env:DOCKER_VERSION.trim()

# Load docker
if((Get-Command dvm -ErrorAction SilentlyContinue) -eq $null) {
  . $env:UserProfile\.dvm\dvm.ps1
}
dvm use >$null

# Cleanup old containers
docker rm -f nginx jupyterhub letsencrypt web *>$null

# Build and publish the custom Docker image used by the user's Jupyter server
docker build -f $PSScriptRoot/Dockerfile-jupyter -t $env:JUPYTER_IMAGE $PSScriptRoot
docker push $env:JUPYTER_IMAGE

# Do all the things with a sidecar of stuff
docker-compose -f $PSScriptRoot/docker-compose.yml build
docker-compose -f $PSScriptRoot/docker-compose.yml up -d
if($debug) {
  Write-Output "********************************************************"
  Write-Output "Tailing the whaleinabox Docker logs"
  Write-Output "Everything is ready when you see `"Whale in a Box Initialization Complete!`""
  Write-Output "Use CTRL+C to quit."
  Write-Output "********************************************************"
  docker-compose -f $PSScriptRoot/docker-compose.yml logs -f
}
else {
  echo "********************************************************"
  echo "Waiting for whaleinabox to complete initialization..."
  echo "********************************************************"
  docker-compose -f docker-compose.yml logs -f | Out-String -Stream | Select-String "Initialization Complete"
  start https://$env:JUPYTERHUB_DOMAIN
  echo "You site is now available at https://$env:JUPYTERHUB_DOMAIN"
}
