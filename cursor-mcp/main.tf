terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.23"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

# Simplified server enablement variables
variable "enable_github" {
  type        = bool
  description = "Enable the GitHub MCP server for GitHub repository operations."
  default     = false
}

variable "github_token" {
  type        = string
  description = "GitHub token for the GitHub MCP server. If not provided, will try to use GITHUB_TOKEN environment variable."
  default     = ""
  sensitive   = true
}

variable "enable_filesystem" {
  type        = bool
  description = "Enable the Filesystem MCP server for file operations."
  default     = false
}

variable "filesystem_path" {
  type        = string
  description = "Path for the Filesystem MCP server to operate on."
  default     = "/home/coder"
}

variable "enable_weather" {
  type        = bool
  description = "Enable the Weather MCP server for weather information."
  default     = false
}

# Proxy configuration
variable "enable_proxy" {
  type        = bool
  description = "Enable automatic proxying of MCP servers to make them accessible from local Cursor. Highly recommended for remote workspaces."
  default     = true
}

variable "proxy_start_port" {
  type        = number
  description = "Starting port number for proxy forwarding."
  default     = 9100
}

# Advanced configuration - for custom or additional MCP servers
variable "mcp_servers" {
  type = map(object({
    name    = string
    command = string
    args    = list(string)
    env     = map(string)
  }))
  description = "Map of MCP servers to configure. Each server needs a name, command, optional args, and optional env variables."
  default     = {}
}

variable "mcp_config_dir" {
  type        = string
  description = "Directory to store the MCP configuration file in the container."
  default     = "~/.cursor"
}

variable "mcp_port_start" {
  type        = number
  description = "Starting port number for MCP servers using SSE."
  default     = 9000
}

variable "log_path" {
  type        = string
  description = "Path to log MCP server output."
  default     = "~/mcp-servers.log"
}

# Common MCP server templates
locals {
  github_server = var.enable_github ? {
    "github-tools" = {
      name    = "github-tools"
      command = "npx"
      args    = ["-y", "@mcp/github-tools"]
      env     = {
        GITHUB_TOKEN = var.github_token != "" ? var.github_token : "GITHUB_TOKEN_ENV"
      }
    }
  } : {}

  filesystem_server = var.enable_filesystem ? {
    "filesystem" = {
      name    = "filesystem"
      command = "npx"
      args    = ["-y", "@modelcontextprotocol/server-filesystem", var.filesystem_path]
      env     = {}
    }
  } : {}

  weather_server = var.enable_weather ? {
    "weather" = {
      name    = "weather"
      command = "npx"
      args    = ["-y", "@modelcontextprotocol/server-weather"]
      env     = {}
    }
  } : {}

  # Merge pre-configured servers with custom servers
  all_servers = merge(
    local.github_server,
    local.filesystem_server,
    local.weather_server,
    var.mcp_servers
  )
  
  # For use with proxy - create server ports mapping
  server_ports = {
    for idx, key in keys(local.all_servers) :
    key => (var.mcp_port_start + idx)
  }
  
  # Create proxied ports mapping
  proxy_ports = var.enable_proxy ? {
    for idx, key in keys(local.all_servers) :
    key => (var.proxy_start_port + idx)
  } : {}
  
  # Local MCP config template content
  local_mcp_config_template = <<-EOT
{
  "mcpServers": {
    %{ for server_key, server in local.all_servers ~}
    "${server.name}": {
      "transport": "sse",
      "url": "http://localhost:${var.enable_proxy ? local.proxy_ports[server_key] : local.server_ports[server_key]}/sse"
    }%{ if server_key != keys(local.all_servers)[length(keys(local.all_servers)) - 1] },%{ endif }
    %{ endfor ~}
  }
}
EOT

  # MCP workspace config content
  mcp_workspace_config = jsonencode({
    mcpServers = {
      for server_key, server in local.all_servers : 
      server.name => {
        command = server.command
        args    = server.args
        env     = server.env
      }
    }
  })
}

# Set up port forwarding for MCP servers if proxying is enabled
resource "coder_app" "mcp-proxy" {
  for_each     = var.enable_proxy ? local.proxy_ports : {}
  agent_id     = var.agent_id
  slug         = "mcp-${each.key}-proxy"
  display_name = "MCP ${each.key} Proxy"
  url          = "http://localhost:${local.server_ports[each.key]}"
  share        = "owner"
  subdomain    = false
  
  # Hide the proxy app from the dashboard
  icon         = "/emptyicon"
  order        = 999
}

# Create MCP configuration file in the workspace using a script
resource "coder_script" "mcp_json" {
  count        = length(local.all_servers) > 0 ? 1 : 0
  agent_id     = var.agent_id
  display_name = "Create MCP Config"
  run_on_start = true
  script       = <<-EOT
#!/bin/bash
set -e
mkdir -p "${var.mcp_config_dir}"
cat > "${var.mcp_config_dir}/mcp.json" << 'EOF'
${local.mcp_workspace_config}
EOF
echo "MCP configuration created at ${var.mcp_config_dir}/mcp.json"
EOT
}

# Create proxy script files using a single script resource
resource "coder_script" "create_proxy_scripts" {
  count        = var.enable_proxy && length(local.all_servers) > 0 ? 1 : 0
  agent_id     = var.agent_id
  display_name = "Create Proxy Scripts"
  run_on_start = true
  script       = <<-EOT
#!/bin/bash
set -e
${join("\n", [
  for server_key, server in local.all_servers : 
  "cat > \"$HOME/mcp-proxy-${server.name}.sh\" << 'EOF'\n#!/bin/bash\ncd $HOME\nexec mcp-remote serve --port ${local.server_ports[server_key]} \"${server.command} ${join(" ", server.args)}\"\nEOF\nchmod +x \"$HOME/mcp-proxy-${server.name}.sh\""
])}
echo "Created proxy script files for MCP servers"
EOT
}

# Install required dependencies script
resource "coder_script" "install_dependencies" {
  count        = var.enable_proxy && length(local.all_servers) > 0 ? 1 : 0
  agent_id     = var.agent_id
  display_name = "Install MCP Dependencies"
  run_on_start = true
  script       = <<-EOT
#!/bin/bash
set -e

# Installing jq (for JSON processing)
if ! command -v jq >/dev/null; then
  echo "Installing jq..."
  if command -v apt-get >/dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v yum >/dev/null; then
    sudo yum install -y jq
  elif command -v dnf >/dev/null; then
    sudo dnf install -y jq
  elif command -v apk >/dev/null; then
    apk add --no-cache jq
  fi
fi

# Installing Node.js and npm
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Installing Node.js and npm..."
  if command -v apt-get >/dev/null; then
    sudo apt-get update && sudo apt-get install -y nodejs npm
  elif command -v yum >/dev/null; then
    sudo yum install -y nodejs npm
  elif command -v dnf >/dev/null; then
    sudo dnf install -y nodejs npm
  elif command -v apk >/dev/null; then
    apk add --no-cache nodejs npm
  fi
fi

# Installing mcp-remote
if ! command -v mcp-remote >/dev/null; then
  echo "Installing mcp-remote..."
  # Create npm global dir in user's home if it doesn't exist
  mkdir -p $HOME/.npm-global
  # Configure npm to use this directory
  npm config set prefix $HOME/.npm-global
  # Install mcp-remote in user directory
  npm install --prefix=$HOME/.npm-global mcp-remote
  # Add to PATH for this session
  export PATH="$HOME/.npm-global/bin:$PATH"
fi
EOT
}

# Start MCP proxy servers
resource "coder_script" "start_proxies" {
  count        = var.enable_proxy && length(local.all_servers) > 0 ? 1 : 0
  agent_id     = var.agent_id
  display_name = "Start MCP Proxies"
  run_on_start = true
  script       = <<-EOT
#!/bin/bash
set -e

# Start each MCP proxy server
${join("\n", [
  for server_key, server in local.all_servers :
  "nohup /home/coder/mcp-proxy-${server.name}.sh > /home/coder/mcp-proxy-${server.name}.log 2>/dev/null &"
])}

echo "MCP servers started:"
${join("\n", [
  for server_key, server in local.all_servers :
  "echo \"- ${server.name} (port ${local.server_ports[server_key]})\""
])}
EOT
}

# MCP servers information script
resource "coder_script" "mcp-servers" {
  count        = length(local.all_servers) > 0 ? 1 : 0
  agent_id     = var.agent_id
  display_name = "MCP Servers"
  icon         = "/icon/cursor.svg"
  run_on_start = true
  script       = <<-EOT
#!/bin/bash
echo "Setting up Cursor MCP Servers..."
echo ""
echo "MCP_CONFIG_DIR=\"${var.mcp_config_dir}\""
${var.enable_github ? "echo \"GITHUB_TOKEN environment variable is being used\"" : ""}
${var.enable_filesystem ? "echo \"Filesystem path: ${var.filesystem_path}\"" : ""}
echo ""
echo "Configured MCP servers:"
${join("\n", [
  for server_key, server in local.all_servers :
  "echo \"- ${server.name}\""
])}

echo ""
if [ "${var.enable_proxy ? "true" : "false"}" = "true" ]; then
  echo "Proxying is enabled"
  echo "MCP servers will be accessible from your local Cursor application."
else
  echo "Proxying is disabled"
  echo "MCP servers will only be available within this workspace."
fi
EOT
}

# Generate MCP configuration for the local Cursor client
resource "local_file" "cursor_mcp_config" {
  count    = var.enable_proxy && length(local.all_servers) > 0 ? 1 : 0
  content  = local.local_mcp_config_template
  filename = "${path.module}/cursor_mcp_config.json"
}

output "mcp_servers_configured" {
  value = sort(keys(local.all_servers))
  description = "List of configured MCP servers."
}

output "proxy_instructions" {
  value = var.enable_proxy && length(local.all_servers) > 0 ? "MCP servers are being proxied. Add the following to your local Cursor MCP configuration (~/.cursor/mcp.json):\n\nPlease copy the configuration from: ${path.module}/cursor_mcp_config.json" : null
}
