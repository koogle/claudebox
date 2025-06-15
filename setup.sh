#!/bin/bash

# Exit on any error
set -e

# Parse command line arguments
SKIP_DOCKER_CHECK=false
FORCE_RECONFIGURE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-docker-check)
            SKIP_DOCKER_CHECK=true
            shift
            ;;
        --force|-f)
            FORCE_RECONFIGURE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-docker-check    Skip Docker installation verification"
            echo "  --force, -f           Force reconfiguration of all settings"
            echo "  --help, -h            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 ClaudeBox Setup"
echo "=================="
echo ""

# Check if Docker is installed (unless skipped)
if [ "$SKIP_DOCKER_CHECK" = false ]; then
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed"
        echo ""
        
        # Detect OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "📦 Docker Desktop for macOS Installation Options:"
            echo ""
            echo "1. Download Docker Desktop from:"
            echo "   https://www.docker.com/products/docker-desktop/"
            echo ""
            echo "2. Or install via Homebrew:"
            echo "   brew install --cask docker"
            echo ""
            echo "After installation, start Docker Desktop and run this script again."
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [[ "$ID" == "ubuntu" ]]; then
                    echo "📦 Docker Installation for Ubuntu:"
                    echo ""
                    echo "Run these commands:"
                    echo ""
                    echo "# Update package index"
                    echo "sudo apt-get update"
                    echo ""
                    echo "# Install prerequisites"
                    echo "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common"
                    echo ""
                    echo "# Add Docker's GPG key"
                    echo "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
                    echo ""
                    echo "# Add Docker repository"
                    echo "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\""
                    echo ""
                    echo "# Install Docker"
                    echo "sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
                    echo ""
                    echo "# Install Docker Compose"
                    echo "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
                    echo "sudo chmod +x /usr/local/bin/docker-compose"
                    echo ""
                    echo "# Add your user to docker group (logout/login required)"
                    echo "sudo usermod -aG docker \$USER"
                else
                    echo "📦 Docker Installation:"
                    echo "Visit: https://docs.docker.com/engine/install/"
                fi
            fi
        else
            echo "📦 Docker Installation:"
            echo "Visit: https://docs.docker.com/engine/install/"
        fi
        echo ""
        echo "To skip Docker checks, run: $0 --skip-docker-check"
        exit 1
    fi

    # Check if docker-compose is installed
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is not installed"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Docker Compose should be included with Docker Desktop."
            echo "Make sure Docker Desktop is running."
        else
            echo "Install Docker Compose:"
            echo "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
            echo "sudo chmod +x /usr/local/bin/docker-compose"
        fi
        echo ""
        echo "To skip Docker checks, run: $0 --skip-docker-check"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "❌ Docker daemon is not running"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Please start Docker Desktop from Applications"
        else
            echo "Please start Docker daemon: sudo systemctl start docker"
        fi
        echo ""
        echo "To skip Docker checks, run: $0 --skip-docker-check"
        exit 1
    fi

    echo "✅ Docker is installed and running"
else
    echo "⚠️  Skipping Docker verification (--skip-docker-check)"
fi


# Create .env if it doesn't exist
if [ ! -f .env ]; then
    touch .env
fi

# Function to update or add environment variable
update_env() {
    local key=$1
    local value=$2
    
    # For multi-line values (like SSH keys), handle differently
    if [[ "$value" == *$'\n'* ]]; then
        # Remove existing key if present
        sed -i.bak "/^${key}=/d" .env && rm -f .env.bak
        # Write multi-line value with proper escaping
        echo "${key}=\"${value}\"" >> .env
    else
        if grep -q "^${key}=" .env; then
            # Update existing single-line value
            sed -i.bak "s|^${key}=.*|${key}=${value}|" .env && rm -f .env.bak
        else
            # Add new single-line value
            echo "${key}=${value}" >> .env
        fi
    fi
}

# Check if ANTHROPIC_API_KEY is already set
if grep -q "^ANTHROPIC_API_KEY=.*[a-zA-Z0-9]" .env && [ "$FORCE_RECONFIGURE" = false ]; then
    echo "✅ Anthropic API key already configured"
else
    if [ "$FORCE_RECONFIGURE" = true ] && grep -q "^ANTHROPIC_API_KEY=.*[a-zA-Z0-9]" .env; then
        echo "🔄 Reconfiguring Anthropic API key (--force)"
    fi
    echo "📝 Anthropic API Key Setup"
    echo "   Get your API key from: https://console.anthropic.com/settings/keys"
    echo ""
    read -p "Enter your Anthropic API key: " api_key
    if [ -z "$api_key" ]; then
        echo "❌ API key is required to continue"
        exit 1
    fi
    update_env "ANTHROPIC_API_KEY" "$api_key"
    echo "✅ API key saved"
fi


# Check if we should reconfigure GitHub settings
SHOULD_CONFIG_GITHUB=true
if grep -q "^REPO_URL=" .env && [ "$FORCE_RECONFIGURE" = false ]; then
    SHOULD_CONFIG_GITHUB=false
    echo "✅ GitHub repository already configured"
    echo "   Use --force to reconfigure"
fi

if [ "$SHOULD_CONFIG_GITHUB" = true ]; then
    if [ "$FORCE_RECONFIGURE" = true ] && grep -q "^REPO_URL=" .env; then
        echo "🔄 Reconfiguring GitHub settings (--force)"
    fi
    
    echo "📝 GitHub Repository Setup (optional)"
    echo "   Leave blank to skip repository cloning"
    echo ""

    # Ask for repo URL
    read -p "Enter GitHub repository URL (e.g., https://github.com/user/repo.git): " repo_url
    if [ ! -z "$repo_url" ]; then
        update_env "REPO_URL" "$repo_url"
        echo "✅ Repository URL saved"
        
        # Check if it's likely a private repo
        if [[ "$repo_url" == *"private"* ]] || [[ "$repo_url" == git@* ]]; then
            echo ""
            echo "⚠️  This appears to be a private repository"
        fi
        
        echo ""
        echo "📝 GitHub Personal Access Token (optional)"
        echo "   Required for private repositories and push access"
        echo "   Create a token at: https://github.com/settings/tokens"
        echo "   Select 'repo' scope for full access"
        echo ""
        
        read -p "Enter GitHub Personal Access Token (or leave blank for public repos): " github_token
        if [ ! -z "$github_token" ]; then
            update_env "GITHUB_TOKEN" "$github_token"
            echo "✅ GitHub token saved"
        else
            # Clear any existing token
            sed -i.bak '/^GITHUB_TOKEN=/d' .env && rm -f .env.bak
            echo "ℹ️  No token provided - will work for public repos only"
        fi
    else
        # Clear GitHub settings if user leaves blank
        sed -i.bak '/^REPO_URL=/d' .env && rm -f .env.bak
        sed -i.bak '/^GITHUB_TOKEN=/d' .env && rm -f .env.bak
        echo "✅ GitHub configuration cleared"
    fi
fi

echo "✅ Configuration complete!"
echo ""
echo "Building and starting ClaudeBox..."
docker-compose up --build -d

echo ""
echo "✅ ClaudeBox is starting!"
echo ""
echo "📺 Terminal interface: http://localhost:3000"
echo "🔌 WebSocket terminal: ws://localhost:3001"
echo ""
echo "Commands:"
echo "  docker-compose logs -f     # View logs"
echo "  docker-compose down        # Stop container"
echo "  docker-compose restart     # Restart container"
