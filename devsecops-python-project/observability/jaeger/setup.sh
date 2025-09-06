#!/bin/bash
set -e

echo "=== Jaeger Distributed Tracing Setup ==="
echo "Setting up Jaeger for DevSecOps 3-tier application"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Change to script directory
cd "$(dirname "$0")"

print_step "1. Starting Jaeger All-in-One..."

# Check if Elasticsearch is running (Jaeger needs it for storage)
if ! curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
    print_warning "Elasticsearch not running. Starting ELK stack first..."
    cd ../elasticsearch && docker-compose up -d
    cd ../logstash && docker-compose up -d
    cd ../kibana && docker-compose up -d
    cd ../jaeger

    print_status "Waiting for Elasticsearch to be ready..."
    sleep 30
fi

# Start Jaeger
docker-compose up -d

print_step "2. Waiting for Jaeger to be ready..."
timeout=120
counter=0
while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:16686 > /dev/null 2>&1; then
        break
    fi
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge $timeout ]; then
    echo "❌ Jaeger failed to start within ${timeout} seconds"
    exit 1
fi

print_step "3. Verifying Jaeger services..."

# Check Jaeger UI
if curl -s http://localhost:16686 > /dev/null 2>&1; then
    print_status "✅ Jaeger UI is accessible at http://localhost:16686"
else
    print_warning "❌ Jaeger UI is not accessible"
fi

# Check Jaeger collector
if curl -s http://localhost:14268/api/traces > /dev/null 2>&1; then
    print_status "✅ Jaeger Collector is running on port 14268"
else
    print_warning "❌ Jaeger Collector is not accessible"
fi

# Check agent ports
if nc -z localhost 6831 2>/dev/null; then
    print_status "✅ Jaeger Agent UDP port 6831 is open"
else
    print_warning "❌ Jaeger Agent UDP port 6831 is not accessible"
fi

print_step "4. Creating Elasticsearch indices for Jaeger..."

# Wait a bit for Jaeger to initialize its indices
sleep 10

# Check if Jaeger indices are created
if curl -s http://localhost:9200/_cat/indices | grep -q jaeger; then
    print_status "✅ Jaeger indices created in Elasticsearch"
    curl -s http://localhost:9200/_cat/indices | grep jaeger
else
    print_warning "⚠️  Jaeger indices not yet created (this is normal on first run)"
fi

print_step "5. Testing trace ingestion..."

# Send a test trace
cat > test_trace.json << 'EOF'
{
  "traceID": "test-trace-$(date +%s)",
  "spanID": "test-span-$(date +%s)",
  "operationName": "test-operation",
  "startTime": $(date +%s)000000,
  "duration": 1000000,
  "tags": [
    {
      "key": "service.name",
      "vStr": "test-service"
    },
    {
      "key": "test.tag",
      "vStr": "test-value"
    }
  ],
  "process": {
    "serviceName": "test-service",
    "tags": [
      {
        "key": "hostname",
        "vStr": "test-host"
      }
    ]
  }
}
EOF

if curl -s -X POST http://localhost:14268/api/traces -H "Content-Type: application/json" -d @test_trace.json > /dev/null 2>&1; then
    print_status "✅ Test trace sent successfully"
    rm -f test_trace.json
else
    print_warning "❌ Failed to send test trace"
fi

print_status "🎉 Jaeger setup completed!"
print_status ""
print_status "Jaeger services:"
print_status "- UI:        http://localhost:16686"
print_status "- Collector: http://localhost:14268"
print_status "- Agent:     UDP port 6831"
print_status ""
print_status "Integration endpoints for applications:"
print_status "- Agent host: localhost"
print_status "- Agent port: 6831"
print_status "- Collector: http://localhost:14268/api/traces"
print_status ""
print_status "Next steps:"
print_status "1. Configure your applications to send traces to Jaeger"
print_status "2. View traces in the Jaeger UI"
print_status "3. Analyze distributed traces for performance optimization"
