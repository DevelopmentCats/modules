terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.17"
    }
  }
}

locals {
  icon_url = "/icon/terminal.svg"
  
  # API provider options
  api_providers = {
    "anthropic" = {
      name  = "Anthropic"
      value = "anthropic"
      icon  = "/icon/claude.svg"
    }
    "openai" = {
      name  = "OpenAI"
      value = "openai"
      icon  = "/icon/openai.svg"
    }
    "deepseek" = {
      name  = "DeepSeek"
      value = "deepseek"
      icon  = "/icon/terminal.svg"
    }
    "groq" = {
      name  = "GROQ"
      value = "groq" 
      icon  = "/icon/terminal.svg"
    }
    "openrouter" = {
      name  = "OpenRouter"
      value = "openrouter"
      icon  = "/icon/terminal.svg"
    }
  }
  
  # Model mappings based on provider
  models = {
    "anthropic" = {
      "sonnet" = {
        name  = "Claude 3.7 Sonnet"
        value = "sonnet"
      }
      "haiku" = {
        name  = "Claude 3.7 Haiku"
        value = "haiku"
      }
    }
    "openai" = {
      "o3-mini" = {
        name  = "o3-mini"
        value = "o3-mini"
      }
      "o1" = {
        name  = "o1"
        value = "o1"
      }
      "gpt-4o" = {
        name  = "GPT-4o"
        value = "gpt-4o"
      }
    }
    "deepseek" = {
      "deepseek" = {
        name  = "DeepSeek R1" 
        value = "deepseek"
      }
      "deepseek-chat" = {
        name  = "DeepSeek Chat V3"
        value = "deepseek-chat"
      }
    }
    "groq" = {
      "mixtral" = {
        name  = "Mixtral"
        value = "mixtral"
      }
      "llama3" = {
        name  = "Llama 3"
        value = "llama3"
      }
    }
    "openrouter" = {
      "openrouter" = {
        name  = "OpenRouter"
        value = "openrouter"
      }
    }
  }
  
  # Playwright options
  playwright_options = {
    "enabled" = {
      name  = "Enabled"
      value = "true"
    }
    "disabled" = {
      name  = "Disabled"
      value = "false"
    }
  }
  
  # Voice coding options
  voice_options = {
    "enabled" = {
      name  = "Enabled"
      value = "true"
    }
    "disabled" = {
      name  = "Disabled"
      value = "false"
    }
  }
  
  selected_provider = data.coder_parameter.api_provider.value
  selected_model = data.coder_parameter.model.value
  
  api_arg = "${local.selected_provider}=${data.coder_parameter.api_key.value}"
}

data "coder_workspace" "me" {}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "log_path" {
  type        = string
  description = "The path to log aider to."
  default     = "/tmp/aider.log"
}

variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
  default     = null
}

variable "folder" {
  type        = string
  description = "The folder to run Aider in."
  default     = "/home/coder"
}

variable "install_aider" {
  type        = bool
  description = "Whether to install Aider."
  default     = true
}

variable "aider_version" {
  type        = string
  description = "The version of Aider to install."
  default     = "latest"
}

variable "additional_arguments" {
  type        = string
  description = "Additional arguments to pass to Aider."
  default     = ""
}

# Parameter to select the API provider
data "coder_parameter" "api_provider" {
  name         = "api_provider"
  display_name = "API Provider"
  description  = "Select the AI provider to use with Aider"
  default      = "anthropic"
  type         = "string"
  icon         = local.icon_url
  mutable      = true
  order        = 1

  dynamic "option" {
    for_each = local.api_providers
    content {
      name  = option.value.name
      value = option.value.value
      icon  = option.value.icon
    }
  }
}

# Parameter for model selection based on provider
data "coder_parameter" "model" {
  name         = "model"
  display_name = "Model"
  description  = "Select the AI model to use with Aider"
  type         = "string"
  mutable      = true
  default      = local.selected_provider == "anthropic" ? "sonnet" : (
                 local.selected_provider == "openai" ? "o3-mini" : (
                 local.selected_provider == "deepseek" ? "deepseek" : (
                 local.selected_provider == "groq" ? "mixtral" : "openrouter")))
  icon         = local.api_providers[local.selected_provider].icon
  order        = 2

  dynamic "option" {
    for_each = local.models[local.selected_provider]
    content {
      name  = option.value.name
      value = option.value.value
    }
  }
}

# Parameter for API key
data "coder_parameter" "api_key" {
  name         = "api_key"
  display_name = "${local.api_providers[local.selected_provider].name} API Key"
  description  = "Enter your ${local.api_providers[local.selected_provider].name} API key"
  type         = "string"
  mutable      = true
  sensitive    = true
  icon         = local.api_providers[local.selected_provider].icon
  order        = 3
}

# Parameter for Playwright installation
data "coder_parameter" "install_playwright" {
  name         = "install_playwright"
  display_name = "Install Playwright"
  description  = "Install Playwright for enhanced web scraping support (requires npm)"
  type         = "string"
  mutable      = true
  default      = "true"
  icon         = "/icon/terminal.svg"
  order        = 4

  dynamic "option" {
    for_each = local.playwright_options
    content {
      name  = option.value.name
      value = option.value.value
    }
  }
}

# Parameter for voice coding support
data "coder_parameter" "enable_voice" {
  name         = "enable_voice"
  display_name = "Enable Voice Coding"
  description  = "Install PortAudio for voice coding support (Linux/Mac only)"
  type         = "string"
  mutable      = true
  default      = "false"
  icon         = "/icon/terminal.svg"
  order        = 5

  dynamic "option" {
    for_each = local.voice_options
    content {
      name  = option.value.name
      value = option.value.value
    }
  }
}

# Install and Initialize Aider
resource "coder_script" "aider" {
  agent_id     = var.agent_id
  display_name = "Aider"
  icon         = local.icon_url
  script       = <<-EOT
    #!/bin/bash
    set -e

    # Function to check if a command exists
    command_exists() {
      command -v "$1" >/dev/null 2>&1
    }

    echo "Setting up Aider AI pair programming..."

    # Install Aider if enabled
    if [ "${var.install_aider}" = "true" ]; then
      echo "Installing Aider using recommended method..."
      
      # Install using aider-install (recommended method from docs)
      if command_exists python3; then
        python3 -m pip install aider-install
        aider-install
      elif command_exists python; then
        python -m pip install aider-install
        aider-install
      else
        echo "Error: Python not found. Please install Python to use Aider."
        exit 1
      fi
    fi

    # Install PortAudio for voice support if requested
    if [ "${data.coder_parameter.enable_voice.value}" = "true" ]; then
      echo "Setting up voice coding support..."
      
      if [ "$(uname)" = "Linux" ]; then
        if command_exists apt-get; then
          echo "Installing PortAudio for voice support on Linux..."
          sudo apt-get update && sudo apt-get install -y libportaudio2 libasound2-plugins
        elif command_exists dnf; then
          echo "Installing PortAudio for voice support on Linux (Fedora/RHEL)..."
          sudo dnf install -y portaudio portaudio-devel
        elif command_exists pacman; then
          echo "Installing PortAudio for voice support on Linux (Arch)..."
          sudo pacman -S --noconfirm portaudio
        else
          echo "Warning: Couldn't detect package manager to install PortAudio."
        fi
      elif [ "$(uname)" = "Darwin" ]; then
        if command_exists brew; then
          echo "Installing PortAudio for voice support on Mac..."
          brew install portaudio
        else
          echo "Warning: Homebrew not found. Can't install PortAudio."
        fi
      else
        echo "Voice support should work on Windows without additional packages."
      fi
    fi

    # Install Playwright for web support if requested
    if [ "${data.coder_parameter.install_playwright.value}" = "true" ]; then
      if command_exists npm; then
        echo "Installing Playwright for web scraping support..."
        npm install -g playwright
        playwright install --with-deps chromium
      else
        echo "Warning: npm not found. Can't install Playwright."
      fi
    fi

    # Create the folder if it doesn't exist
    mkdir -p "${var.folder}"
    
    # Touch the log file
    touch "${var.log_path}"
    
    echo "Aider setup complete! Access it through your terminal."
    echo "To use Aider, run: aider --model ${local.selected_model} --api-key ${local.api_arg} ${var.additional_arguments}"
    EOT
  run_on_start = true
}

# Command to run Aider CLI
resource "coder_command" "aider" {
  agent_id     = var.agent_id
  display_name = "Aider CLI"
  icon         = local.icon_url
  command      = "cd ${var.folder} && aider --model ${local.selected_model} --api-key ${local.api_arg} ${var.additional_arguments}"
}

