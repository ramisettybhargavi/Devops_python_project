#!/usr/bin/env python3
"""
DevSecOps 3-Tier Application - Backend API with ELK & Jaeger Integration
Flask REST API with PostgreSQL database, ELK logging, and Jaeger tracing
"""

from flask import Flask, jsonify, request, g
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from prometheus_client import Counter, Histogram, generate_latest
import logging
import json
import os
import time
import uuid
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
import requests
from pythonjsonlogger import jsonlogger
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
import socket
import re

# Configure structured logging for ELK
def setup_logging():
    """Setup structured JSON logging for ELK stack"""
    log_level = os.environ.get('LOG_LEVEL', 'INFO')

    # Create JSON formatter
    logHandler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        fmt='%(asctime)s %(name)s %(levelname)s %(message)s %(pathname)s %(lineno)d',
        datefmt='%Y-%m-%dT%H:%M:%S'
    )
    logHandler.setFormatter(formatter)

    # Configure logger
    logger = logging.getLogger()
    logger.addHandler(logHandler)
    logger.setLevel(getattr(logging, log_level.upper()))

    return logger

# Setup Jaeger tracing
def setup_tracing():
    """Setup Jaeger distributed tracing"""
    jaeger_endpoint = os.environ.get('JAEGER_ENDPOINT', 'http://localhost:14268/api/traces')
    service_name = os.environ.get('SERVICE_NAME', 'devsecops-backend')

    # Create tracer provider with resource information
    resource = Resource.create({
        "service.name": service_name,
        "service.version": "1.0.0",
        "deployment.environment": os.environ.get('ENVIRONMENT', 'development')
    })

    trace.set_tracer_provider(TracerProvider(resource=resource))

    # Create Jaeger exporter
    jaeger_exporter = JaegerExporter(
        agent_host_name=os.environ.get('JAEGER_AGENT_HOST', 'localhost'),
        agent_port=int(os.environ.get('JAEGER_AGENT_PORT', 6831)),
    )

    # Create span processor
    span_processor = BatchSpanProcessor(jaeger_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)

    return trace.get_tracer(__name__)

# Initialize logging and tracing
logger = setup_logging()
tracer = setup_tracing()

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')
DB_OPERATIONS = Counter('database_operations_total', 'Total database operations', ['operation', 'table'])
JAEGER_SPANS = Counter('jaeger_spans_total', 'Total Jaeger spans created', ['operation'])
ELK_LOGS = Counter('elk_logs_total', 'Total logs sent to ELK', ['level'])

app = Flask(__name__)

# Enable CORS for frontend integration
CORS(app, origins=[
    'http://localhost:3000', 
    'http://localhost:8080',
    'http://localhost:8000'
])

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 
    'postgresql://devsecops_user:secure_password_123@localhost:5432/devsecops_db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', str(uuid.uuid4()))

# ELK Stack configuration
app.config['ELASTICSEARCH_URL'] = os.environ.get('ELASTICSEARCH_URL', 'http://localhost:9200')
app.config['LOGSTASH_HOST'] = os.environ.get('LOGSTASH_HOST', 'localhost')
app.config['LOGSTASH_PORT'] = int(os.environ.get('LOGSTASH_PORT', 5044))

# Initialize extensions
db = SQLAlchemy(app)
migrate = Migrate(app, db)

# Initialize OpenTelemetry instrumentation
FlaskInstrumentor().instrument_app(app)
SQLAlchemyInstrumentor().instrument(engine=db.engine)
RequestsInstrumentor().instrument()

# Database Models
class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'is_active': self.is_active
        }

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<User {self.email}>'

class AuditLog(db.Model):
    __tablename__ = 'audit_logs'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    action = db.Column(db.String(50), nullable=False)
    resource = db.Column(db.String(50), nullable=False)
    details = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
    trace_id = db.Column(db.String(100))  # Store trace ID for correlation
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'action': self.action,
            'resource': self.resource,
            'details': self.details,
            'ip_address': self.ip_address,
            'trace_id': self.trace_id,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }

# Middleware for request tracking and tracing
@app.before_request
def before_request():
    request.start_time = time.time()

    # Get or generate trace ID
    trace_id = request.headers.get('X-Trace-ID') or str(uuid.uuid4())
    g.trace_id = trace_id

    # Start a new span for this request
    span = tracer.start_span(f"{request.method} {request.endpoint}")
    span.set_attribute("http.method", request.method)
    span.set_attribute("http.url", request.url)
    span.set_attribute("trace.id", trace_id)
    g.span = span

    # Structured logging
    logger.info("Request started", extra={
        "trace_id": trace_id,
        "method": request.method,
        "path": request.path,
        "remote_addr": request.remote_addr,
        "user_agent": request.headers.get('User-Agent', '')
    })

    ELK_LOGS.labels(level='info').inc()

@app.after_request
def after_request(response):
    request_duration = time.time() - request.start_time
    trace_id = getattr(g, 'trace_id', 'unknown')

    # Update Prometheus metrics
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    REQUEST_DURATION.observe(request_duration)

    # Add trace ID to response headers
    response.headers['X-Trace-ID'] = trace_id

    # Finish span
    if hasattr(g, 'span'):
        g.span.set_attribute("http.status_code", response.status_code)
        g.span.set_attribute("http.response_size", len(response.get_data()))
        if response.status_code >= 400:
            g.span.set_status(trace.Status(trace.StatusCode.ERROR))
        g.span.end()
        JAEGER_SPANS.labels(operation=request.endpoint or 'unknown').inc()

    # Structured logging
    log_level = 'error' if response.status_code >= 400 else 'info'
    logger.log(
        getattr(logging, log_level.upper()),
        "Request completed",
        extra={
            "trace_id": trace_id,
            "method": request.method,
            "path": request.path,
            "status_code": response.status_code,
            "duration_ms": request_duration * 1000,
            "response_size": len(response.get_data())
        }
    )

    ELK_LOGS.labels(level=log_level).inc()
    return response

# Utility functions
def log_audit(action, resource, details=None, user_id=None):
    """Log audit trail for security and compliance with tracing"""
    try:
        trace_id = getattr(g, 'trace_id', str(uuid.uuid4()))

        audit_log = AuditLog(
            user_id=user_id,
            action=action,
            resource=resource,
            details=details,
            ip_address=request.remote_addr,
            trace_id=trace_id
        )
        db.session.add(audit_log)
        db.session.commit()
        DB_OPERATIONS.labels(operation='INSERT', table='audit_logs').inc()

        # Structured logging for audit
        logger.info("Audit log created", extra={
            "trace_id": trace_id,
            "action": action,
            "resource": resource,
            "user_id": user_id,
            "details": details,
            "ip_address": request.remote_addr
        })

    except Exception as e:
        logger.error("Failed to log audit", extra={
            "trace_id": getattr(g, 'trace_id', 'unknown'),
            "error": str(e),
            "action": action,
            "resource": resource
        })

def validate_email(email):
    """Basic email validation"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def check_service_health(url, timeout=5):
    """Generic service health check"""
    try:
        response = requests.get(url, timeout=timeout)
        return {
            "status": "healthy" if response.status_code == 200 else "unhealthy",
            "healthy": response.status_code == 200,
            "response_time": response.elapsed.total_seconds()
        }
    except Exception as e:
        return {"status": "error", "healthy": False, "error": str(e)}

def check_elasticsearch_health():
    """Check Elasticsearch cluster health"""
    return check_service_health(f"{app.config['ELASTICSEARCH_URL']}/_cluster/health")

def check_kibana_health():
    """Check Kibana health"""
    kibana_url = os.environ.get('KIBANA_URL', 'http://localhost:5601')
    return check_service_health(f"{kibana_url}/api/status")

def check_jaeger_health():
    """Check Jaeger health"""
    jaeger_url = os.environ.get('JAEGER_QUERY_URL', 'http://localhost:16686')
    return check_service_health(f"{jaeger_url}/api/services")

def check_logstash_health():
    """Check Logstash health"""
    logstash_url = f"http://{app.config['LOGSTASH_HOST']}:9600"
    return check_service_health(f"{logstash_url}/_node/stats")

# API Routes
@app.route('/health', methods=['GET'])
def health_check():
    """Comprehensive health check endpoint"""
    with tracer.start_as_current_span("health_check") as span:
        try:
            # Test database connection
            db.session.execute('SELECT 1')
            db_status = "healthy"
            span.set_attribute("database.status", "healthy")
        except Exception as e:
            logger.error("Database health check failed", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "error": str(e)
            })
            db_status = "unhealthy"
            span.set_attribute("database.status", "unhealthy")
            span.set_status(trace.Status(trace.StatusCode.ERROR))

        # Check observability stack
        health_data = {
            "status": "healthy" if db_status == "healthy" else "unhealthy",
            "timestamp": datetime.utcnow().isoformat(),
            "service": "devsecops-backend",
            "version": "1.0.0",
            "database": db_status,
            "observability": {
                "elasticsearch": check_elasticsearch_health(),
                "kibana": check_kibana_health(),
                "jaeger": check_jaeger_health(),
                "logstash": check_logstash_health()
            },
            "uptime": time.time() - app.start_time if hasattr(app, 'start_time') else 0,
            "trace_id": getattr(g, 'trace_id', 'unknown')
        }

        status_code = 200 if db_status == "healthy" else 503
        return jsonify(health_data), status_code

# Observability endpoints
@app.route('/observability/status', methods=['GET'])
def observability_status():
    """Complete observability status"""
    with tracer.start_as_current_span("observability_status"):
        status = {
            "elasticsearch": check_elasticsearch_health(),
            "kibana": check_kibana_health(),
            "jaeger": check_jaeger_health(),
            "logstash": check_logstash_health()
        }
        return jsonify(status)

@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

# User Management API
@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all active users with pagination"""
    with tracer.start_as_current_span("get_users") as span:
        try:
            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 10, type=int), 100)

            span.set_attributes({
                "pagination.page": page,
                "pagination.per_page": per_page
            })

            users_query = User.query.filter_by(is_active=True).order_by(User.created_at.desc())
            users_paginated = users_query.paginate(
                page=page, per_page=per_page, error_out=False
            )

            users_data = [user.to_dict() for user in users_paginated.items]

            DB_OPERATIONS.labels(operation='SELECT', table='users').inc()
            span.set_attribute("users.count", len(users_data))

            log_audit("READ", "users", f"Retrieved {len(users_data)} users")

            return jsonify({
                "users": users_data,
                "pagination": {
                    "page": page,
                    "per_page": per_page,
                    "total": users_paginated.total,
                    "pages": users_paginated.pages,
                    "has_next": users_paginated.has_next,
                    "has_prev": users_paginated.has_prev
                }
            }), 200

        except Exception as e:
            logger.error("Error fetching users", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "error": str(e)
            })
            span.set_status(trace.Status(trace.StatusCode.ERROR))
            return jsonify({"error": "Internal server error"}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    with tracer.start_as_current_span("create_user") as span:
        try:
            data = request.get_json()
            if not data:
                return jsonify({"error": "No data provided"}), 400

            # Validate required fields
            required_fields = ['name', 'email']
            missing_fields = [field for field in required_fields if not data.get(field)]
            if missing_fields:
                return jsonify({"error": f"Missing required fields: {', '.join(missing_fields)}"}), 400

            # Validate email format
            if not validate_email(data['email']):
                return jsonify({"error": "Invalid email format"}), 400

            # Check if user already exists
            existing_user = User.query.filter_by(email=data['email']).first()
            if existing_user:
                return jsonify({"error": "User with this email already exists"}), 409

            # Create new user
            user = User(
                name=data['name'].strip(),
                email=data['email'].strip().lower()
            )

            if data.get('password'):
                user.set_password(data['password'])

            db.session.add(user)
            db.session.commit()

            DB_OPERATIONS.labels(operation='INSERT', table='users').inc()
            span.set_attribute("user.id", user.id)
            span.set_attribute("user.email", user.email)

            log_audit("CREATE", "user", f"Created user {user.email}", user.id)

            logger.info("User created successfully", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "user_id": user.id,
                "email": user.email
            })

            return jsonify({
                "message": "User created successfully",
                "user": user.to_dict()
            }), 201

        except Exception as e:
            db.session.rollback()
            logger.error("Error creating user", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "error": str(e)
            })
            span.set_status(trace.Status(trace.StatusCode.ERROR))
            return jsonify({"error": "Internal server error"}), 500

@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user by ID"""
    with tracer.start_as_current_span("get_user") as span:
        try:
            user = User.query.filter_by(id=user_id, is_active=True).first()
            if not user:
                return jsonify({"error": "User not found"}), 404

            span.set_attribute("user.id", user.id)
            span.set_attribute("user.email", user.email)

            DB_OPERATIONS.labels(operation='SELECT', table='users').inc()
            log_audit("READ", "user", f"Retrieved user {user.email}", user.id)

            return jsonify({"user": user.to_dict()}), 200

        except Exception as e:
            logger.error("Error fetching user", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "user_id": user_id,
                "error": str(e)
            })
            span.set_status(trace.Status(trace.StatusCode.ERROR))
            return jsonify({"error": "Internal server error"}), 500

@app.route('/api/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Update a user"""
    with tracer.start_as_current_span("update_user") as span:
        try:
            user = User.query.filter_by(id=user_id, is_active=True).first()
            if not user:
                return jsonify({"error": "User not found"}), 404

            data = request.get_json()
            if not data:
                return jsonify({"error": "No data provided"}), 400

            # Update fields
            if 'name' in data:
                user.name = data['name'].strip()
            
            if 'email' in data:
                email = data['email'].strip().lower()
                if not validate_email(email):
                    return jsonify({"error": "Invalid email format"}), 400
                
                # Check if email is already taken by another user
                existing_user = User.query.filter(User.email == email, User.id != user_id).first()
                if existing_user:
                    return jsonify({"error": "Email already taken"}), 409
                
                user.email = email

            if 'password' in data:
                user.set_password(data['password'])

            user.updated_at = datetime.utcnow()
            db.session.commit()

            DB_OPERATIONS.labels(operation='UPDATE', table='users').inc()
            span.set_attribute("user.id", user.id)
            span.set_attribute("user.email", user.email)

            log_audit("UPDATE", "user", f"Updated user {user.email}", user.id)

            return jsonify({
                "message": "User updated successfully",
                "user": user.to_dict()
            }), 200

        except Exception as e:
            db.session.rollback()
            logger.error("Error updating user", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "user_id": user_id,
                "error": str(e)
            })
            span.set_status(trace.Status(trace.StatusCode.ERROR))
            return jsonify({"error": "Internal server error"}), 500

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Soft delete a user"""
    with tracer.start_as_current_span("delete_user") as span:
        try:
            user = User.query.filter_by(id=user_id, is_active=True).first()
            if not user:
                return jsonify({"error": "User not found"}), 404

            # Soft delete
            user.is_active = False
            user.updated_at = datetime.utcnow()
            db.session.commit()

            DB_OPERATIONS.labels(operation='UPDATE', table='users').inc()
            span.set_attribute("user.id", user.id)
            span.set_attribute("user.email", user.email)

            log_audit("DELETE", "user", f"Deleted user {user.email}", user.id)

            return jsonify({"message": "User deleted successfully"}), 200

        except Exception as e:
            db.session.rollback()
            logger.error("Error deleting user", extra={
                "trace_id": getattr(g, 'trace_id', 'unknown'),
                "user_id": user_id,
                "error": str(e)
            })
            span.set_status(trace.Status(trace.StatusCode.ERROR))
            return jsonify({"error": "Internal server error"}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Resource not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    logger.error("Internal server error", extra={
        "trace_id": getattr(g, 'trace_id', 'unknown'),
        "error": str(error)
    })
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    # Initialize database
    app.start_time = time.time()

    with app.app_context():
        try:
            db.create_all()
            logger.info("Database initialized successfully", extra={
                "database_url": app.config['SQLALCHEMY_DATABASE_URI']
            })
        except Exception as e:
            logger.error("Database initialization failed", extra={
                "error": str(e)
            })
            raise

    # Start the application
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'false').lower() == 'true'

    logger.info("Starting DevSecOps Backend API with ELK & Jaeger", extra={
        "port": port,
        "debug": debug,
        "elasticsearch_url": app.config['ELASTICSEARCH_URL'],
        "logstash_host": app.config['LOGSTASH_HOST'],
        "logstash_port": app.config['LOGSTASH_PORT']
    })

    app.run(host='0.0.0.0', port=port, debug=debug)
