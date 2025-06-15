FROM node:20-slim

# Install git, ssh, and pnpm
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack prepare pnpm@latest --activate

WORKDIR /app

# Install Claude Code globally with pnpm
RUN pnpm add -g @anthropic-ai/claude-code

# Copy package files first for better caching
COPY package*.json pnpm-lock.yaml* ./
RUN pnpm install

# Copy application files
COPY . .

# Create SSH directory
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Expose HTTP port for web server and WebSocket port for terminal
EXPOSE 3000 3001

CMD ["node", "server.js"]