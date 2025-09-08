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
# Remove deprecated Jaeger Thrift exporter import
# from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
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

# Setup OpenTelemetry tracing using OTLP exporter (modern)
def setup_tracing():
    """Setup OpenTelemetry distributed tracing with OTLP"""
    # Use OTLP endpoint (modern approach)
    otlp_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://jaeger:4317')
    insecure = os.environ.get('OTEL_EXPORTER_OTLP_INSECURE', 'true').lower() == 'true'
    service_name = os.environ.get('SERVICE_NAME', 'devsecops-backend')

    # Create tracer provider with resource information
    resource = Resource.create({
        "service.name": service_name,
        "service.version": "1.0.0",
        "deployment.environment": os.environ.get('ENVIRONMENT', 'development')
    })
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)

    # Create OTLP exporter with proper configuration
    otlp_exporter = OTLPSpanExporter(
        endpoint=otlp_endpoint,
        insecure=insecure,
        # Add headers if needed for authentication
        headers={}
    )

    # Create span processor with optimized batch settings
    span_processor = BatchSpanProcessor(
        otlp_exporter,
        max_queue_size=2048,
        max_export_batch_size=512,
        export_timeout=30,
        schedule_delay=5
    )
    provider.add_span_processor(span_processor)

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
DATABASE_URL = os.environ.get(
    'DATABASE_URL', 
    'postgresql://devsecops_user:secure_password_123@localhost:5432/devsecops_db'
)
app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'pool_pre_ping': True,
    'pool_recycle': 300,
    'connect_args': {
        'connect_timeout': 30,
        'application_name': 'devsecops-backend',
    }
}
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
            from opentelemetry.trace import Status, StatusCode
            g.span.set_status(Status(StatusCode.ERROR))
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

# Utility functions and API routes remain unchanged...
def wait_for_db(app, max_retries=30):
    """Wait for the database to be ready before starting the app."""
    import time
    import sqlalchemy
    for attempt in range(max_retries):
        try:
            with app.app_context():
                db.session.execute('SELECT 1')
                logger.info("Database connection successful")
                return True
        except sqlalchemy.exc.OperationalError:
            logger.warning(f"Database not ready, retry attempt {attempt + 1}/{max_retries}")
            time.sleep(2)
    return False

if __name__ == '__main__':
    if not wait_for_db(app):
        logger.error("Could not connect to the database after maximum retries")
        exit(1)
    with app.app_context():
        db.create_all()
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
