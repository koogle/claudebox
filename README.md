# ClaudeBox

Run Claude code in a container and within a repo to make it easy to develop on the go. Have fun.

<img width="1457" alt="Screenshot 2025-06-14 at 11 36 07 PM" src="https://github.com/user-attachments/assets/21a8dacf-4574-434e-964a-f4d42db870ed" />

## Quick Start

1. **Setup environment**
   ```bash
   ./setup.sh
   ```
   The setup script will guide you through configuring:
   - Claude credentials (from keychain on macOS or ~/.claude/.credentials.json on Linux)
   - Anthropic API key (if credentials not available)
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

## Claude Auth

ClaudeBox supports two authentication methods:

**macOS (Keychain Integration)**
- Automatically detects Claude credentials stored in macOS keychain

**Linux/Other Platforms**
- Uses credentials file at `~/.claude/.credentials.json`

**API Key Fallback**
- If no credentials found, prompts for `ANTHROPIC_API_KEY`
- Can be configured manually in `.env` file

## Environment Variables

- `USE_CLAUDE_CREDENTIALS` - Set to "true" to use credentials file/keychain (auto-configured)
- `ANTHROPIC_API_KEY` - Your Anthropic API key (fallback if no credentials)
- `REPO_URL` - Git repository to clone on startup (optional)
  - Use HTTPS format: `https://github.com/username/repo.git`
- `GITHUB_TOKEN` - GitHub Personal Access Token (optional)
  - Required for private repositories
  - Enables push/pull operations
  - Format: `ghp_xxxxxxxxxxxxxxxxxxxx`
- `BASIC_AUTH_USER` - Username for basic authentication (optional)
- `BASIC_AUTH_PASS` - Password for basic authentication (optional)
  - When both are set, enables HTTP basic auth for the web interface
  - Useful for securing public deployments

## Arch

- **Backend**: Node.js + Express + node-pty
- **Terminal**: xterm.js + WebSocket streaming

## Setup

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
