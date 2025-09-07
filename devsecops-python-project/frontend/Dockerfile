FROM node:18-alpine AS builder

# Install necessary tools
RUN apk add --no-cache wget curl

WORKDIR /app

# Copy source files
COPY src/ ./src/

FROM nginx:1.25-alpine

# Install curl for health checks
RUN apk add --no-cache curl wget

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/src /usr/share/nginx/html

# Add healthcheck using wget (more reliable than curl in alpine)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# Create non-root user for security
RUN addgroup -g 1001 -S nginx-user && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx-user -g nginx-user nginx-user && \
    chown -R nginx-user:nginx-user /var/cache/nginx && \
    chown -R nginx-user:nginx-user /var/log/nginx && \
    chown -R nginx-user:nginx-user /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx-user:nginx-user /var/run/nginx.pid

USER nginx-user

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
