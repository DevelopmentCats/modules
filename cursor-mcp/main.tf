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
        GITHUB_TOKEN = var.github_token != "" ? var.github_token : "$${GITHUB_TOKEN}"
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
  
  # Local MCP config template content (previously in local_mcp_config.tpl)
  local_mcp_config_template = <<-EOT
{
  "mcpServers": {
    %{ for server_key, server in PROXIED_SERVERS ~}
    "${server.name}": {
      "transport": "sse",
      "url": "http://localhost:${PROXY_PORTS[server_key]}/sse"
    }%{ if server_key != keys(PROXIED_SERVERS)[length(keys(PROXIED_SERVERS)) - 1] },%{ endif }
    %{ endfor ~}
  }
}
EOT
}

# Script to set up and run MCP servers
resource "coder_script" "mcp-servers" {
  count        = length(local.all_servers) > 0 ? 1 : 0
  agent_id     = var.agent_id
  display_name = "MCP Servers"
  icon         = "/icon/cursor.svg"
  script       = templatefile("${path.module}/run.sh", {
    MCP_SERVERS    = jsonencode(local.all_servers)
    MCP_CONFIG_DIR = var.mcp_config_dir
    MCP_PORT_START = var.mcp_port_start
    LOG_PATH       = var.log_path
    SERVER_PORTS   = jsonencode(local.server_ports)
    ENABLE_PROXY   = var.enable_proxy
  })
  run_on_start = true
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

# Generate MCP configuration for the local Cursor client
resource "local_file" "cursor_mcp_config" {
  count    = var.enable_proxy && length(local.all_servers) > 0 ? 1 : 0
  content  = templatefile(
    # Use the inline template instead of external file
    local.local_mcp_config_template, 
    {
      PROXIED_SERVERS = local.all_servers
      PROXY_PORTS     = local.proxy_ports
    }
  )
  filename = "${path.module}/cursor_mcp_config.json"
}

output "mcp_servers_configured" {
  value       = keys(local.all_servers)
  description = "List of configured MCP servers."
}

output "proxy_instructions" {
  value = var.enable_proxy && length(local.all_servers) > 0 ? "MCP servers are being proxied. Add the following to your local Cursor MCP configuration (~/.cursor/mcp.json):\n\nPlease copy the configuration from: ${path.module}/cursor_mcp_config.json" : null
}
