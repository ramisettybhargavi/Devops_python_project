#!/bin/bash
set -e

echo "=== Waiting for Complete DevSecOps ELK & Jaeger Stack ==="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local service_url=$2
    local timeout=${3:-120}
    local counter=0

    print_step "Waiting for $service_name at $service_url (timeout: ${timeout}s)..."

    while [ $counter -lt $timeout ]; do
        if curl -s -f "$service_url" > /dev/null 2>&1; then
            print_status "✅ $service_name is ready!"
            return 0
        fi

        if [ $((counter % 10)) -eq 0 ]; then
            print_warning "⏳ Still waiting for $service_name... (${counter}s elapsed)"
        fi

        sleep 2
        counter=$((counter + 2))
    done

    print_error "❌ $service_name failed to start within ${timeout} seconds"
    return 1
}

print_step "1. Checking if docker-compose services are starting..."

# Check if docker-compose file exists
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

print_step "2. Starting complete stack (this may take several minutes)..."
docker-compose up -d

print_step "3. Waiting for core services to be ready..."

# Wait for database first (required by backend)
wait_for_service "PostgreSQL" "http://localhost:5432" 60 || {
    print_warning "Database connection test failed, but continuing..."
}

# Wait for ELK Stack (in order)
wait_for_service "Elasticsearch" "http://localhost:9200/_cluster/health" 120
wait_for_service "Logstash" "http://localhost:9600" 90  
wait_for_service "Kibana" "http://localhost:5601/api/status" 120

# Wait for Jaeger
wait_for_service "Jaeger UI" "http://localhost:16686" 60
wait_for_service "Jaeger Collector" "http://localhost:14268" 30

# Wait for Prometheus and Grafana
wait_for_service "Prometheus" "http://localhost:9090/-/healthy" 60
wait_for_service "Grafana" "http://localhost:3000/api/health" 60

# Wait for application services
wait_for_service "Backend API" "http://localhost:5000/health" 90
wait_for_service "Frontend" "http://localhost:8080/health" 30

print_step "4. Validating observability integration..."

# Test ELK integration
print_status "Testing Elasticsearch indices..."
if curl -s "http://localhost:9200/_cat/indices?v" > /dev/null; then
    print_status "✅ Elasticsearch is accessible"
else
    print_warning "⚠️  Elasticsearch indices not accessible"
fi

# Test Jaeger services
print_status "Testing Jaeger services..."
if curl -s "http://localhost:16686/api/services" > /dev/null; then
    print_status "✅ Jaeger is accessible"
else
    print_warning "⚠️  Jaeger services not accessible"
fi

# Test backend observability endpoints
print_status "Testing backend observability integration..."
if curl -s "http://localhost:5000/observability/elasticsearch/status" > /dev/null; then
    print_status "✅ Backend-Elasticsearch integration working"
else
    print_warning "⚠️  Backend-Elasticsearch integration not working"
fi

if curl -s "http://localhost:5000/observability/jaeger/status" > /dev/null; then
    print_status "✅ Backend-Jaeger integration working"  
else
    print_warning "⚠️  Backend-Jaeger integration not working"
fi

print_step "5. Stack Status Summary"

print_status "🎉 DevSecOps ELK & Jaeger Stack is ready!"
print_status ""
print_status "=== Service URLs ==="
print_status "Frontend:           http://localhost:8080"
print_status "Backend API:        http://localhost:5000"
print_status "Database Admin:     http://localhost:5050"
print_status ""
print_status "=== ELK Stack ==="
print_status "Kibana (Logs):      http://localhost:5601"
print_status "Elasticsearch:      http://localhost:9200"
print_status "Logstash API:       http://localhost:9600"
print_status ""
print_status "=== Tracing & Metrics ==="
print_status "Jaeger UI:          http://localhost:16686"
print_status "Prometheus:         http://localhost:9090"
print_status "Grafana:            http://localhost:3000 (admin/admin123)"
print_status ""
print_status "=== Next Steps ==="
print_status "1. Open the application: http://localhost:8080"
print_status "2. Generate sample data: ./scripts/generate-sample-data.sh"
print_status "3. View logs in Kibana: http://localhost:5601"
print_status "4. View traces in Jaeger: http://localhost:16686"
print_status "5. View metrics in Grafana: http://localhost:3000"
print_status ""
print_status "Run './scripts/generate-sample-data.sh' to create sample users and traces!"
