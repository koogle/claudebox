#!/bin/bash

echo "🚀 ClaudeBox Setup"
echo "=================="

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "✅ Created .env file"
    echo ""
    echo "⚠️  Please edit .env and add your ANTHROPIC_API_KEY"
    echo "   You can also optionally set REPO_URL to auto-clone a repository"
    exit 1
fi

# Check if ANTHROPIC_API_KEY is set
if ! grep -q "ANTHROPIC_API_KEY=.*[a-zA-Z0-9]" .env; then
    echo "❌ ANTHROPIC_API_KEY not set in .env file"
    echo "   Please add your API key to continue"
    exit 1
fi

echo "✅ Environment configured"
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