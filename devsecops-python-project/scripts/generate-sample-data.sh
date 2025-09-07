#!/bin/bash

# Generate Sample Data Script
# Creates test data and generates traces for observability testing

set -e

echo "🎯 Generating Sample Data for DevSecOps Application"
echo "=================================================="

# Configuration
BACKEND_URL="http://localhost:5000"
FRONTEND_URL="http://localhost:8080"
NUM_USERS=10
NUM_REQUESTS=50

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to generate random user data
generate_user_data() {
    local names=("Alice Johnson" "Bob Smith" "Carol Williams" "David Brown" "Eva Davis" "Frank Miller" "Grace Wilson" "Henry Moore" "Iris Taylor" "Jack Anderson")
    local domains=("example.com" "test.org" "demo.net" "sample.io" "mock.dev")
    
    local name=${names[$((RANDOM % ${#names[@]}))]}
    local first_name=$(echo $name | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
    local last_name=$(echo $name | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
    local domain=${domains[$((RANDOM % ${#domains[@]}))]}
    local email="${first_name}.${last_name}@${domain}"
    
    echo "{\"name\":\"$name\",\"email\":\"$email\",\"password\":\"password123\"}"
}

# Function to make traced request
make_traced_request() {
    local method=$1
    local url=$2
    local data=$3
    local trace_id="trace-$(date +%s)-$RANDOM"
    
    if [ "$method" = "POST" ]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "X-Trace-ID: $trace_id" \
            -d "$data" \
            "$url" || true
    else
        curl -s -H "X-Trace-ID: $trace_id" "$url" || true
    fi
}

# Check if backend is available
echo -e "${BLUE}Step 1: Checking backend availability${NC}"
if ! curl -s "$BACKEND_URL/health" > /dev/null; then
    echo -e "${RED}❌ Backend is not available at $BACKEND_URL${NC}"
    echo "Please ensure the backend service is running"
    exit 1
fi
echo -e "${GREEN}✅ Backend is available${NC}"

# Create sample users
echo ""
echo -e "${BLUE}Step 2: Creating sample users${NC}"
echo "--------------------------------"

created_users=0
for i in $(seq 1 $NUM_USERS); do
    user_data=$(generate_user_data)
    echo -n "Creating user $i... "
    
    response=$(make_traced_request "POST" "$BACKEND_URL/api/users" "$user_data")
    
    if echo "$response" | grep -q "successfully"; then
        echo -e "${GREEN}✅ Created${NC}"
        ((created_users++))
    else
        echo -e "${YELLOW}⚠️ Skipped (may already exist)${NC}"
    fi
    
    # Small delay to avoid overwhelming the system
    sleep 0.5
done

echo "Created $created_users new users"

# Generate API traffic for observability
echo ""
echo -e "${BLUE}Step 3: Generating API traffic${NC}"
echo "--------------------------------"

request_count=0
for i in $(seq 1 $NUM_REQUESTS); do
    echo -n "Request $i/$NUM_REQUESTS... "
    
    # Random API calls to generate traces
    case $((RANDOM % 5)) in
        0)
            # Get all users
            make_traced_request "GET" "$BACKEND_URL/api/users" > /dev/null
            echo -e "${GREEN}GET /users${NC}"
            ;;
        1)
            # Get specific user
            user_id=$((RANDOM % 10 + 1))
            make_traced_request "GET" "$BACKEND_URL/api/users/$user_id" > /dev/null
            echo -e "${GREEN}GET /users/$user_id${NC}"
            ;;
        2)
            # Health check
            make_traced_request "GET" "$BACKEND_URL/health" > /dev/null
            echo -e "${GREEN}GET /health${NC}"
            ;;
        3)
            # Observability status
            make_traced_request "GET" "$BACKEND_URL/observability/status" > /dev/null
            echo -e "${GREEN}GET /observability/status${NC}"
            ;;
        4)
            # Metrics
            make_traced_request "GET" "$BACKEND_URL/metrics" > /dev/null
            echo -e "${GREEN}GET /metrics${NC}"
            ;;
    esac
    
    ((request_count++))
    
    # Random delay between requests
    sleep $(echo "scale=2; $RANDOM/32767 * 2" | bc)
done

echo "Generated $request_count API requests"

# Test frontend connectivity
echo ""
echo -e "${BLUE}Step 4: Testing frontend connectivity${NC}"
echo "---------------------------------------"

if curl -s "$FRONTEND_URL" > /dev/null; then
    echo -e "${GREEN}✅ Frontend is accessible at $FRONTEND_URL${NC}"
else
    echo -e "${YELLOW}⚠️ Frontend may not be fully ready at $FRONTEND_URL${NC}"
fi

# Generate some errors for testing
echo ""
echo -e "${BLUE}Step 5: Generating test scenarios${NC}"
echo "-----------------------------------"

echo -n "Testing 404 errors... "
make_traced_request "GET" "$BACKEND_URL/api/nonexistent" > /dev/null
make_traced_request "GET" "$BACKEND_URL/api/users/999999" > /dev/null
echo -e "${GREEN}✅ Done${NC}"

echo -n "Testing invalid requests... "
make_traced_request "POST" "$BACKEND_URL/api/users" '{"invalid":"data"}' > /dev/null
make_traced_request "POST" "$BACKEND_URL/api/users" '{"name":"","email":"invalid"}' > /dev/null
echo -e "${GREEN}✅ Done${NC}"

# Summary
echo ""
echo -e "${GREEN}🎉 Sample Data Generation Complete!${NC}"
echo "======================================"
echo ""
echo -e "${BLUE}📊 Generated Data Summary:${NC}"
echo "- Users created: $created_users"
echo "- API requests: $request_count"
echo "- Test scenarios: Multiple error cases"
echo ""
echo -e "${BLUE}🔍 Where to View Data:${NC}"
echo "- Application: $FRONTEND_URL"
echo "- API Health: $BACKEND_URL/health"
echo "- Logs (Kibana): http://localhost:5601"
echo "- Traces (Jaeger): http://localhost:16686"
echo "- Metrics (Grafana): http://localhost:3000"
echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "1. Wait 2-3 minutes for logs to appear in Kibana"
echo "2. Check Jaeger for distributed traces"
echo "3. View real-time metrics in Grafana"
echo "4. Look for trace IDs in application logs"
echo ""
echo -e "${GREEN}Ready to explore your observability stack! 🚀${NC}"
