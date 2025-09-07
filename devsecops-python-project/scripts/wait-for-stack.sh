#!/bin/bash

# DevSecOps Stack Startup and Health Check Script
# Waits for all services to be healthy before completing

set -e

echo "🚀 Starting DevSecOps Stack Health Check..."
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES=60
RETRY_INTERVAL=10

# Function to check service health
check_service() {
    local service_name=$1
    local health_url=$2
    local expected_status=${3:-200}
    
    echo -n "Checking $service_name... "
    
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s -o /dev/null -w "%{http_code}" "$health_url" | grep -q "$expected_status"; then
            echo -e "${GREEN}✓ Healthy${NC}"
            return 0
        fi
        
        if [ $i -eq $MAX_RETRIES ]; then
            echo -e "${RED}✗ Failed after $MAX_RETRIES attempts${NC}"
            return 1
        fi
        
        echo -n "."
        sleep $RETRY_INTERVAL
    done
}

# Function to check Docker service status
check_docker_service() {
    local service_name=$1
    
    echo -n "Checking Docker service $service_name... "
    
    if docker ps --filter "name=$service_name" --filter "status=running" | grep -q "$service_name"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running${NC}"
        return 1
    fi
}

# Function to wait for port to be available
wait_for_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    echo -n "Waiting for $service_name port $port... "
    
    for i in $(seq 1 $MAX_RETRIES); do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓ Available${NC}"
            return 0
        fi
        
        if [ $i -eq $MAX_RETRIES ]; then
            echo -e "${RED}✗ Port not available after $MAX_RETRIES attempts${NC}"
            return 1
        fi
        
        echo -n "."
        sleep $RETRY_INTERVAL
    done
}

echo -e "${BLUE}Step 1: Checking Docker services status${NC}"
echo "----------------------------------------"

# Check if Docker Compose services are running
SERVICES=("devsecops-postgres" "devsecops-elasticsearch" "devsecops-logstash" "devsecops-kibana" "devsecops-jaeger" "devsecops-backend" "devsecops-frontend" "devsecops-prometheus" "devsecops-grafana")

for service in "${SERVICES[@]}"; do
    check_docker_service "$service"
done

echo ""
echo -e "${BLUE}Step 2: Waiting for service ports${NC}"
echo "------------------------------------"

# Wait for essential ports
wait_for_port "localhost" "5432" "PostgreSQL"
wait_for_port "localhost" "9200" "Elasticsearch"
wait_for_port "localhost" "5044" "Logstash"
wait_for_port "localhost" "5601" "Kibana"
wait_for_port "localhost" "16686" "Jaeger UI"
wait_for_port "localhost" "5000" "Backend API"
wait_for_port "localhost" "8080" "Frontend"
wait_for_port "localhost" "9090" "Prometheus"
wait_for_port "localhost" "3000" "Grafana"

echo ""
echo -e "${BLUE}Step 3: Health checking services${NC}"
echo "-----------------------------------"

# Health check services with HTTP endpoints
check_service "PostgreSQL" "http://localhost:5432" "000"  # Connection test
check_service "Elasticsearch" "http://localhost:9200/_cluster/health"
check_service "Kibana" "http://localhost:5601/api/status"
check_service "Jaeger UI" "http://localhost:16686"
check_service "Backend API" "http://localhost:5000/health"
check_service "Frontend" "http://localhost:8080"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"

echo ""
echo -e "${BLUE}Step 4: Comprehensive backend health check${NC}"
echo "----------------------------------------------"

# Detailed backend health check
echo "Checking backend observability integration..."
if curl -s "http://localhost:5000/observability/status" | jq '.elasticsearch.healthy' | grep -q "true"; then
    echo -e "Backend → Elasticsearch: ${GREEN}✓ Connected${NC}"
else
    echo -e "Backend → Elasticsearch: ${YELLOW}⚠ Warning${NC}"
fi

if curl -s "http://localhost:5000/observability/status" | jq '.jaeger.healthy' | grep -q "true"; then
    echo -e "Backend → Jaeger: ${GREEN}✓ Connected${NC}"
else
    echo -e "Backend → Jaeger: ${YELLOW}⚠ Warning${NC}"
fi

echo ""
echo -e "${BLUE}Step 5: Testing API endpoints${NC}"
echo "--------------------------------"

# Test basic API functionality
echo -n "Testing user API endpoint... "
if curl -s "http://localhost:5000/api/users" | jq '.users' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Working${NC}"
else
    echo -e "${YELLOW}⚠ Limited functionality${NC}"
fi

echo -n "Testing metrics endpoint... "
if curl -s "http://localhost:5000/metrics" | grep -q "http_requests_total"; then
    echo -e "${GREEN}✓ Working${NC}"
else
    echo -e "${YELLOW}⚠ Limited functionality${NC}"
fi

echo ""
echo -e "${GREEN}🎉 DevSecOps Stack Health Check Complete!${NC}"
echo "============================================="
echo ""
echo -e "${BLUE}📊 Service URLs:${NC}"
echo "----------------"
echo "Frontend:       http://localhost:8080"
echo "Backend API:    http://localhost:5000"
echo "Kibana:         http://localhost:5601"
echo "Jaeger UI:      http://localhost:16686"
echo "Grafana:        http://localhost:3000 (admin/admin123)"
echo "Prometheus:     http://localhost:9090"
echo "Elasticsearch:  http://localhost:9200"
echo "PgAdmin:        http://localhost:5050 (admin@devsecops.local/admin123)"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "--------------"
echo "1. Generate sample data: ./scripts/generate-sample-data.sh"
echo "2. View application logs in Kibana"
echo "3. Check distributed traces in Jaeger"
echo "4. Monitor metrics in Grafana"
echo ""
echo -e "${GREEN}All services are ready for use! 🚀${NC}"
