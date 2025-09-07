-- DevSecOps Database Initialization Script
-- Creates tables and initial data for the 3-tier application

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    resource VARCHAR(50) NOT NULL,
    details TEXT,
    ip_address INET,
    trace_id VARCHAR(100),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_trace_id ON audit_logs(trace_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);

-- Create function to update timestamp
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
INSERT INTO users (name, email, password_hash) VALUES 
    ('John Doe', 'john.doe@example.com', 'pbkdf2:sha256:260000$example$hash'),
    ('Jane Smith', 'jane.smith@example.com', 'pbkdf2:sha256:260000$example$hash'),
    ('Bob Johnson', 'bob.johnson@example.com', 'pbkdf2:sha256:260000$example$hash')
ON CONFLICT (email) DO NOTHING;

-- Insert sample audit logs
INSERT INTO audit_logs (user_id, action, resource, details, ip_address, trace_id) VALUES 
    (1, 'CREATE', 'user', 'Initial user creation', '127.0.0.1', 'trace-init-001'),
    (2, 'CREATE', 'user', 'Initial user creation', '127.0.0.1', 'trace-init-002'),
    (3, 'CREATE', 'user', 'Initial user creation', '127.0.0.1', 'trace-init-003');

-- Create view for active users
CREATE OR REPLACE VIEW active_users AS
SELECT id, name, email, created_at, updated_at
FROM users
WHERE is_active = TRUE;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO devsecops_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON audit_logs TO devsecops_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO devsecops_user;
GRANT SELECT ON active_users TO devsecops_user;

-- Display initialization status
SELECT 'Database initialized successfully!' as status;
SELECT COUNT(*) as user_count FROM users;
SELECT COUNT(*) as audit_log_count FROM audit_logs;
