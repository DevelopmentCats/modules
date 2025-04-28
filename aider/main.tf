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
  
  # Browser mode options
  browser_options = {
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

variable "git_repository_url" {
  type        = string
  description = "URL of a Git repository to clone for use with Aider. If empty, no repository will be cloned."
  default     = ""
}

variable "git_branch" {
  type        = string
  description = "Branch to check out when cloning the Git repository."
  default     = "main"
}

variable "auto_commit" {
  type        = bool
  description = "Whether to configure Aider to automatically commit changes."
  default     = true
}

variable "browser_mode" {
  type        = bool
  description = "Whether to launch Aider in browser mode instead of terminal mode."
  default     = false
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

# Parameter for browser mode
data "coder_parameter" "browser_mode" {
  name         = "browser_mode"
  display_name = "Browser Mode"
  description  = "Launch Aider in browser UI mode instead of terminal"
  type         = "string"
  mutable      = true
  default      = "false"
  icon         = "/icon/terminal.svg"
  order        = 6

  dynamic "option" {
    for_each = local.browser_options
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

    echo "Setting up Aider AI pair programming..."

    # Install essential dependencies
    if [ "$(uname)" = "Linux" ]; then
      echo "Installing dependencies on Linux..."
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y git python3 python3-pip
        
        # Install PortAudio if voice support is enabled
        if [ "${data.coder_parameter.enable_voice.value}" = "true" ]; then
          sudo apt-get install -y libportaudio2 libasound2-plugins libpulse-dev
          pip3 install pyaudio sounddevice
        fi
        
        # Install Node.js if Playwright is enabled
        if [ "${data.coder_parameter.install_playwright.value}" = "true" ]; then
          curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
          sudo apt-get install -y nodejs
        fi
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git python3 python3-pip
        
        # Install PortAudio if voice support is enabled
        if [ "${data.coder_parameter.enable_voice.value}" = "true" ]; then
          sudo dnf install -y portaudio portaudio-devel pulseaudio-libs-devel
          pip3 install pyaudio sounddevice
        fi
        
        # Install Node.js if Playwright is enabled
        if [ "${data.coder_parameter.install_playwright.value}" = "true" ]; then
          sudo dnf module install -y nodejs:18
        fi
      fi
    elif [ "$(uname)" = "Darwin" ]; then
      echo "Installing dependencies on macOS..."
      if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew install git python3
      
      # Install PortAudio if voice support is enabled
      if [ "${data.coder_parameter.enable_voice.value}" = "true" ]; then
        brew install portaudio
        pip3 install pyaudio sounddevice
      fi
      
      # Install Node.js if Playwright is enabled
      if [ "${data.coder_parameter.install_playwright.value}" = "true" ]; then
        brew install node
      fi
    fi

    # Install Aider
    if [ "${var.install_aider}" = "true" ]; then
      echo "Installing Aider..."
      pip3 install aider-install
      aider-install
    fi

    # Install Playwright if enabled
    if [ "${data.coder_parameter.install_playwright.value}" = "true" ]; then
      if command -v npm >/dev/null 2>&1; then
        echo "Installing Playwright for web scraping..."
        npm install -g playwright
        npx playwright install --with-deps chromium
      fi
    fi

    # Create the workspace folder
    mkdir -p "${var.folder}"
    touch "${var.log_path}"
    
    # Setup Git repository if provided
    if [ -n "${var.git_repository_url}" ]; then
      # Configure Git
      git config --global user.email "$(whoami)@$(hostname)" 2>/dev/null || true
      git config --global user.name "$(whoami)" 2>/dev/null || true
      
      # Clone repository
      echo "Cloning repository: ${var.git_repository_url}"
      if [ -z "$(ls -A ${var.folder})" ]; then
        git clone --branch ${var.git_branch} ${var.git_repository_url} ${var.folder}
      else
        repo_name=$(basename "${var.git_repository_url}" .git)
        git clone --branch ${var.git_branch} ${var.git_repository_url} "${var.folder}/${repo_name}"
      fi
    fi
    
    # Create Aider config
    mkdir -p "$HOME/.config/aider"
    cat > "$HOME/.config/aider/config.yaml" <<EOF
# Aider configuration
model: ${local.selected_model}
provider: ${local.selected_provider}
auto_commit: ${var.auto_commit}
EOF
    
    echo "Aider setup complete! Access it through your terminal."
    echo "To use Aider, run: aider --model ${local.selected_model} --api-key ${local.api_arg} ${var.additional_arguments}"
    EOT
  run_on_start = true
}

# Command to run Aider CLI
resource "coder_command" "aider" {
  agent_id     = var.agent_id
  display_name = data.coder_parameter.browser_mode.value == "true" ? "Aider (Browser UI)" : "Aider CLI"
  icon         = local.icon_url
  command      = <<-EOT
    #!/bin/bash
    # Determine working directory
    if [ -n "${var.git_repository_url}" ] && [ ! -z "$(ls -A ${var.folder})" ]; then
      repo_name=$(basename "${var.git_repository_url}" .git)
      if [ -d "${var.folder}/${repo_name}" ]; then
        cd "${var.folder}/${repo_name}"
      else
        cd "${var.folder}"
      fi
    else
      cd "${var.folder}"
    fi
    
    # Run Aider with browser flag if enabled
    if [ "${data.coder_parameter.browser_mode.value}" = "true" ]; then
      aider --browser --model ${local.selected_model} --api-key ${local.api_arg} ${var.additional_arguments}
    else
      aider --model ${local.selected_model} --api-key ${local.api_arg} ${var.additional_arguments}
    fi
  EOT
}

