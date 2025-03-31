#!/usr/bin/env bash

BOLD='\033[0;1m'
RESET='\033[0m'

# These variables come from Terraform
MCP_SERVERS='${MCP_SERVERS}'
MCP_CONFIG_DIR="${MCP_CONFIG_DIR}"
LOG_PATH="${LOG_PATH}"
ENABLE_PROXY=${ENABLE_PROXY}

# Convert ~ to $HOME if needed
MCP_CONFIG_DIR="${MCP_CONFIG_DIR/#\~/$HOME}"
LOG_PATH="${LOG_PATH/#\~/$HOME}"

printf "$${BOLD}Setting up Cursor MCP Servers...$${RESET}\n\n"

# Create the config directory
mkdir -p "$MCP_CONFIG_DIR"

# Parse the servers to show info
SERVERS=$(echo "$MCP_SERVERS" | jq -r 'keys[]')

if [ -z "$SERVERS" ]; then
  printf "No MCP servers configured.\n"
else
  printf "Configuring the following MCP servers:\n"
  for SERVER_KEY in $SERVERS; do
    SERVER_NAME=$(echo "$MCP_SERVERS" | jq -r ".[\"$SERVER_KEY\"].name")
    printf "  - %s\n" "$SERVER_NAME"
  done
  
  if [ "$ENABLE_PROXY" = true ]; then
    printf "\n$${BOLD}Proxying is enabled$${RESET}\n"
    printf "MCP servers will be accessible from your local Cursor application.\n"
  else
    printf "\n$${BOLD}Proxying is disabled$${RESET}\n"
    printf "MCP servers will only be available within this workspace.\n"
  fi
fi

printf "\nCheck logs at %s\n" "$LOG_PATH"
