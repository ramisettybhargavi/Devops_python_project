FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies including curl for health checks
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ .

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app && \
    chown -R app:app /app

# Create logs directory
RUN mkdir -p /app/logs && chown -R app:app /app/logs

USER app

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Environment variables
ENV FLASK_APP=main.py
ENV FLASK_ENV=production
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# ELK and Jaeger configuration - REMOVE deprecated Jaeger Agent settings and add OTLP config
ENV ELASTICSEARCH_URL=http://elasticsearch:9200
ENV LOGSTASH_HOST=logstash
ENV LOGSTASH_PORT=5044

# Remove these deprecated Jaeger agent environment variables
# ENV JAEGER_AGENT_HOST=jaeger
# ENV JAEGER_AGENT_PORT=6831

# Keep OTLP and HTTP endpoint for Jaeger
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317
ENV OTEL_EXPORTER_OTLP_INSECURE=true
ENV JAEGER_ENDPOINT=http://jaeger:14268/api/traces

# Run the application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "60", "--keep-alive", "2", "--access-logfile", "-", "--error-logfile", "-", "--log-level", "info", "main:app"]
