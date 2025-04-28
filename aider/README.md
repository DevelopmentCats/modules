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
- **Simple Installation**: Uses `aider-install` to set up Aider following the recommended approach

## Examples

### Basic usage with user-selectable options

```tf
module "aider" {
  source    = "registry.coder.com/modules/aider/coder"
  version   = "1.0.0"
  agent_id  = coder_agent.example.id
  folder    = "/home/coder/project"
}
```

With this setup, users will be prompted to select:
- AI provider (Anthropic, OpenAI, DeepSeek, etc.)
- Model (options depend on the selected provider)
- API key
- Whether to install Playwright for web scraping
- Whether to enable voice coding support

### With additional arguments

```tf
module "aider" {
  source              = "registry.coder.com/modules/aider/coder"
  version             = "1.0.0"
  agent_id            = coder_agent.example.id
  folder              = "/home/coder/project"
  additional_arguments = "--dark-mode --watch-files"
}
```

## Usage

After the workspace starts, Aider will be installed using the recommended `aider-install` method, which creates a separate Python environment specifically for Aider.

To start coding with Aider:

1. **Terminal Command**: Run `aider` in your terminal with your selected model and API key
2. **Command Button**: Click the Aider CLI command in the Coder dashboard to start Aider automatically

### Available Models

Aider supports multiple AI models from different providers:

- **Anthropic**: Claude 3.7 Sonnet, Claude 3.7 Haiku
- **OpenAI**: o3-mini, o1, GPT-4o
- **DeepSeek**: DeepSeek R1, DeepSeek Chat V3
- **GROQ**: Mixtral, Llama 3
- **OpenRouter**: Access to multiple providers with a single key

For more information on using Aider, see the [Aider documentation](https://aider.chat/docs/).
