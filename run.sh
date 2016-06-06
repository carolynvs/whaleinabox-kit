#!/bin/bash
# Having trouble with this script? Use ./run.sh debug to see the logs
set -euo pipefail

# Parse command-line arguments
DEBUG=${1:-false}

# Figure out the current directory
__SCRIPT_SOURCE="$_"
if [ -n "$BASH_SOURCE" ]; then
  __SCRIPT_SOURCE="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "${__SCRIPT_SOURCE:-$0}")" > /dev/null && \pwd)"
unset __SCRIPT_SOURCE 2> /dev/null

# Load secret credentials
source $SCRIPT_DIR/secrets.sh

# Load settings
source $SCRIPT_DIR/settings.sh

# Connect to the Carina cluster
eval $(carina env $JUPYTERHUB_CLUSTER)

# Load docker
# Temporarily disable strict mode for a sec, as dvm's multi-shell support magic doesn't work with it
if ! type dvm &> /dev/null; then
  set +u; source ~/.dvm/dvm.sh; set -u
fi
dvm use &> /dev/null

# Cleanup old containers
docker rm -f nginx jupyterhub letsencrypt web &> /dev/null || true

# Build and publish the custom Docker image used by the user's Jupyter server
docker build -f $SCRIPT_DIR/Dockerfile-jupyter -t $JUPYTER_IMAGE $SCRIPT_DIR
docker push $JUPYTER_IMAGE

# Do all the things with a sidecar of stuff
docker-compose -f $SCRIPT_DIR/docker-compose.yml build
docker-compose -f $SCRIPT_DIR/docker-compose.yml up -d
if [ $DEBUG = "debug" ]; then
  echo "********************************************************"
  echo "Tailing the whaleinabox Docker logs"
  echo "Everything is ready when you see \"Whale in a Box Initialization Complete!\""
  echo "Use CTRL+C to quit."
  echo "********************************************************"
  docker-compose -f $SCRIPT_DIR/docker-compose.yml logs -f
else
  echo "********************************************************"
  echo "Waiting for whaleinabox to complete initialization..."
  echo "********************************************************"
  ( docker-compose -f $SCRIPT_DIR/docker-compose.yml logs -f & ) | grep -q "Whale in a Box Initialization Complete"
  if type open &> /dev/null; then
    open https://$JUPYTERHUB_DOMAIN
  fi
  echo "You site is now available at https://$JUPYTERHUB_DOMAIN"
fi
