#!/bin/sh

# Setup Claude configuration from template
if [ -n "$ANTHROPIC_API_KEY" ]; then
  # Get the last 20 characters of the API key
  API_KEY_SUFFIX=$(echo "$ANTHROPIC_API_KEY" | tail -c 21)
  
  # Create .claude.json from template
  sed -e "s/__API_KEY__/$ANTHROPIC_API_KEY/g" \
      -e "s/__API_KEY_SUFFIX__/$API_KEY_SUFFIX/g" \
      /app/claude-config-template.json > /root/.claude.json
  
  echo "Claude configuration created at /root/.claude.json"
else
  echo "Warning: ANTHROPIC_API_KEY not set, skipping Claude configuration"
fi