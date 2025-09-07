#!/bin/bash
set -e

echo "=== Enhanced Database Migration Script with Docker Support ==="
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

# Database configuration - supports both Docker and direct connection
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-devsecops_db}
DB_USER=${DB_USER:-devsecops_user}
DB_PASSWORD=${DB_PASSWORD:-secure_password_123}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

# Docker support
DOCKER_MODE=${DOCKER_MODE:-true}
POSTGRES_CONTAINER=${POSTGRES_CONTAINER:-devsecops-postgres}

print_status "Database Migration Configuration:"
print_status "Host: $DB_HOST"
print_status "Port: $DB_PORT"
print_status "Database: $DB_NAME"
print_status "User: $DB_USER"
print_status "Docker Mode: $DOCKER_MODE"

# Function to execute psql commands
execute_psql() {
    local command="$1"
    local database="${2:-postgres}"
    
    if [ "$DOCKER_MODE" = "true" ]; then
        docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" \
            psql -h localhost -p 5432 -U "$POSTGRES_USER" -d "$database" -c "$command"
    else
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$database" -c "$command"
    fi
}

# Function to execute psql files
execute_psql_file() {
    local file_path="$1"
    local database="$2"
    
    if [ "$DOCKER_MODE" = "true" ]; then
        # Copy file to container and execute
        docker cp "$file_path" "$POSTGRES_CONTAINER:/tmp/$(basename $file_path)"
        docker exec -e PGPASSWORD="$DB_PASSWORD" "$POSTGRES_CONTAINER" \
            psql -h localhost -p 5432 -U "$DB_USER" -d "$database" -f "/tmp/$(basename $file_path)"
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$database" -f "$file_path"
    fi
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    print_status "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if execute_psql "SELECT 1;" > /dev/null 2>&1; then
            print_status "✅ PostgreSQL is ready"
            return 0
        fi
        
        print_status "Waiting for PostgreSQL... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "❌ PostgreSQL is not ready after $max_attempts attempts"
    return 1
}

# Check if we're in Docker mode and container exists
if [ "$DOCKER_MODE" = "true" ]; then
    if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
        print_error "PostgreSQL container '$POSTGRES_CONTAINER' not found or not running"
        exit 1
    fi
fi

# Wait for PostgreSQL
if ! wait_for_postgres; then
    exit 1
fi

# Create database and user
print_status "Creating database and user..."
execute_psql "
-- Create database if it doesn't exist
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\\gexec

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
ALTER USER $DB_USER CREATEDB;
"

print_status "✅ Database and user created/verified"

# Check if init.sql exists
INIT_SQL_PATH="${INIT_SQL_PATH:-./database/scripts/init.sql}"
if [ ! -f "$INIT_SQL_PATH" ]; then
    print_warning "init.sql not found at $INIT_SQL_PATH, skipping database initialization"
else
    print_status "Running database initialization..."
    if execute_psql_file "$INIT_SQL_PATH" "$DB_NAME"; then
        print_status "✅ Database initialization completed successfully"
    else
        print_error "❌ Database initialization failed"
        exit 1
    fi
fi

# Verify tables were created
print_status "Verifying database setup..."
TABLE_COUNT=$(execute_psql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" "$DB_NAME" | grep -E "^\s*[0-9]+\s*$" | tr -d ' ')

if [ "$TABLE_COUNT" -gt 0 ] 2>/dev/null; then
    print_status "✅ Database setup verified - $TABLE_COUNT tables created"
    
    # Show sample data if users table exists
    if execute_psql "SELECT to_regclass('public.users');" "$DB_NAME" | grep -q "users"; then
        print_status "Sample users in database:"
        execute_psql "SELECT id, name, email, created_at FROM users LIMIT 5;" "$DB_NAME" 2>/dev/null || true
    fi
    
    # Show all tables
    print_status "Tables created:"
    execute_psql "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;" "$DB_NAME" 2>/dev/null || true
else
    print_warning "No tables found in database (this might be normal for a fresh setup)"
fi

print_status "🎉 Database migration completed successfully!"
print_status ""
print_status "Connection details:"
print_status "Host: $DB_HOST"
print_status "Port: $DB_PORT"
print_status "Database: $DB_NAME"
print_status "Username: $DB_USER"
print_status ""
print_status "Next steps:"
print_status "1. Start your backend application"
print_status "2. The application will create tables using SQLAlchemy if needed"
print_status "3. Check logs for any connection issues"

# Health check endpoint
print_status ""
print_status "You can verify the database connection using:"
print_status "curl http://localhost:5000/health"
