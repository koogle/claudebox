# ClaudeBox

A containerized Claude Code environment with web-based terminal streaming.

## Quick Start

1. **Setup environment**
   ```bash
   ./setup.sh
   ```
   The setup script will guide you through configuring:
   - Anthropic API key (required)
   - GitHub repository URL (optional)
   - GitHub Personal Access Token (optional, for private repos)

2. **Run container**
   ```bash
   docker-compose up --build
   ```

3. **Access terminal**
   Open http://localhost:3000 in your browser

## Features

- Live terminal streaming using xterm.js and WebSockets
- Claude Code pre-installed and configured
- Automatic Claude process restart on exit
- Full terminal output buffering and replay for new connections
- Git operations (commit, push, pull, revert) via web UI
- Auto-clone repository on startup (optional)
- GitHub Personal Access Token support for secure operations
- Real-time status indicators for API key, repository, and connection
- Native node-pty compilation for optimal performance

## GitHub Setup

### Creating a Personal Access Token

1. Go to GitHub Settings → [Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give your token a descriptive name (e.g., "ClaudeBox")
4. Select expiration (recommend 90 days for security)
5. Select scopes:
   - **`repo`** - Full control of private repositories (required for private repos)
   - **`public_repo`** - Access public repositories (if only using public repos)
6. Click "Generate token"
7. **Copy the token immediately** (starts with `ghp_`)

### Token Security Best Practices

- Use tokens instead of SSH keys for better security
- Set expiration dates on tokens
- Use minimum required scopes
- Revoke tokens when no longer needed
- Never commit tokens to version control

## Environment Variables

- `ANTHROPIC_API_KEY` - Your Anthropic API key (required)
- `REPO_URL` - Git repository to clone on startup (optional)
  - Use HTTPS format: `https://github.com/username/repo.git`
- `GITHUB_TOKEN` - GitHub Personal Access Token (optional)
  - Required for private repositories
  - Enables push/pull operations
  - Format: `ghp_xxxxxxxxxxxxxxxxxxxx`

## Architecture

- **Backend**: Node.js + Express + node-pty
- **Terminal**: xterm.js + WebSocket streaming
- **Container**: Docker with pnpm package manager
- **Ports**: 3000 (HTTP), 3001 (WebSocket)
- **Process Management**: Automatic Claude process restart on exit
- **Build Tools**: Includes Python 3, make, and build-essential for native modules

## Commands

```bash
# Initial setup (interactive)
./setup.sh

# Force reconfigure all settings
./setup.sh --force

# Skip Docker checks (for custom Docker setups)
./setup.sh --skip-docker-check

# Start container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop container
docker-compose down

# Rebuild after changes
docker-compose up --build
```

## Example Configurations

### Public Repository (Read-Only)
```env
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxx
REPO_URL=https://github.com/facebook/react.git
# No GITHUB_TOKEN needed for public repos
```

### Private Repository with Push Access
```env
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxx
REPO_URL=https://github.com/mycompany/private-repo.git
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```
