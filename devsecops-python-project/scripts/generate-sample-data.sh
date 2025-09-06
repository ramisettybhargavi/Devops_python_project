#!/bin/bash
set -e

echo "=== Generating Sample Data for ELK & Jaeger Demo ==="

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

# Configuration
BACKEND_URL="http://localhost:5000"
TOTAL_USERS=50
TOTAL_OPERATIONS=200

print_step "1. Checking backend availability..."
if ! curl -s -f "$BACKEND_URL/health" > /dev/null; then
    echo "Backend not available at $BACKEND_URL"
    echo "Please ensure the stack is running: docker-compose up -d"
    exit 1
fi

print_status "✅ Backend is available"

print_step "2. Creating sample users with tracing..."

# Array of sample user data
declare -a users=(
    "John Doe:john.doe@company.com"
    "Jane Smith:jane.smith@company.com" 
    "Bob Johnson:bob.johnson@company.com"
    "Alice Brown:alice.brown@company.com"
    "Charlie Wilson:charlie.wilson@company.com"
    "Diana Prince:diana.prince@company.com"
    "ELK Admin:elk.admin@devsecops.com"
    "Jaeger User:jaeger.user@devsecops.com"
    "DevOps Engineer:devops@company.com"
    "Security Analyst:security@company.com"
)

# Function to generate random trace ID
generate_trace_id() {
    echo "demo-$(date +%s)-$(shuf -i 1000-9999 -n 1)"
}

# Create users
user_ids=()
for i in $(seq 1 $TOTAL_USERS); do
    if [ $i -le ${#users[@]} ]; then
        # Use predefined user data
        user_data="${users[$((i-1))]}"
        name="${user_data%:*}"
        email="${user_data#*:}"
    else
        # Generate random user data
        name="Test User $i"
        email="testuser$i@example.com"
    fi

    trace_id=$(generate_trace_id)

    print_status "Creating user: $name ($trace_id)"

    response=$(curl -s -X POST "$BACKEND_URL/api/users" \
        -H "Content-Type: application/json" \
        -H "X-Trace-ID: $trace_id" \
        -d "{\"name\": \"$name\", \"email\": \"$email\"}" \
        -w "%{http_code}")

    if [ "${response: -3}" == "201" ]; then
        # Extract user ID from response
        user_id=$(echo "$response" | sed 's/201$//' | jq -r '.id' 2>/dev/null || echo "unknown")
        user_ids+=("$user_id")
        print_status "✅ Created user $name (ID: $user_id, Trace: $trace_id)"
    else
        print_status "⚠️  Failed to create user $name (Response: ${response: -3})"
    fi

    # Add small delay to avoid overwhelming the system
    sleep 0.1
done

print_step "3. Performing various operations to generate traces..."

# Array of operations to perform
operations=("GET" "GET" "GET" "PUT" "DELETE")
operation_weights=(50 30 10 8 2)  # Percentage weights

for i in $(seq 1 $TOTAL_OPERATIONS); do
    # Select random operation based on weights
    rand=$((RANDOM % 100))
    if [ $rand -lt 50 ]; then
        operation="GET"
    elif [ $rand -lt 80 ]; then
        operation="GET_LIST"
    elif [ $rand -lt 90 ]; then
        operation="PUT"
    else
        operation="DELETE"
    fi

    trace_id=$(generate_trace_id)

    case $operation in
        "GET")
            # Get individual user
            if [ ${#user_ids[@]} -gt 0 ]; then
                user_id=${user_ids[$((RANDOM % ${#user_ids[@]}))]}
                curl -s -X GET "$BACKEND_URL/api/users/$user_id" \
                    -H "X-Trace-ID: $trace_id" > /dev/null
                print_status "GET user $user_id (Trace: $trace_id)"
            fi
            ;;
        "GET_LIST")
            # Get user list
            page=$((RANDOM % 5 + 1))
            curl -s -X GET "$BACKEND_URL/api/users?page=$page&per_page=10" \
                -H "X-Trace-ID: $trace_id" > /dev/null
            print_status "GET users list page $page (Trace: $trace_id)"
            ;;
        "PUT")
            # Update user
            if [ ${#user_ids[@]} -gt 0 ]; then
                user_id=${user_ids[$((RANDOM % ${#user_ids[@]}))]}
                new_name="Updated User $i"
                curl -s -X PUT "$BACKEND_URL/api/users/$user_id" \
                    -H "Content-Type: application/json" \
                    -H "X-Trace-ID: $trace_id" \
                    -d "{\"name\": \"$new_name\"}" > /dev/null
                print_status "PUT user $user_id (Trace: $trace_id)"
            fi
            ;;
        "DELETE")
            # Delete user (only occasionally)
            if [ ${#user_ids[@]} -gt 10 ]; then
                user_id=${user_ids[$((RANDOM % ${#user_ids[@]}))]}
                curl -s -X DELETE "$BACKEND_URL/api/users/$user_id" \
                    -H "X-Trace-ID: $trace_id" > /dev/null
                print_status "DELETE user $user_id (Trace: $trace_id)"
                # Remove from array
                user_ids=("${user_ids[@]/$user_id}")
            fi
            ;;
    esac

    # Add random delay
    sleep $(echo "scale=2; $RANDOM/32767*0.5" | bc -l 2>/dev/null || echo "0.1")
done

print_step "4. Generating some error scenarios for testing..."

# Generate some 404 errors
for i in {1..5}; do
    trace_id=$(generate_trace_id)
    curl -s -X GET "$BACKEND_URL/api/users/999$i" \
        -H "X-Trace-ID: $trace_id" > /dev/null
    print_status "Generated 404 error (Trace: $trace_id)"
    sleep 0.2
done

# Generate some validation errors
for i in {1..3}; do
    trace_id=$(generate_trace_id)
    curl -s -X POST "$BACKEND_URL/api/users" \
        -H "Content-Type: application/json" \
        -H "X-Trace-ID: $trace_id" \
        -d "{\"name\": \"\", \"email\": \"invalid-email\"}" > /dev/null
    print_status "Generated validation error (Trace: $trace_id)"
    sleep 0.2
done

print_step "5. Checking observability data collection..."

# Wait a bit for logs and traces to be processed
print_status "Waiting 10 seconds for log and trace processing..."
sleep 10

# Check Elasticsearch logs
log_count=$(curl -s "http://localhost:9200/devsecops-logs-*/_count" | jq -r '.count' 2>/dev/null || echo "unknown")
print_status "Elasticsearch logs collected: $log_count"

# Check Jaeger traces
jaeger_services=$(curl -s "http://localhost:16686/api/services" | jq -r '.data | length' 2>/dev/null || echo "unknown")
print_status "Jaeger services discovered: $jaeger_services"

print_step "6. Sample Data Generation Complete!"

print_status "🎉 Sample data generation completed successfully!"
print_status ""
print_status "=== Generated Data ==="
print_status "Users created: ~$TOTAL_USERS"
print_status "Operations performed: $TOTAL_OPERATIONS"
print_status "Logs in Elasticsearch: $log_count"
print_status "Services in Jaeger: $jaeger_services"
print_status ""
print_status "=== Next Steps ==="
print_status "1. View application logs in Kibana:"
print_status "   http://localhost:5601"
print_status "   - Go to 'Discover' tab"
print_status "   - Select 'devsecops-logs-*' index pattern"
print_status "   - Filter by log_level, trace_id, or other fields"
print_status ""
print_status "2. Analyze traces in Jaeger:"
print_status "   http://localhost:16686"
print_status "   - Select 'devsecops-backend' service"
print_status "   - Look for traces with operations like GET, POST, PUT, DELETE"
print_status "   - Click on traces to see detailed timing information"
print_status ""
print_status "3. View metrics in Grafana:"
print_status "   http://localhost:3000 (admin/admin123)"
print_status "   - Check 'DevSecOps ELK & Jaeger Overview' dashboard"
print_status "   - Monitor HTTP request rates, response times, and error rates"
print_status ""
print_status "4. Monitor system health:"
print_status "   - Backend API: http://localhost:5000/health"
print_status "   - Elasticsearch: http://localhost:9200/_cluster/health"
print_status "   - Jaeger: http://localhost:16686/api/services"
