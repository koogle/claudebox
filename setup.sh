#!/bin/bash

echo "🚀 ClaudeBox Setup"
echo "=================="
echo ""

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    touch .env
fi

# Function to update or add environment variable
update_env() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" .env; then
        # Update existing
        sed -i.bak "s|^${key}=.*|${key}=${value}|" .env && rm .env.bak
    else
        # Add new
        echo "${key}=${value}" >> .env
    fi
}

# Check if ANTHROPIC_API_KEY is already set
if grep -q "^ANTHROPIC_API_KEY=.*[a-zA-Z0-9]" .env; then
    echo "✅ Anthropic API key already configured"
else
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

echo ""
echo "📝 GitHub Repository Setup (optional)"
echo "   Leave blank to skip repository cloning"
echo ""

# Ask for repo URL
read -p "Enter GitHub repository URL (e.g., git@github.com:user/repo.git): " repo_url
if [ ! -z "$repo_url" ]; then
    update_env "REPO_URL" "$repo_url"
    echo "✅ Repository URL saved"
    
    echo ""
    echo "📝 GitHub SSH Key Setup"
    echo "   Required for private repositories"
    echo ""
    
    # Check if user wants to use existing SSH key
    if [ -f ~/.ssh/id_rsa ]; then
        read -p "Use existing SSH key from ~/.ssh/id_rsa? (y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            echo "✅ Will mount existing SSH directory"
        else
            echo ""
            echo "Paste your GitHub SSH private key (press Enter twice when done):"
            ssh_key=""
            while IFS= read -r line; do
                [ -z "$line" ] && break
                ssh_key="${ssh_key}${line}\n"
            done
            if [ ! -z "$ssh_key" ]; then
                # Remove trailing newline and escape for .env
                ssh_key=$(echo -e "$ssh_key" | sed '$d')
                update_env "GITHUB_SSH_KEY" "$ssh_key"
                echo "✅ SSH key saved"
            fi
        fi
    else
        echo ""
        echo "Paste your GitHub SSH private key (press Enter twice when done):"
        ssh_key=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            ssh_key="${ssh_key}${line}\n"
        done
        if [ ! -z "$ssh_key" ]; then
            # Remove trailing newline and escape for .env
            ssh_key=$(echo -e "$ssh_key" | sed '$d')
            update_env "GITHUB_SSH_KEY" "$ssh_key"
            echo "✅ SSH key saved"
        fi
    fi
fi

echo ""
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