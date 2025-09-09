FROM node:18-alpine AS builder

# Install necessary tools
RUN apk add --no-cache wget curl

WORKDIR /app

# Copy source files
COPY src/ ./src/

# Production stage with nginx
FROM nginx:1.25-alpine

# Install curl and wget for health checks
RUN apk add --no-cache curl wget

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/src /usr/share/nginx/html

# FIXED: Copy configuration injection script
COPY inject-config.sh /usr/local/bin/inject-config.sh
RUN chmod +x /usr/local/bin/inject-config.sh

# Fix permissions
RUN chown -R nginx:nginx /usr/share/nginx/html
RUN chown -R nginx:nginx /var/cache/nginx
RUN chown -R nginx:nginx /var/log/nginx

# Create nginx pid file directory
RUN mkdir -p /var/run/nginx
RUN chown -R nginx:nginx /var/run/nginx

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
 CMD curl -f http://localhost/health || exit 1

EXPOSE 80

# FIXED: Inject config before starting nginx
CMD ["/bin/sh", "-c", "/usr/local/bin/inject-config.sh && nginx -g 'daemon off;'"]
