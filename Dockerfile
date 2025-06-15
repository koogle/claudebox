FROM node:20-slim

# Install git, ssh, and pnpm
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
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

# Create workspace directory
RUN mkdir -p /workspace

# Clone repository if URL provided
RUN if [ -n "$REPO_URL" ]; then \
    if [ -n "$GITHUB_TOKEN" ]; then \
        # Extract repo path from URL (works with both https and git@ URLs)
        REPO_PATH=$(echo $REPO_URL | sed -e 's/.*github.com[:/]\(.*\)\.git$/\1/' -e 's/.*github.com[:/]\(.*\)$/\1/'); \
        git clone https://${GITHUB_TOKEN}@github.com/${REPO_PATH}.git /workspace && echo "Repository cloned successfully" || exit 1; \
    else \
        # Try cloning without auth (for public repos)
        git clone $REPO_URL /workspace && echo "Repository cloned successfully" || exit 1; \
    fi; \
fi

WORKDIR /app

# Copy package files first for better caching
COPY package*.json pnpm-lock.yaml* ./
RUN pnpm install

# Copy application files
COPY . .

# Expose HTTP port for web server and WebSocket port for terminal
EXPOSE 3000 3001

CMD ["node", "server.js"]