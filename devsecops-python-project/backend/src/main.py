# Updated Backend main.py with Enhanced Health Check for Observability

#!/usr/bin/env python3
"""
DevSecOps 3-Tier Application - Backend API with ELK & Jaeger Integration
Flask REST API with PostgreSQL database, ELK logging, and Jaeger tracing
FIXED: Enhanced health checks and observability status endpoints
"""
from flask import Flask, jsonify, request, g
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from prometheus_client import Counter, Histogram, generate_latest
import logging
import os
import time
import uuid
import requests
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
from pythonjsonlogger import jsonlogger
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from sqlalchemy import text

# Configure structured logging for ELK
def setup_logging():
    """Setup structured JSON logging for ELK stack"""
    log_level = os.environ.get('LOG_LEVEL', 'INFO')
    logHandler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        fmt='%(asctime)s %(name)s %(levelname)s %(message)s %(pathname)s %(lineno)d',
        datefmt='%Y-%m-%dT%H:%M:%S'
    )
    logHandler.setFormatter(formatter)
    logger = logging.getLogger()
    logger.addHandler(logHandler)
    logger.setLevel(getattr(logging, log_level.upper()))
    return logger

# Setup OpenTelemetry tracing using OTLP exporter (modern)
def setup_tracing():
    """Setup OpenTelemetry distributed tracing with OTLP"""
    otlp_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://jaeger:4317')
    insecure = os.environ.get('OTEL_EXPORTER_OTLP_INSECURE', 'true').lower() == 'true'
    service_name = os.environ.get('SERVICE_NAME', 'devsecops-backend')

    resource = Resource.create({
        "service.name": service_name,
        "service.version": "1.0.0",
        "deployment.environment": os.environ.get('ENVIRONMENT', 'development')
    })
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)

    otlp_exporter = OTLPSpanExporter(
        endpoint=otlp_endpoint,
        insecure=insecure,
        headers={}
    )
    span_processor = BatchSpanProcessor(otlp_exporter)
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
with app.app_context():
    SQLAlchemyInstrumentor().instrument(engine=db.engine)
RequestsInstrumentor().instrument()

# Database Models (same as before)
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
    trace_id = db.Column(db.String(100))
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

# NEW: Enhanced observability status checking functions
def check_elasticsearch_health():
    """Check Elasticsearch cluster health"""
    try:
        start_time = time.time()
        response = requests.get(f"{app.config['ELASTICSEARCH_URL']}/_cluster/health", timeout=10)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            health_data = response.json()
            return {
                'healthy': health_data.get('status') in ['green', 'yellow'],
                'status': health_data.get('status'),
                'response_time': response_time,
                'details': f"Cluster: {health_data.get('cluster_name')}, Nodes: {health_data.get('number_of_nodes')}"
            }
        else:
            return {'healthy': False, 'status': 'error', 'response_time': response_time, 'details': f'HTTP {response.status_code}'}
    except Exception as e:
        return {'healthy': False, 'status': 'error', 'response_time': None, 'details': str(e)}

def check_jaeger_health():
    """Check Jaeger collector health"""
    try:
        start_time = time.time()
        # Check Jaeger health endpoint
        response = requests.get('http://jaeger:14269/', timeout=10)
        response_time = time.time() - start_time
        
        return {
            'healthy': response.status_code == 200,
            'status': 'healthy' if response.status_code == 200 else 'error',
            'response_time': response_time,
            'details': f'HTTP {response.status_code}'
        }
    except Exception as e:
        return {'healthy': False, 'status': 'error', 'response_time': None, 'details': str(e)}

def check_logstash_health():
    """Check Logstash health"""
    try:
        start_time = time.time()
        response = requests.get('http://logstash:9600/_node/stats', timeout=10)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            stats = response.json()
            return {
                'healthy': True,
                'status': 'healthy',
                'response_time': response_time,
                'details': f"Pipeline: {stats.get('pipeline', {}).get('events', {}).get('in', 0)} events"
            }
        else:
            return {'healthy': False, 'status': 'error', 'response_time': response_time, 'details': f'HTTP {response.status_code}'}
    except Exception as e:
        return {'healthy': False, 'status': 'error', 'response_time': None, 'details': str(e)}

def check_kibana_health():
    """Check Kibana health"""
    try:
        start_time = time.time()
        response = requests.get('http://kibana:5601/api/status', timeout=10)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            status_data = response.json()
            overall_status = status_data.get('status', {}).get('overall', {}).get('state', 'unknown')
            return {
                'healthy': overall_status == 'green',
                'status': overall_status,
                'response_time': response_time,
                'details': f"Status: {overall_status}"
            }
        else:
            return {'healthy': False, 'status': 'error', 'response_time': response_time, 'details': f'HTTP {response.status_code}'}
    except Exception as e:
        return {'healthy': False, 'status': 'error', 'response_time': None, 'details': str(e)}

# Middleware for request tracking and tracing (same as before)
@app.before_request
def before_request():
    request.start_time = time.time()
    trace_id = request.headers.get('X-Trace-ID') or str(uuid.uuid4())
    g.trace_id = trace_id
    span = tracer.start_span(f"{request.method} {request.endpoint}")
    span.set_attribute("http.method", request.method)
    span.set_attribute("http.url", request.url)
    span.set_attribute("trace.id", trace_id)
    g.span = span

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

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    REQUEST_DURATION.observe(request_duration)

    response.headers['X-Trace-ID'] = trace_id

    if hasattr(g, 'span'):
        g.span.set_attribute("http.status_code", response.status_code)
        g.span.set_attribute("http.response_size", len(response.get_data()))
        if response.status_code >= 400:
            from opentelemetry.trace import Status, StatusCode
            g.span.set_status(Status(StatusCode.ERROR))
        g.span.end()
        JAEGER_SPANS.labels(operation=request.endpoint or 'unknown').inc()

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

# ENHANCED: Health check endpoint with observability status
@app.route('/health', methods=['GET'])
def health_check():
    """Enhanced health check endpoint with observability stack status"""
    try:
        # Check database connectivity
        with app.app_context():
            db.session.execute(text('SELECT 1'))

        # Check observability stack
        observability_status = {
            'elasticsearch': check_elasticsearch_health(),
            'jaeger': check_jaeger_health(),
            'logstash': check_logstash_health(),
            'kibana': check_kibana_health()
        }

        # Determine overall health
        all_healthy = all(service['healthy'] for service in observability_status.values())
        database_healthy = True  # We've already tested this above

        overall_healthy = database_healthy and all_healthy

        health_status = {
            'status': 'healthy' if overall_healthy else 'degraded',
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'devsecops-backend',
            'version': '1.0.0',
            'uptime': time.time() - app.start_time if hasattr(app, 'start_time') else 0,
            'checks': {
                'database': 'connected' if database_healthy else 'disconnected',
                'application': 'running'
            },
            'observability': observability_status,
            'trace_id': getattr(g, 'trace_id', None)
        }

        status_code = 200 if overall_healthy else 503
        logger.info(f"Health check completed - Status: {health_status['status']}", 
                   extra={'trace_id': health_status['trace_id']})
        
        return jsonify(health_status), status_code

    except Exception as e:
        logger.error(f"Health check failed: {str(e)}", extra={'trace_id': getattr(g, 'trace_id', None)})
        return jsonify({
            'status': 'unhealthy',
            'timestamp': datetime.utcnow().isoformat(),
            'error': str(e),
            'trace_id': getattr(g, 'trace_id', None)
        }), 503

# Prometheus metrics endpoint (same as before)
@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    try:
        metrics_data = generate_latest()
        logger.info("Metrics endpoint accessed", extra={'trace_id': getattr(g, 'trace_id', None)})
        return metrics_data, 200, {'Content-Type': 'text/plain; charset=utf-8'}
    except Exception as e:
        logger.error(f"Metrics endpoint failed: {str(e)}", extra={'trace_id': getattr(g, 'trace_id', None)})
        return jsonify({'error': 'Metrics unavailable'}), 500

# Sample CRUD endpoints (same as before)
@app.route('/api/users', methods=['GET'])
def get_users():
    try:
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 10, type=int), 100)  # Max 100 per page
        
        DB_OPERATIONS.labels(operation='SELECT', table='users').inc()
        users_query = User.query.filter_by(is_active=True)
        pagination = users_query.paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        users = pagination.items
        
        audit_log = AuditLog(
            action='LIST_USERS',
            resource='users',
            details=f'Retrieved {len(users)} users (page {page})',
            ip_address=request.remote_addr,
            trace_id=getattr(g, 'trace_id', None)
        )
        db.session.add(audit_log)
        db.session.commit()

        return jsonify({
            'users': [u.to_dict() for u in users],
            'pagination': {
                'page': page,
                'pages': pagination.pages,
                'per_page': per_page,
                'total': pagination.total,
                'has_next': pagination.has_next,
                'has_prev': pagination.has_prev
            },
            'trace_id': getattr(g, 'trace_id', None)
        }), 200

    except Exception as e:
        logger.error(f"Failed to get users: {str(e)}", extra={'trace_id': getattr(g, 'trace_id', None)})
        return jsonify({'error': 'Failed to retrieve users'}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    try:
        data = request.get_json()
        if not data or not data.get('name') or not data.get('email'):
            return jsonify({'error': 'Name and email are required'}), 400

        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': 'User with this email already exists'}), 409

        user = User(name=data['name'], email=data['email'])
        if data.get('password'):
            user.set_password(data['password'])

        DB_OPERATIONS.labels(operation='INSERT', table='users').inc()
        db.session.add(user)
        db.session.commit()

        audit_log = AuditLog(
            user_id=user.id,
            action='CREATE_USER',
            resource='users',
            details=f'Created user: {user.email}',
            ip_address=request.remote_addr,
            trace_id=getattr(g, 'trace_id', None)
        )
        db.session.add(audit_log)
        db.session.commit()

        logger.info(f"User created: {user.email}", extra={'trace_id': getattr(g, 'trace_id', None)})
        return jsonify({
            'message': 'User created successfully',
            'user': user.to_dict(),
            'trace_id': getattr(g, 'trace_id', None)
        }), 201

    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to create user: {str(e)}", extra={'trace_id': getattr(g, 'trace_id', None)})
        return jsonify({'error': 'Failed to create user'}), 500

# Utility to wait for DB readiness
def wait_for_db(app, max_retries=30):
    import sqlalchemy
    for attempt in range(max_retries):
        try:
            with app.app_context():
                db.session.execute(text('SELECT 1'))
            logger.info("Database connection successful")
            return True
        except sqlalchemy.exc.OperationalError:
            logger.warning(f"Database not ready, retry attempt {attempt + 1}/{max_retries}")
            time.sleep(2)
    return False

if __name__ == '__main__':
    # Store application start time for uptime calculation
    app.start_time = time.time()
    
    if not wait_for_db(app):
        logger.error("Could not connect to the database after maximum retries")
        exit(1)

    with app.app_context():
        db.create_all()

    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'false').lower() == 'true'
    logger.info("Starting DevSecOps Backend API with Enhanced Observability", extra={
        "port": port,
        "debug": debug,
        "elasticsearch_url": app.config['ELASTICSEARCH_URL'],
        "logstash_host": app.config['LOGSTASH_HOST'],
        "logstash_port": app.config['LOGSTASH_PORT']
    })
    app.run(host='0.0.0.0', port=port, debug=debug)
