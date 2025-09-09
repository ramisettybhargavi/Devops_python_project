#!/bin/sh
# inject-config.sh - Inject environment variables into JavaScript

set -e

# Get environment variables with defaults
PUBLIC_IP=${PUBLIC_IP:-localhost}
BACKEND_PORT=${BACKEND_PORT:-5000}
ENVIRONMENT=${ENVIRONMENT:-development}

echo "Injecting configuration..."
echo "PUBLIC_IP: $PUBLIC_IP"
echo "BACKEND_PORT: $BACKEND_PORT" 
echo "ENVIRONMENT: $ENVIRONMENT"

# Create js directory if it doesn't exist
mkdir -p /usr/share/nginx/html/js

# Create configuration JavaScript file
cat > /usr/share/nginx/html/js/config.js << EOF
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

echo "Configuration injection completed!"
echo "Generated config.js with PUBLIC_IP: $PUBLIC_IP"
