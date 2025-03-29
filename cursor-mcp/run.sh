#!/usr/bin/env bash

set -e  # Exit immediately if a command exits with a non-zero status

BOLD='\033[0;1m'
RESET='\033[0m'
MCP_SERVERS='${MCP_SERVERS}'
MCP_CONFIG_DIR="${MCP_CONFIG_DIR}"
MCP_PORT_START=${MCP_PORT_START}
LOG_PATH="${LOG_PATH}"
SERVER_PORTS='${SERVER_PORTS}'
ENABLE_PROXY=${ENABLE_PROXY}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v yum &> /dev/null; then
    sudo yum install -y jq
  elif command -v dnf &> /dev/null; then
    sudo dnf install -y jq
  elif command -v apk &> /dev/null; then
    apk add --no-cache jq
  else
    echo "Error: Could not install jq. Please install it manually."
    exit 1
  fi
fi

# Check if proxy is enabled and install mcp-remote if needed
if [ "$ENABLE_PROXY" = true ]; then
  echo "🔄 Setting up MCP proxying..."
  
  # Check if Node.js and npm are installed
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Installing Node.js and npm for MCP proxying..."
    if command -v apt-get &> /dev/null; then
      sudo apt-get update && sudo apt-get install -y nodejs npm
    elif command -v yum &> /dev/null; then
      sudo yum install -y nodejs npm
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y nodejs npm
    elif command -v apk &> /dev/null; then
      apk add --no-cache nodejs npm
    else
      echo "Error: Could not install Node.js and npm. Please install them manually."
      exit 1
    fi
  fi
  
  # Install mcp-remote globally if not already installed
  if ! command -v mcp-remote &> /dev/null; then
    echo "Installing mcp-remote for MCP proxying..."
    npm install -g mcp-remote
  fi
fi

# Expand the config dir path if it contains ~
MCP_CONFIG_DIR="${MCP_CONFIG_DIR/#\~/$HOME}"
LOG_PATH="${LOG_PATH/#\~/$HOME}"

# Ensure the MCP config directory exists
mkdir -p "$MCP_CONFIG_DIR" || {
  echo "Error: Failed to create directory $MCP_CONFIG_DIR"
  exit 1
}

echo "🔧 Setting up MCP servers..."

# Validate the MCP servers JSON
if ! echo "$MCP_SERVERS" | jq empty 2>/dev/null; then
  echo "Error: Invalid MCP servers configuration. Please check your Terraform configuration."
  exit 1
fi

# Parse the MCP servers JSON
SERVERS=$(echo "$MCP_SERVERS" | jq -r 'keys[]')

if [ -z "$SERVERS" ]; then
  echo "Warning: No MCP servers configured."
  exit 0
fi

# Create the mcp.json configuration file
echo "📝 Creating MCP configuration file at $MCP_CONFIG_DIR/mcp.json"
echo '{
  "mcpServers": {
' > "$MCP_CONFIG_DIR/mcp.json" || {
  echo "Error: Failed to write to $MCP_CONFIG_DIR/mcp.json"
  exit 1
}

# Process each server
for SERVER_KEY in $SERVERS; do
  SERVER_NAME=$(echo "$MCP_SERVERS" | jq -r ".[\"$SERVER_KEY\"].name")
  SERVER_COMMAND=$(echo "$MCP_SERVERS" | jq -r ".[\"$SERVER_KEY\"].command")
  SERVER_ARGS=$(echo "$MCP_SERVERS" | jq -r ".[\"$SERVER_KEY\"].args | join(\" \")")
  SERVER_ENV=$(echo "$MCP_SERVERS" | jq -r ".[\"$SERVER_KEY\"].env")
  SERVER_PORT=$(echo "$SERVER_PORTS" | jq -r ".[\"$SERVER_KEY\"]")
  
  # Validate required fields
  if [ -z "$SERVER_NAME" ] || [ -z "$SERVER_COMMAND" ]; then
    echo "Error: Server $SERVER_KEY is missing required fields (name or command)"
    exit 1
  fi
  
  # Add server to the mcp.json file
  echo "    \"$SERVER_NAME\": {
      \"command\": \"$SERVER_COMMAND\",
      \"args\": $(echo "$MCP_SERVERS" | jq ".[\"$SERVER_KEY\"].args"),
      \"env\": $(echo "$SERVER_ENV")
    }$([ "$SERVER_KEY" = "$(echo "$SERVERS" | tail -n1)" ] && echo "" || echo ",")" >> "$MCP_CONFIG_DIR/mcp.json" || {
    echo "Error: Failed to write server configuration for $SERVER_NAME"
    exit 1
  }
  
  # If proxy is enabled, create a proxy server script for this MCP server
  if [ "$ENABLE_PROXY" = true ]; then
    echo "🔄 Setting up proxy for MCP server: $SERVER_NAME on port $SERVER_PORT"
    
    # Create a startup script for the proxy service
    PROXY_SCRIPT="$HOME/mcp-proxy-$SERVER_NAME.sh"
    cat > "$PROXY_SCRIPT" << EOL
#!/bin/bash
# Start the MCP server on port $SERVER_PORT with proxying support
cd \$HOME
exec mcp-remote serve --port $SERVER_PORT "$SERVER_COMMAND $(echo "$MCP_SERVERS" | jq -r ".[\"$SERVER_KEY\"].args | join(\" \")")"
EOL
    
    chmod +x "$PROXY_SCRIPT"
    
    # Start the proxy in the background
    echo "🚀 Starting proxy server for $SERVER_NAME..."
    nohup "$PROXY_SCRIPT" > "$HOME/mcp-proxy-$SERVER_NAME.log" 2>&1 &
  fi
done

# Close the JSON object
echo '  }
}' >> "$MCP_CONFIG_DIR/mcp.json" || {
  echo "Error: Failed to finalize the MCP configuration file"
  exit 1
}

# Validate the generated JSON file
if ! jq empty "$MCP_CONFIG_DIR/mcp.json" 2>/dev/null; then
  echo "Error: Generated an invalid MCP configuration file. Please check your Terraform configuration."
  exit 1
fi

echo "✅ MCP configuration complete"
if [ "$ENABLE_PROXY" = true ]; then
  echo "✅ MCP proxying set up. Connect your local Cursor to these proxied servers using the provided configuration."
else
  echo "👷 MCP servers are configured. Cursor will automatically connect to them when launched."
fi
echo "📋 Check logs at $LOG_PATH for details"
