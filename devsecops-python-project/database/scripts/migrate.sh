#!/bin/bash
set -e

echo "=== Database Migration Script with ELK & Jaeger Support ==="
echo "Setting up PostgreSQL database for DevSecOps 3-Tier Application with observability"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Database configuration
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-devsecops_db}
DB_USER=${DB_USER:-devsecops_user}
DB_PASSWORD=${DB_PASSWORD:-secure_password_123}
POSTGRES_USER=${POSTGRES_USER:-postgres}

print_status "Database Migration Configuration:"
print_status "Host: $DB_HOST"
print_status "Port: $DB_PORT"
print_status "Database: $DB_NAME"
print_status "User: $DB_USER"

# Check if PostgreSQL is available
if ! command -v psql &> /dev/null; then
    print_error "PostgreSQL client (psql) not found. Please install PostgreSQL client."
    exit 1
fi

# Test connection to PostgreSQL server
print_status "Testing PostgreSQL connection..."
if ! PGPASSWORD=${POSTGRES_PASSWORD:-postgres} psql -h $DB_HOST -p $DB_PORT -U $POSTGRES_USER -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    print_error "Cannot connect to PostgreSQL server. Please check connection settings."
    exit 1
fi

print_status "✅ PostgreSQL connection successful"

# Create database and user
print_status "Creating database and user..."
PGPASSWORD=${POSTGRES_PASSWORD:-postgres} psql -h $DB_HOST -p $DB_PORT -U $POSTGRES_USER -d postgres << EOF
-- Create database if it doesn't exist
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Create user if it doesn't exist
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$DB_USER') THEN
      CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
   END IF;
END
\$\$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

print_status "✅ Database and user created/verified"

# Run initialization script
print_status "Running database initialization with observability support..."
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f init.sql; then
    print_status "✅ Database initialization completed successfully"
else
    print_error "❌ Database initialization failed"
    exit 1
fi

# Verify tables were created
print_status "Verifying database setup..."
TABLE_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")

if [ "$TABLE_COUNT" -gt 0 ]; then
    print_status "✅ Database setup verified - $TABLE_COUNT tables created"

    # Show sample data
    print_status "Sample users in database:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT id, name, email, created_at FROM users LIMIT 8;"

    # Show observability tables
    print_status "Observability tables created:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%audit%' OR table_name LIKE '%observability%';"
else
    print_error "❌ Database verification failed - no tables found"
    exit 1
fi

print_status "🎉 Database migration with ELK & Jaeger support completed successfully!"
print_status ""
print_status "Connection details:"
print_status "Host: $DB_HOST"
print_status "Port: $DB_PORT"
print_status "Database: $DB_NAME"
print_status "Username: $DB_USER"
print_status ""
print_status "Observability features enabled:"
print_status "- Audit logging with trace correlation"
print_status "- Observability metrics collection"
print_status "- Monitoring user access"
print_status ""
print_status "You can now start the backend application with ELK and Jaeger integration."
