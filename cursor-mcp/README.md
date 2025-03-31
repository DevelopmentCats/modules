---
display_name: Cursor MCP
description: Set up Model Context Protocol (MCP) servers for Cursor IDE
icon: ../.icons/cursor.svg
maintainer_github: coder
verified: true
tags: [ide, cursor, mcp, ai]
---

# Cursor MCP Servers

This module sets up Model Context Protocol (MCP) servers in your Coder workspace to extend Cursor IDE with AI capabilities. MCP allows you to connect Cursor to external tools, APIs, databases, and other systems, enhancing its AI capabilities.

This module is designed to be used **alongside** the standard Cursor module, which handles the actual launching of Cursor IDE.

## How It Works

MCP (Model Context Protocol) is an open protocol that standardizes how applications provide context and tools to LLMs. The protocol enables Cursor to interact with various data sources and tools through standardized interfaces.

This module:
1. Creates a proper MCP configuration in your workspace
2. Sets up specified MCP servers
3. Configures the environment for Cursor to discover and use these MCP servers when launched
4. **Automatically proxies** MCP servers to make them accessible from your local machine (solves remote development challenges)

## Usage

First, include both the `cursor` and `cursor-mcp` modules in your Terraform configuration:

```tf
module "cursor" {
  source   = "registry.coder.com/modules/cursor/coder"
  version  = "1.0.19"
  agent_id = coder_agent.example.id
  folder   = "/home/coder/project"
}

module "cursor_mcp" {
  source        = "registry.coder.com/modules/cursor-mcp/coder"
  version       = "1.0.0"
  agent_id      = coder_agent.example.id
  
  # Simple flags to enable common MCP servers
  enable_github = true
  github_token  = "your-token-here"
}
```

Once deployed, the module will generate a local MCP configuration file that you can use to set up your local Cursor IDE to connect to the remote MCP servers.

## Examples

### Simple Configuration with Flags

The easiest way to enable common MCP servers is to use the provided flags:

```tf
module "cursor_mcp" {
  source             = "registry.coder.com/modules/cursor-mcp/coder"
  version            = "1.0.0"
  agent_id           = coder_agent.example.id
  
  # Enable the GitHub MCP server
  enable_github      = true
  github_token       = "your-token-here"
  
  # Enable filesystem access
  enable_filesystem  = true
  filesystem_path    = "/home/coder/project"
  
  # Enable weather information
  enable_weather     = true
}
```

### Advanced Configuration with Custom Servers

For more advanced use cases, you can specify custom MCP servers:

```tf
module "cursor_mcp" {
  source      = "registry.coder.com/modules/cursor-mcp/coder"
  version     = "1.0.0"
  agent_id    = coder_agent.example.id
  
  # Enable built-in servers with simple flags
  enable_github = true
  
  # Add custom MCP servers
  mcp_servers = {
    "database" = {
      name    = "database",
      command = "python",
      args    = ["-m", "mcp_database_server"],
      env     = {
        DB_CONNECTION_STRING = "postgresql://user:password@localhost:5432/mydb"
      }
    }
  }
}
```

### Disabling Proxying (Not Recommended)

By default, this module automatically sets up proxying for MCP servers to make them accessible from your local Cursor instance. If you want to disable this feature:

```tf
module "cursor_mcp" {
  source        = "registry.coder.com/modules/cursor-mcp/coder"
  version       = "1.0.0"
  agent_id      = coder_agent.example.id
  enable_github = true
  enable_proxy  = false  # Disables proxying (not recommended)
}
```

## Connecting Your Local Cursor to Remote MCP Servers

After deploying your workspace with this module:

1. Create or open `~/.cursor/mcp.json` on your local machine
2. Copy the contents from the generated configuration file displayed in the module's outputs
3. Restart Cursor IDE

The module uses Coder's port forwarding capabilities and the `mcp-remote` adapter to seamlessly connect your local Cursor IDE to the remote MCP servers.

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `agent_id` | ID of the Coder agent | `string` | (Required) |

### Simplified MCP Server Enablement

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_github` | Enable the GitHub MCP server | `bool` | `false` |
| `github_token` | GitHub token for the GitHub MCP server | `string` | `""` |
| `enable_filesystem` | Enable the Filesystem MCP server | `bool` | `false` |
| `filesystem_path` | Path for the Filesystem server to operate on | `string` | `/home/coder` |
| `enable_weather` | Enable the Weather MCP server | `bool` | `false` |

### Proxy Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_proxy` | Enable automatic proxying of MCP servers | `bool` | `true` |
| `proxy_start_port` | Starting port number for proxy forwarding | `number` | `9100` |

### Advanced Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `mcp_servers` | Map of additional custom MCP servers | `map(object)` | `{}` |
| `mcp_config_dir` | Directory to store MCP configuration | `string` | `~/.cursor` |
| `mcp_port_start` | Starting port for MCP servers | `number` | `9000` |
| `log_path` | Path to log MCP server output | `string` | `~/mcp-servers.log` |

### Custom MCP Server Configuration

Each MCP server in the `mcp_servers` map requires:

- `name`: A unique identifier for the server
- `command`: The command to execute (e.g., `npx`, `node`, `python`)
- `args`: List of arguments to pass to the command
- `env`: Map of environment variables for the server

## How the Proxying Works

This module solves the remote development challenge with MCP by:

1. Setting up each MCP server in the Coder workspace
2. Creating a port-forwarding tunnel for each server using Coder's built-in proxying
3. Using the `mcp-remote` tool to adapt remote MCP servers to be accessible from local Cursor
4. Generating a local configuration file for your Cursor IDE

This approach ensures that your local Cursor can seamlessly interact with MCP servers running in your remote Coder workspace.

## Outputs

| Name | Description |
|------|-------------|
| `mcp_servers_configured` | List of configured MCP server names |
| `proxy_instructions` | Instructions for connecting your local Cursor to the proxied MCP servers |

## Troubleshooting

### MCP Servers Not Appearing in Cursor

If MCP servers are not appearing in your local Cursor:

1. Verify that the MCP servers are running in your workspace by checking the "MCP Servers" script output
2. Ensure you've copied the correct configuration to your local `~/.cursor/mcp.json` file
3. Check that port forwarding is working by visiting the proxy URLs directly in your browser
4. Restart your local Cursor application after updating the configuration

### GitHub Integration Issues

For GitHub integration:

1. Ensure your GitHub token has the necessary permissions (typically repo access)
2. If using a token directly, make sure it's properly specified in the module configuration
3. If using the `GITHUB_TOKEN` environment variable, verify it's available in your workspace

### Performance Considerations

MCP servers run directly in your workspace and communicate with your local Cursor over port forwarding. For optimal performance:

1. Use a workspace with sufficient resources for running MCP servers
2. Consider connection quality when working with large repositories or datasets
3. For filesystem operations, keep directories targeted by the filesystem server relatively small

## Contributing

If you encounter issues or have suggestions for improving this module, please submit an issue or pull request to the Coder registry repository.
