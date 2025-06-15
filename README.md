# ClaudeBox

A containerized Claude Code environment with web-based terminal streaming.

## Quick Start

1. **Setup environment**
   ```bash
   ./setup.sh
   ```

2. **Configure API key**
   Edit `.env` and add your Anthropic API key:
   ```
   ANTHROPIC_API_KEY=your-api-key-here
   ```

3. **Run container**
   ```bash
   docker-compose up --build
   ```

4. **Access terminal**
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
