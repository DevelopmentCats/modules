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

# Install MCP server dependencies and tools
resource "coder_script" "setup_mcp_environment" {
  agent_id     = var.agent_id
  display_name = "Setup MCP Environment"
  run_on_start = true
  script       = <<-EOT
#!/bin/bash
set -e

echo "===== Setting up MCP Environment ====="

# Create necessary directories
mkdir -p "${var.mcp_config_dir}"
mkdir -p "$HOME/.cursor/bin"

# Also create .cursor directory in the project path if filesystem is enabled
if [ "${var.enable_filesystem ? "true" : "false"}" = "true" ]; then
  PROJECT_DIR="${var.filesystem_path}"
  echo "Creating .cursor directory in project: $PROJECT_DIR"
  mkdir -p "$PROJECT_DIR/.cursor"
  
  # Create MCP configuration in the project directory
  cat > "$PROJECT_DIR/.cursor/mcp.json" << 'EOF'
${local.mcp_workspace_config}
EOF
  echo "Created MCP config at $PROJECT_DIR/.cursor/mcp.json"
fi

# Also create the config in the standard location as a backup
cat > "${var.mcp_config_dir}/mcp.json" << 'EOF'
${local.mcp_workspace_config}
EOF

# Install mcp-remote if needed (for proxying)
if [ "${var.enable_proxy ? "true" : "false"}" = "true" ]; then
  echo "Installing mcp-remote for proxying..."
  cd $HOME
  npm install mcp-remote --no-fund --silent

  # Create a wrapper script
  cat > $HOME/.cursor/bin/mcp-remote << 'EOF'
#!/bin/bash
NODE_PATH=$HOME/node_modules node $HOME/node_modules/mcp-remote/bin/mcp-remote.js "$@"
EOF
  chmod +x $HOME/.cursor/bin/mcp-remote

  # Add to PATH if not already there
  if ! grep -q "$HOME/.cursor/bin" $HOME/.bashrc; then
    echo 'export PATH="$HOME/.cursor/bin:$PATH"' >> $HOME/.bashrc
  fi
  export PATH="$HOME/.cursor/bin:$PATH"
fi

echo "✅ MCP environment setup complete"
EOT
}

# Create and start MCP servers
resource "coder_script" "start_mcp_servers" {
  agent_id     = var.agent_id
  display_name = "Start MCP Servers"
  run_on_start = true
  icon         = "/icon/cursor.svg" 
  script       = <<-EOT
#!/bin/bash
set -e

export PATH="$HOME/.cursor/bin:$PATH"
echo "===== Starting MCP Servers ====="

# Create proxy scripts if proxying is enabled
if [ "${var.enable_proxy ? "true" : "false"}" = "true" ]; then
  ${join("\n  ", [
    for server_key, server in local.all_servers : 
    "cat > \"$HOME/.cursor/mcp-proxy-${server.name}.sh\" << 'EOF'\n#!/bin/bash\ncd $HOME\nexec mcp-remote serve --port ${local.server_ports[server_key]} \"${server.command} ${join(" ", server.args)}\"\nEOF\nchmod +x \"$HOME/.cursor/mcp-proxy-${server.name}.sh\""
  ])}
  
  # Start proxy servers
  ${join("\n  ", [
    for server_key, server in local.all_servers :
    "nohup $HOME/.cursor/mcp-proxy-${server.name}.sh > $HOME/.cursor/mcp-proxy-${server.name}.log 2>&1 &"
  ])}
else
  # Start direct MCP servers without proxying
  ${join("\n  ", [
    for server_key, server in local.all_servers :
    "nohup ${server.command} ${join(" ", server.args)} > $HOME/.cursor/${server.name}-mcp.log 2>&1 &"
  ])}
fi

echo "✅ MCP servers started:"
${join("\n", [
  for server_key, server in local.all_servers :
  "echo \"- ${server.name} (port ${local.server_ports[server_key]})\""
])}

echo ""
if [ "${var.enable_proxy ? "true" : "false"}" = "true" ]; then
  echo "MCP servers are being proxied and will be accessible from your local Cursor."
  echo "Add the following configuration to your local Cursor:"
  echo ""
  echo 'cat > ~/.cursor/mcp.json << EOF'
  echo '${replace(local.local_mcp_config_template, "$", "\\$")}'
  echo 'EOF'
else
  echo "MCP servers are running locally within the workspace."
fi

echo ""
echo "MCP server logs can be found in $HOME/.cursor/*.log"
EOT
  depends_on = [coder_script.setup_mcp_environment]
}

output "mcp_servers_configured" {
  value = sort(keys(local.all_servers))
  description = "List of configured MCP servers."
}

output "proxy_instructions" {
  value = var.enable_proxy && length(local.all_servers) > 0 ? "MCP servers are being proxied. Add the configuration shown in the 'Start MCP Servers' script output to your local Cursor MCP configuration (~/.cursor/mcp.json)" : null
}
