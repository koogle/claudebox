#!/bin/sh

# Setup Claude configuration from template
if [ -f "/app/claude-config-template.json" ]; then
  # Start with the template
  cp /app/claude-config-template.json /tmp/claude-config.json
  
  # Process API key if provided
  if [ -n "$ANTHROPIC_API_KEY" ]; then
    # Get the last 20 characters of the API key
    API_KEY_SUFFIX=$(echo "$ANTHROPIC_API_KEY" | tail -c 21)
    
    # Replace placeholders
    sed -i "s/__API_KEY__/$ANTHROPIC_API_KEY/g" /tmp/claude-config.json
    sed -i "s/__API_KEY_SUFFIX__/$API_KEY_SUFFIX/g" /tmp/claude-config.json
    
    echo "Claude configuration created with API key"
  else
    # Remove primaryApiKey field if no API key provided
    python3 -c "
import json
with open('/tmp/claude-config.json', 'r') as f:
    config = json.load(f)
config.pop('primaryApiKey', None)
with open('/tmp/claude-config.json', 'w') as f:
    json.dump(config, f, indent=2)
"
  fi
  
  
  # Move the final config to the correct location
  mv /tmp/claude-config.json /root/.claude.json
  echo "Claude configuration created at /root/.claude.json"
  
  # Copy credentials file if present
  if [ -f "/app/claude-credentials.json" ]; then
    mkdir -p /root/.claude
    cp /app/claude-credentials.json /root/.claude/.credentials.json
    echo "Credentials copied to /root/.claude/.credentials.json"
  fi
else
  echo "No Claude configuration template found"
fi
