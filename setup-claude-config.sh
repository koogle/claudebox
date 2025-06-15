#!/bin/sh

# Setup Claude configuration from template
if [ -f "/app/claude-config-template.json" ]; then
  # Start with the template
  cp /app/claude-config-template.json /tmp/claude-config.json
  
  # Process API key if provided
  if [ -n "$ANTHROPIC_API_KEY" ]; then
    # Get the last 20 characters of the API key
    API_KEY_SUFFIX=$(echo "$ANTHROPIC_API_KEY" | tail -c 21)
    
    # Replace placeholders and ensure customApiKeyResponses includes this API key
    python3 -c "
import json

# Read the config template
with open('/tmp/claude-config.json', 'r') as f:
    config = json.load(f)

# Replace API key placeholders
api_key = '$ANTHROPIC_API_KEY'
api_key_suffix = '$API_KEY_SUFFIX'

# Set the primary API key
config['primaryApiKey'] = api_key

# Ensure customApiKeyResponses exists and includes this API key suffix
if 'customApiKeyResponses' not in config:
    config['customApiKeyResponses'] = {'approved': [], 'rejected': []}

# Add the API key suffix to approved list if not already present
if api_key_suffix not in config['customApiKeyResponses']['approved']:
    config['customApiKeyResponses']['approved'].append(api_key_suffix)

# Write the updated config
with open('/tmp/claude-config.json', 'w') as f:
    json.dump(config, f, indent=2)

print(f'Claude configuration created with API key (suffix: {api_key_suffix})')
"
    
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
  
  # Setup credentials file if enabled
  mkdir -p /root/.claude
  
  # Check if we should use the credentials file
  if [ "$USE_CLAUDE_CREDENTIALS" = "true" ] && [ -f "/app/claude-credentials.json" ]; then
    cp /app/claude-credentials.json /root/.claude/credentials.json
    echo "Credentials copied to /root/.claude/credentials.json"
    
    # Extract customApiKeyResponses from credentials and merge into Claude config
    python3 -c "
import json

# Read the credentials file
try:
    with open('/app/claude-credentials.json', 'r') as f:
        credentials = json.load(f)
    
    # Read the current Claude config
    with open('/root/.claude.json', 'r') as f:
        config = json.load(f)
    
    # Extract customApiKeyResponses if it exists in credentials
    if 'customApiKeyResponses' in credentials:
        config['customApiKeyResponses'] = credentials['customApiKeyResponses']
        print('Merged customApiKeyResponses from credentials into Claude config')
    
    # Write the updated config back
    with open('/root/.claude.json', 'w') as f:
        json.dump(config, f, indent=2)
        
except Exception as e:
    print(f'Warning: Failed to merge customApiKeyResponses: {e}')
"
    
  elif [ "$USE_CLAUDE_CREDENTIALS" = "true" ]; then
    echo "Warning: USE_CLAUDE_CREDENTIALS=true but /app/claude-credentials.json not found"
  else
    echo "Claude credentials file not used"
  fi
else
  echo "No Claude configuration template found"
fi
