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
- Git operations (commit, push, pull, revert) via web UI
- Auto-clone repository on startup (optional)
- SSH key support for private repos

## Environment Variables

- `ANTHROPIC_API_KEY` - Your Anthropic API key (required)
- `REPO_URL` - Git repository to clone on startup (optional)
- `GITHUB_SSH_KEY` - SSH private key for GitHub access (optional)

## Architecture

- **Backend**: Node.js + Express + node-pty
- **Terminal**: xterm.js + WebSocket streaming
- **Container**: Docker with pnpm package manager
- **Ports**: 3000 (HTTP), 3001 (WebSocket)

## Commands

```bash
# Start container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop container
docker-compose down

# Rebuild after changes
docker-compose up --build
```
