# DevSecOps 3-Tier Application with ELK Stack & Jaeger Tracing

![DevSecOps](https://img.shields.io/badge/DevSecOps-Complete-brightgreen.svg)
![ELK Stack](https://img.shields.io/badge/Logging-ELK%20Stack-orange.svg)
![Jaeger](https://img.shields.io/badge/Tracing-Jaeger-blue.svg)
![3-Tier](https://img.shields.io/badge/Architecture-3--Tier-blue.svg)
![CI/CD](https://img.shields.io/badge/CI%2FCD-Jenkins%20%7C%20GitHub%20Actions-orange.svg)

## 🚀 Overview

This is a **production-ready 3-tier DevSecOps application** with comprehensive **ELK Stack logging** and **Jaeger distributed tracing**. The application demonstrates modern observability practices including structured logging, distributed tracing, metrics collection, and comprehensive security scanning.

## 🏗️ Enhanced Architecture with ELK & Jaeger

### 3-Tier Application Stack with Full Observability

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FRONTEND      │    │    BACKEND      │    │    DATABASE     │
│   (Tier 1)      │    │    (Tier 2)     │    │    (Tier 3)     │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • HTML/CSS/JS   │────│ • Python Flask  │────│ • PostgreSQL    │
│ • Nginx         │    │ • REST API      │    │ • Data Storage  │
│ • Bootstrap UI  │    │ • ELK Integration│   │ • Observability │
│ • Trace Headers │    │ • Jaeger Tracing│   │ • Audit Logs    │
└─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                          OBSERVABILITY LAYER                           │
├─────────────────┬─────────────────┬─────────────────┬─────────────────┤
│  ELK STACK      │  DISTRIBUTED    │     METRICS     │   VISUALIZATION │
│                 │    TRACING      │                 │                 │
│ • Elasticsearch │ • Jaeger        │ • Prometheus    │ • Grafana       │
│ • Logstash      │ • Trace Collect │ • App Metrics   │ • Dashboards    │
│ • Kibana        │ • Service Map   │ • System Metrics│ • Alerting      │
│ • Log Analysis  │ • Performance   │ • Custom KPIs   │ • Monitoring    │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

## 🎯 Key Features

### 📊 **Complete ELK Stack Integration**
- **Elasticsearch**: Log storage and search with optimized indices
- **Logstash**: Log processing, filtering, and enrichment with grok patterns
- **Kibana**: Log visualization, dashboards, and analysis tools
- **Structured Logging**: JSON formatted logs with correlation IDs

### 🕸️ **Jaeger Distributed Tracing**
- **End-to-end Tracing**: Request flow across all application tiers
- **Performance Analysis**: Response time and bottleneck identification
- **Service Dependencies**: Visual service topology and call graphs
- **Trace Correlation**: Link traces with logs using trace IDs

### 📈 **Enhanced Observability Stack**
- **Prometheus**: Metrics collection from all application components
- **Grafana**: Integrated dashboards showing metrics, logs, and traces
- **Custom Dashboards**: Pre-built dashboards for ELK and Jaeger metrics
- **Alerting**: Prometheus alerting rules for ELK and Jaeger health

### 🔒 **Comprehensive Security**
- **SAST**: SonarQube integration with ELK configuration scanning
- **Container Security**: Trivy scanning for ELK stack and Jaeger images
- **Audit Logging**: Security events with trace correlation
- **Configuration Security**: Secure ELK and Jaeger configurations

## 🚀 Quick Start

### Prerequisites
- **Docker** (v20.10+) and Docker Compose
- **Python** (3.11+) for backend development
- **Node.js** (18+) for frontend tooling
- **8GB RAM minimum** (16GB recommended for full ELK stack)
- **kubectl** & **AWS CLI** (for EKS deployment)

### 1. Start Complete Stack with ELK & Jaeger

```bash
# Clone the repository
git clone <your-repo-url>
cd devsecops-3tier-elk-project

# Start complete observability stack
docker-compose up -d

# Wait for all services to be ready (may take 5-10 minutes)
./scripts/wait-for-stack.sh
```

### 2. Access All Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://localhost:8080 | - |
| **Backend API** | http://localhost:5000 | - |
| **Kibana (Logs)** | http://localhost:5601 | - |
| **Jaeger (Tracing)** | http://localhost:16686 | - |
| **Grafana (Metrics)** | http://localhost:3000 | admin/admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Elasticsearch** | http://localhost:9200 | - |
| **Database Admin** | http://localhost:5050 | admin@devsecops.com/admin123 |

### 3. Generate Sample Data

```bash
# Create sample users (generates traces and logs)
./scripts/generate-sample-data.sh

# View traces in Jaeger: http://localhost:16686
# View logs in Kibana: http://localhost:5601
# View metrics in Grafana: http://localhost:3000
```

## 📁 Enhanced Project Structure

```
devsecops-3tier-elk-project/
├── frontend/                        # Frontend with trace headers
│   ├── src/
│   │   ├── index.html              # Enhanced UI with observability status
│   │   ├── js/app.js               # ELK & Jaeger integration
│   │   └── css/style.css           # Updated styling
│   └── Dockerfile                  # Multi-stage build
│
├── backend/                         # Backend with ELK & Jaeger
│   ├── src/main.py                 # Flask API with full observability
│   ├── requirements.txt            # Enhanced dependencies
│   ├── tests/unit/                 # Unit tests
│   ├── tests/integration/          # Integration tests with observability
│   └── Dockerfile                  # Production container
│
├── database/                        # Enhanced database
│   ├── scripts/init.sql            # Schema with observability tables
│   ├── scripts/migrate.sh          # Migration with observability support
│   └── docker-compose.yml         # PostgreSQL with monitoring
│
├── observability/                   # Complete observability stack
│   ├── elasticsearch/
│   │   ├── elasticsearch.yml       # ES configuration
│   │   └── docker-compose.yml     # ES container setup
│   ├── logstash/
│   │   ├── logstash.conf           # Log processing pipeline
│   │   ├── logstash.yml           # LS configuration
│   │   └── docker-compose.yml     # LS container setup
│   ├── kibana/
│   │   ├── kibana.yml             # Kibana configuration
│   │   ├── dashboards/            # Pre-built dashboards
│   │   └── docker-compose.yml     # Kibana container
│   ├── jaeger/
│   │   ├── jaeger-config.json     # Sampling strategies
│   │   ├── setup.sh               # Jaeger setup script
│   │   └── docker-compose.yml     # Jaeger all-in-one
│   ├── prometheus/
│   │   ├── prometheus.yaml        # Prometheus with ELK/Jaeger targets
│   │   ├── rules/                 # Alerting rules
│   │   └── docker-compose.yml     # Prometheus container
│   └── grafana/
│       ├── grafana.ini           # Grafana configuration
│       ├── provisioning/         # Datasources & dashboards
│       ├── dashboards/           # ELK & Jaeger dashboards
│       └── docker-compose.yml    # Grafana container
│
├── ci-cd/                          # Enhanced CI/CD
│   ├── jenkins/Jenkinsfile        # Jenkins with ELK & Jaeger
│   └── .github/workflows/         # GitHub Actions with observability
│
├── infra/                          # Infrastructure
│   ├── k8s/                       # Kubernetes manifests
│   ├── helm/                      # Helm charts with observability
│   └── eks-cluster/               # EKS with ELK & Jaeger
│
├── scripts/                        # Enhanced utility scripts
│   ├── run_all_tests.sh           # Testing with observability
│   ├── build_all.sh               # Build all components
│   ├── deploy.sh                  # Deploy with observability
│   ├── generate-sample-data.sh    # Generate test data
│   └── wait-for-stack.sh          # Wait for all services
│
└── docker-compose.yml             # Complete stack orchestration
```

## 🔍 ELK Stack Configuration

### Elasticsearch
- **Version**: 8.10.0 with security disabled for development
- **Indices**: Automatic creation of `devsecops-logs-*` indices
- **Storage**: Persistent volumes with 30-day retention
- **Performance**: Optimized for log storage and search

### Logstash
- **Pipeline**: Multi-input pipeline (HTTP, Beats, TCP, Syslog)
- **Processing**: JSON parsing, grok patterns, field enrichment
- **Output**: Structured data to Elasticsearch with templates
- **Monitoring**: Built-in monitoring and dead letter queue

### Kibana
- **Dashboards**: Pre-configured dashboards for application logs
- **Index Patterns**: Automatic pattern creation for log indices  
- **Visualizations**: Error rates, response times, trace correlation
- **Alerts**: Integration with ElastAlert for log-based alerting

## 🔍 Jaeger Tracing Configuration

### Jaeger All-in-One Setup
- **Collector**: HTTP and gRPC endpoints for trace ingestion
- **Agent**: UDP endpoint for application instrumentation
- **Query**: Web UI for trace analysis and service maps
- **Storage**: Elasticsearch backend for trace persistence

### Application Instrumentation
- **OpenTelemetry**: Python backend instrumentation with auto-discovery
- **Trace Propagation**: HTTP headers for cross-service tracing
- **Sampling**: Configurable sampling strategies per service/operation
- **Correlation**: Trace IDs embedded in logs for correlation

### Performance Analysis
- **Service Map**: Visual representation of service dependencies
- **Trace Timeline**: Detailed span analysis with timing information
- **Error Tracking**: Failed traces with error context
- **Performance Trends**: Historical performance analysis

## 🔄 Enhanced CI/CD Pipeline

### Jenkins Pipeline with ELK & Jaeger
```groovy
pipeline {
    stages {
        stage('Setup Observability') {
            steps {
                // Start ELK stack for testing
                sh 'cd observability && ./setup-elk.sh'
                // Start Jaeger for tracing
                sh 'cd observability && ./setup-jaeger.sh'
            }
        }

        stage('Test with Observability') {
            steps {
                // Run tests with tracing enabled
                sh 'JAEGER_AGENT_HOST=localhost pytest tests/'
                // Validate log ingestion
                sh 'curl -f http://localhost:9200/devsecops-logs-*/_search'
                // Verify trace collection
                sh 'curl -f http://localhost:16686/api/services'
            }
        }

        stage('Observability Validation') {
            steps {
                // Generate test data with tracing
                sh './scripts/generate-test-traces.sh'
                // Validate ELK data ingestion
                sh './scripts/validate-elk-data.sh'
                // Check Jaeger trace collection
                sh './scripts/validate-jaeger-traces.sh'
            }
        }
    }
}
```

### GitHub Actions with Observability
- **Matrix Builds**: Test against different ELK and Jaeger versions
- **Integration Testing**: Full stack testing with observability enabled
- **Performance Testing**: Load testing with trace analysis
- **Security Scanning**: Container scanning for ELK and Jaeger images

## 📊 Monitoring & Dashboards

### Pre-built Grafana Dashboards
1. **DevSecOps Overview**: System health with ELK and Jaeger status
2. **ELK Stack Monitoring**: Elasticsearch, Logstash, Kibana metrics  
3. **Jaeger Performance**: Trace ingestion rates and query performance
4. **Application Observability**: Combined metrics, logs, and traces
5. **Security Dashboard**: Audit logs and security events

### Kibana Dashboards
1. **Application Logs**: Structured log analysis with filtering
2. **Error Analysis**: Error log patterns and troubleshooting
3. **Performance Logs**: Response time and throughput analysis
4. **Trace Correlation**: Log entries correlated with trace IDs

### Alerting Rules
- **ELK Stack Health**: Elasticsearch cluster status, Logstash processing
- **Jaeger Health**: Trace ingestion rates, query performance
- **Application Performance**: Error rates, response times
- **Security Alerts**: Failed authentication, suspicious activity

## 🧪 Testing with Observability

### Unit Testing
```bash
# Run backend tests with observability mocking
cd backend
python -m pytest tests/unit/ --cov=src --cov-report=html

# Frontend tests with observability status checks
cd frontend  
npm test
```

### Integration Testing
```bash
# Full stack integration with ELK and Jaeger
./scripts/run_all_tests.sh

# This will:
# 1. Start ELK stack and Jaeger
# 2. Run database migrations
# 3. Start application with observability enabled
# 4. Execute integration tests with tracing
# 5. Validate log ingestion and trace collection
# 6. Generate observability validation report
```

### Performance Testing with Tracing
```bash
# Load testing with distributed tracing
k6 run --out json=performance-results.json performance-test.js

# Analysis:
# - View traces in Jaeger UI
# - Analyze response times by service
# - Identify performance bottlenecks
# - Correlate metrics with traces
```

## 🚀 Deployment Options

### Local Development with Full Observability
```bash
# Complete stack
docker-compose up -d

# Individual observability components
cd observability/elasticsearch && docker-compose up -d
cd ../logstash && docker-compose up -d  
cd ../kibana && docker-compose up -d
cd ../jaeger && docker-compose up -d
```

### AWS EKS Production Deployment
```bash
# Setup EKS cluster with observability
cd infra/eks-cluster && ./setup.sh

# Deploy ELK stack
helm upgrade --install elk-stack ./helm/elk-chart --namespace observability

# Deploy Jaeger
helm upgrade --install jaeger ./helm/jaeger-chart --namespace observability

# Deploy application with observability
helm upgrade --install devsecops-3tier ./helm --namespace production
```

## 🔧 Configuration

### ELK Stack Environment Variables
```bash
# Elasticsearch
ELASTICSEARCH_URL=http://elasticsearch:9200
ES_JAVA_OPTS=-Xms1g -Xmx1g

# Logstash
LOGSTASH_HOST=logstash
LOGSTASH_PORT=5044
LS_JAVA_OPTS=-Xms512m -Xmx512m

# Kibana
KIBANA_URL=http://kibana:5601
ELASTICSEARCH_HOSTS=http://elasticsearch:9200
```

### Jaeger Environment Variables  
```bash
# Agent configuration
JAEGER_AGENT_HOST=jaeger
JAEGER_AGENT_PORT=6831

# Collector configuration
JAEGER_ENDPOINT=http://jaeger:14268/api/traces
JAEGER_QUERY_URL=http://jaeger:16686

# Sampling configuration
JAEGER_SAMPLER_TYPE=const
JAEGER_SAMPLER_PARAM=1
```

### Application Configuration
```bash
# Backend configuration
SERVICE_NAME=devsecops-backend
ENVIRONMENT=production
LOG_LEVEL=INFO

# Observability integration
ELASTICSEARCH_URL=http://elasticsearch:9200
JAEGER_AGENT_HOST=jaeger
JAEGER_AGENT_PORT=6831
```

## 🐛 Troubleshooting

### ELK Stack Issues
```bash
# Check Elasticsearch health
curl http://localhost:9200/_cluster/health

# Check Logstash pipeline
curl http://localhost:9600/_node/pipelines

# Check Kibana status
curl http://localhost:5601/api/status

# View ELK stack logs
docker-compose logs elasticsearch
docker-compose logs logstash
docker-compose logs kibana
```

### Jaeger Issues
```bash
# Check Jaeger health
curl http://localhost:16686/api/services

# Check collector health
curl http://localhost:14269/

# View Jaeger logs
docker-compose logs jaeger

# Test trace ingestion
curl -X POST http://localhost:14268/api/traces \
  -H "Content-Type: application/json" \
  -d @test-trace.json
```

### Application Observability Issues
```bash
# Check backend observability endpoints
curl http://localhost:5000/observability/elasticsearch/status
curl http://localhost:5000/observability/jaeger/status

# Check trace propagation
curl -H "X-Trace-ID: test-trace-123" http://localhost:5000/api/users

# Validate log correlation
grep "test-trace-123" /var/log/application/*.log
```

## 🤝 Contributing

1. **Fork the Repository**
2. **Create Feature Branch**: `git checkout -b feature/elk-jaeger-enhancement`
3. **Test Observability**: Run full test suite with ELK and Jaeger
4. **Validate Integration**: Ensure traces and logs are properly collected
5. **Update Documentation**: Include observability considerations
6. **Submit Pull Request**

### Development Standards
- **Observability**: All new features must include tracing and logging
- **Testing**: Integration tests must validate observability data collection  
- **Performance**: Monitor performance impact of observability overhead
- **Security**: Follow ELK and Jaeger security best practices

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Elastic Stack** - Elasticsearch, Logstash, Kibana
- **Jaeger** - Distributed tracing platform
- **OpenTelemetry** - Observability framework
- **Prometheus & Grafana** - Metrics and visualization
- **Flask & PostgreSQL** - Application foundation
- **Docker & Kubernetes** - Container orchestration

---

**🎉 Production-Ready DevSecOps with Complete Observability!**

This comprehensive 3-tier application demonstrates enterprise observability practices with ELK Stack for logging and Jaeger for distributed tracing. The integrated CI/CD pipelines ensure security, performance, and observability at every stage.

**Quick Start Commands:**
```bash
# Start complete stack
docker-compose up -d

# Generate sample data
./scripts/generate-sample-data.sh

# Access services
open http://localhost:8080     # Application
open http://localhost:5601     # Kibana (Logs)
open http://localhost:16686    # Jaeger (Traces)  
open http://localhost:3000     # Grafana (Metrics)
```

**Observability URLs:**
- **Logs**: http://localhost:5601 (Kibana)
- **Traces**: http://localhost:16686 (Jaeger)
- **Metrics**: http://localhost:3000 (Grafana)
- **Raw Logs**: http://localhost:9200 (Elasticsearch)
