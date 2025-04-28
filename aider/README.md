---
display_name: Aider
description: Run Aider AI pair programming in your workspace
icon: ../.icons/terminal.svg
maintainer_github: coder
verified: false
tags: [ai, pair-programming, coding-assistant]
---

# Aider

Aider is AI pair programming in your terminal. This module installs and runs [Aider](https://aider.chat) in your workspace using the recommended installation method.

## Quick Start

Add this module to your Coder template:

```tf
module "aider" {
  source    = "registry.coder.com/modules/aider/coder"
  version   = "1.0.0"
  agent_id  = coder_agent.example.id
}
```

## Features

- **Interactive Parameter Selection**: Choose your AI provider, model, and configuration options when creating the workspace
- **Multiple AI Providers**: Supports Anthropic (Claude), OpenAI, DeepSeek, GROQ, and OpenRouter
- **Optional Dependencies**: Install Playwright for web page scraping and PortAudio for voice coding
- **Git Integration**: Automatically configure Git and clone repositories for your projects
- **Browser UI**: Use Aider in your browser with a modern web interface instead of the terminal
- **Simple Installation**: Uses `aider-install` to set up Aider following the recommended approach

## Module Parameters

| Parameter | Description | Type | Default |
|-----------|-------------|------|---------|
| `agent_id` | The ID of a Coder agent (required) | `string` | - |
| `folder` | The folder to run Aider in | `string` | `/home/coder` |
| `log_path` | The path to log Aider to | `string` | `/tmp/aider.log` |
| `install_aider` | Whether to install Aider | `bool` | `true` |
| `aider_version` | The version of Aider to install | `string` | `"latest"` |
| `additional_arguments` | Additional arguments to pass to Aider | `string` | `""` |
| `git_repository_url` | URL of a Git repository to clone for use with Aider | `string` | `""` |
| `git_branch` | Branch to check out when cloning the Git repository | `string` | `"main"` |
| `auto_commit` | Whether to configure Aider to automatically commit changes | `bool` | `true` |
| `browser_mode` | Whether to launch Aider in browser mode | `bool` | `false` |
| `order` | Position of the app in the UI presentation | `number` | `null` |

## User Parameters

When creating a workspace, users will be prompted for:

1. **API Provider**: Choose between Anthropic, OpenAI, DeepSeek, GROQ, or OpenRouter
2. **Model**: Select a model specific to the chosen provider
3. **API Key**: Enter the API key for the selected provider
4. **Install Playwright**: Choose whether to install Playwright for web scraping (true/false)
5. **Enable Voice Coding**: Choose whether to install PortAudio for voice coding (true/false)
6. **Browser Mode**: Choose whether to launch Aider in browser UI mode instead of terminal mode (true/false)

## Usage Examples

### Basic Example

```tf
module "aider" {
  source    = "registry.coder.com/modules/aider/coder"
  version   = "1.0.0"
  agent_id  = coder_agent.example.id
  folder    = "/home/coder/project"
}
```

### With Browser Mode Enabled

```tf
module "aider" {
  source       = "registry.coder.com/modules/aider/coder"
  version      = "1.0.0"
  agent_id     = coder_agent.example.id
  folder       = "/home/coder/project"
  browser_mode = true
}
```

### With Git Repository Integration

```tf
module "aider" {
  source            = "registry.coder.com/modules/aider/coder"
  version           = "1.0.0"
  agent_id          = coder_agent.example.id
  folder            = "/home/coder/project"
  git_repository_url = "https://github.com/example/repo.git"
  git_branch        = "develop"
  auto_commit       = true
}
```

### With Additional Arguments

```tf
module "aider" {
  source               = "registry.coder.com/modules/aider/coder"
  version              = "1.0.0"
  agent_id             = coder_agent.example.id
  folder               = "/home/coder/project"
  additional_arguments = "--dark-mode --watch-files"
}
```

### Specific Aider Version

```tf
module "aider" {
  source        = "registry.coder.com/modules/aider/coder"
  version       = "1.0.0"
  agent_id      = coder_agent.example.id
  aider_version = "v0.14.0"
}
```

## Complete Template Example

Here's a more complete example of how to use the Aider module in a Coder template:

```tf
terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.11.0"
    }
  }
}

provider "coder" {}

data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    # Add any additional workspace setup here
    echo "Workspace ready!"
  EOT
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:8080/?folder=/home/coder/project"
  icon         = "/icon/code.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080/healthz"
    interval  = 3
    threshold = 10
  }
}

module "aider" {
  source            = "registry.coder.com/modules/aider/coder"
  version           = "1.0.0"
  agent_id          = coder_agent.main.id
  folder            = "/home/coder/project"
  git_repository_url = "https://github.com/yourusername/yourproject.git"
  browser_mode      = true
}

resource "coder_metadata" "workspace_info" {
  resource_id = coder_agent.main.id
  item {
    key   = "AI Assistant"
    value = "Aider"
  }
}
```

## Using Aider in Your Workspace

After the workspace starts, Aider will be installed and configured according to your parameters.

### Starting Aider

You can start Aider in two different ways, with two different interfaces:

1. **Terminal Interface**: 
   - Click the "Aider CLI" button in the Coder dashboard
   - Run the command displayed at the end of the setup script
   - Interact with Aider directly in your terminal

2. **Browser Interface**:
   - If browser mode is enabled, click the "Aider (Browser UI)" button in the dashboard
   - A web interface will open in a new browser tab
   - Interact with Aider using a more visual, user-friendly interface

### Aider Browser Mode

The browser UI for Aider provides a more visual way to work with the AI pair programmer:

- Modern web interface for easier interaction
- Direct code editing in your local files
- Git integration with automatic commits and sensible commit messages
- Works well with models like GPT-4o, Claude 3.7 Sonnet, and DeepSeek models
- Visual display of code changes and suggestions

By default, the module launches Aider in terminal mode, but you can enable browser mode using either:
- The `browser_mode` module parameter (set to `true`)
- The "Browser Mode" user parameter when creating the workspace

### Available AI Providers and Models

| Provider | Available Models | Description |
|----------|------------------|-------------|
| **Anthropic** | Claude 3.7 Sonnet, Claude 3.7 Haiku | High-quality Claude models |
| **OpenAI** | o3-mini, o1, GPT-4o | GPT models from OpenAI |
| **DeepSeek** | DeepSeek R1, DeepSeek Chat V3 | Models from DeepSeek |
| **GROQ** | Mixtral, Llama 3 | Fast inference on open models |
| **OpenRouter** | OpenRouter | Access to multiple providers with a single key |

### API Keys

You will need an API key for the selected provider:

- **Anthropic**: Get a key from [console.anthropic.com](https://console.anthropic.com/)
- **OpenAI**: Get a key from [platform.openai.com](https://platform.openai.com/api-keys)
- **DeepSeek**: Get a key from [platform.deepseek.com](https://platform.deepseek.com/)
- **GROQ**: Get a key from [console.groq.com](https://console.groq.com/keys)
- **OpenRouter**: Get a key from [openrouter.ai](https://openrouter.ai/keys)

## Troubleshooting

If you encounter issues:

1. **Aider not found**: The module adds Aider to your PATH. Try restarting your terminal or running `source ~/.bashrc`.
2. **API key issues**: Ensure you've entered the correct API key for your selected provider.
3. **Git errors**: Check that your Git repository URL is correct and accessible.
4. **Voice coding issues**: Voice coding requires additional system libraries. Check for any installation errors in the setup logs.
5. **Browser mode issues**: If the browser interface doesn't open, check that you're accessing it from a machine that can reach your Coder workspace.

For more information on using Aider, see the [Aider documentation](https://aider.chat/docs/) and the [browser UI documentation](https://aider.chat/docs/usage/browser.html).
