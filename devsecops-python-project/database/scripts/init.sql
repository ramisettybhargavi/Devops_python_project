-- DevSecOps 3-Tier Database Initialization with ELK & Jaeger
-- PostgreSQL database setup script

-- Create database (run as superuser)
-- CREATE DATABASE devsecops_db;
-- CREATE USER devsecops_user WITH PASSWORD 'secure_password_123';
-- GRANT ALL PRIVILEGES ON DATABASE devsecops_db TO devsecops_user;

-- Connect to devsecops_db
\c devsecops_db;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create audit_logs table for security tracking with trace correlation
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    resource VARCHAR(50) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    trace_id VARCHAR(100),  -- For Jaeger trace correlation
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create observability_metrics table for application metrics
CREATE TABLE IF NOT EXISTS observability_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL NOT NULL,
    labels JSONB,
    trace_id VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_trace_id ON audit_logs(trace_id);
CREATE INDEX IF NOT EXISTS idx_observability_metrics_name ON observability_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_observability_metrics_timestamp ON observability_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_observability_metrics_trace_id ON observability_metrics(trace_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data
INSERT INTO users (name, email) VALUES
    ('John Doe', 'john.doe@example.com'),
    ('Jane Smith', 'jane.smith@example.com'),
    ('Bob Johnson', 'bob.johnson@example.com'),
    ('Alice Brown', 'alice.brown@example.com'),
    ('Charlie Wilson', 'charlie.wilson@example.com'),
    ('Diana Prince', 'diana.prince@example.com'),
    ('ELK Stack User', 'elk@devsecops.com'),
    ('Jaeger User', 'jaeger@devsecops.com')
ON CONFLICT (email) DO NOTHING;

-- Insert sample observability metrics
INSERT INTO observability_metrics (metric_name, metric_value, labels) VALUES
    ('app_startup_time', 2.5, '{"component": "backend", "environment": "development"}'),
    ('database_connections', 5, '{"pool": "main", "status": "active"}'),
    ('elk_integration_status', 1, '{"component": "logstash", "status": "healthy"}'),
    ('jaeger_integration_status', 1, '{"component": "jaeger", "status": "healthy"}');

-- Create read-only user for monitoring
CREATE USER monitoring_user WITH PASSWORD 'monitoring_pass_123';
GRANT CONNECT ON DATABASE devsecops_db TO monitoring_user;
GRANT USAGE ON SCHEMA public TO monitoring_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO monitoring_user;

-- Security configurations
-- Enable row level security (can be customized based on requirements)
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Grant permissions to application user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO devsecops_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO devsecops_user;

-- Create view for observability dashboard
CREATE OR REPLACE VIEW observability_summary AS
SELECT 
    DATE_TRUNC('hour', timestamp) as hour,
    COUNT(*) as total_operations,
    COUNT(DISTINCT trace_id) as unique_traces,
    AVG(CASE WHEN action = 'CREATE' THEN 1 ELSE 0 END) as create_rate,
    AVG(CASE WHEN action = 'READ' THEN 1 ELSE 0 END) as read_rate,
    AVG(CASE WHEN action = 'UPDATE' THEN 1 ELSE 0 END) as update_rate,
    AVG(CASE WHEN action = 'DELETE' THEN 1 ELSE 0 END) as delete_rate
FROM audit_logs 
WHERE timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', timestamp)
ORDER BY hour DESC;

GRANT SELECT ON observability_summary TO monitoring_user;
GRANT SELECT ON observability_summary TO devsecops_user;

COMMIT;
