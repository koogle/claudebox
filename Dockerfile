FROM node:20-slim

# Install git, ssh, build tools, and pnpm
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    make \
    python3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack prepare pnpm@latest --activate

# Setup pnpm and install Claude Code globally
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV SHELL="/bin/bash"

# Run pnpm setup separately
RUN pnpm setup

# Install Claude Code globally
RUN pnpm add -g @anthropic-ai/claude-code

# Setup build arguments
ARG REPO_URL
ARG GITHUB_TOKEN
ARG USE_CLAUDE_CREDENTIALS=false
ARG BASIC_AUTH_USER
ARG BASIC_AUTH_PASS
ARG ANTHROPIC_API_KEY

# Environment variables
# USE_CLAUDE_CREDENTIALS: Set to "true" to use claude-credentials.json file
# ANTHROPIC_API_KEY: API key for Claude
# GITHUB_TOKEN: GitHub token for git operations
# BASIC_AUTH_USER: Username for basic authentication (optional)
# BASIC_AUTH_PASS: Password for basic authentication (optional)

# Create workspace directory
RUN mkdir -p /workspace

# Clone repository if URL provided
RUN if [ -n "$REPO_URL" ]; then \
    # Ensure URL ends with .git if it's a GitHub URL
    CLONE_URL="$REPO_URL"; \
    if echo "$REPO_URL" | grep -q "github.com" && ! echo "$REPO_URL" | grep -q "\.git$"; then \
        CLONE_URL="${REPO_URL}.git"; \
    fi; \
    if [ -n "$GITHUB_TOKEN" ]; then \
        # Set up git credentials first
        git config --global credential.helper store && \
        echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > /root/.git-credentials && \
        # Clone using the corrected URL (credentials will be used automatically)
        git clone $CLONE_URL /workspace && echo "Repository cloned successfully" || exit 1; \
    else \
        # Try cloning without auth (for public repos)
        git clone $CLONE_URL /workspace && echo "Repository cloned successfully" || exit 1; \
    fi; \
fi

WORKDIR /app

# Copy package files first for better caching
COPY package*.json pnpm-lock.yaml* ./
RUN pnpm install

# Build node-pty native modules
RUN cd node_modules/node-pty && \
    npm install && \
    npm run build && \
    cd ../..

# Copy application files
COPY . .

# Copy Claude credentials file if USE_CLAUDE_CREDENTIALS is true
# This requires the file to be manually copied to build context first
COPY claude-credentials.json* /app/

# Set build-time environment variables for runtime and setup
ENV BASIC_AUTH_USER=${BASIC_AUTH_USER}
ENV BASIC_AUTH_PASS=${BASIC_AUTH_PASS}
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Make setup script executable and run Claude configuration setup
RUN chmod +x /app/setup-claude-config.sh

# Run setup script
RUN /app/setup-claude-config.sh && \
    rm -f /app/claude-credentials.json

# Expose port for HTTP + WebSocket server
EXPOSE 3000

CMD ["node", "server.js"]
