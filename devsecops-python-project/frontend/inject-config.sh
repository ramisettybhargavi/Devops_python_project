#!/bin/sh
# inject-config.sh - Inject environment variables from main project .env file

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

echo "Looking for .env file at: $ENV_FILE"

# Load environment variables safely
load_env_safely() {
    if [ -f "$ENV_FILE" ]; then
        echo "Loading environment variables from .env file..."
        # Read each line and process safely
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments, empty lines, and lines without =
            case "$line" in
                '#'*|''|*[!a-zA-Z0-9_]*=*) 
                    continue 
                    ;;
            esac

            # Extract variable name and value
            var_name="${line%%=*}"
            var_value="${line#*=}"

            # Remove any leading/trailing whitespace
            var_name=$(echo "$var_name" | xargs)
            var_value=$(echo "$var_value" | xargs)

            # Remove quotes if present
            var_value=$(echo "$var_value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

            # Only export if it looks like a valid variable name
            if echo "$var_name" | grep -q '^[a-zA-Z_][a-zA-Z0-9_]*$'; then
                export "$var_name"="$var_value"
                echo "  Loaded: $var_name=$var_value"
            else
                echo "  Skipping invalid variable name: $var_name"
            fi
        done < "$ENV_FILE"
    else
        echo ".env file not found at $ENV_FILE, using defaults or existing environment variables"
    fi
}

load_env_safely

# Get environment variables with defaults
PUBLIC_IP=${PUBLIC_IP:-localhost}
BACKEND_PORT=${BACKEND_PORT:-5000}
ENVIRONMENT=${ENVIRONMENT:-development}

echo "Injecting configuration..."
echo "PUBLIC_IP: $PUBLIC_IP"
echo "BACKEND_PORT: $BACKEND_PORT"
echo "ENVIRONMENT: $ENVIRONMENT"

# Create js directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/src/js"

# Create configuration JavaScript file
CONFIG_JS="$SCRIPT_DIR/src/js/config.js"
cat > "$CONFIG_JS" << EOF
// Runtime configuration injected at container startup
window.APP_CONFIG = {
    publicIP: '$PUBLIC_IP',
    backendPort: '$BACKEND_PORT',
    environment: '$ENVIRONMENT',
    protocol: window.location.protocol,
    backendUrl: window.location.protocol + '//' + '$PUBLIC_IP' + ':$BACKEND_PORT',
    kibanaUrl: window.location.protocol + '//' + '$PUBLIC_IP' + ':5601',
    jaegerUrl: window.location.protocol + '//' + '$PUBLIC_IP' + ':16686',
    grafanaUrl: window.location.protocol + '//' + '$PUBLIC_IP' + ':3000',
    elasticsearchUrl: window.location.protocol + '//' + '$PUBLIC_IP' + ':9200',
    prometheusUrl: window.location.protocol + '//' + '$PUBLIC_IP' + ':9090'
};

console.log('Frontend Configuration Loaded:', window.APP_CONFIG);
EOF

echo "Configuration file created successfully at: $CONFIG_JS"
