/**
 * DevSecOps 3-Tier Application Frontend with ELK & Jaeger Integration
 * Handles UI interactions and API communication with observability
 */

class DevSecOpsELKApp {
    constructor() {
        this.apiBaseUrl = this.getApiBaseUrl();
        this.users = [];
        this.metrics = {};
        this.currentTraceId = null;

        this.init();
    }

    getApiBaseUrl() {
        // Determine API base URL based on environment
        const hostname = window.location.hostname;
        const protocol = window.location.protocol;

        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return `${protocol}//${hostname}:5000`;
        } else {
            return '/api';
        }
    }

    init() {
        this.bindEventListeners();
        this.loadInitialData();
        this.startPeriodicUpdates();
    }

    bindEventListeners() {
        // User form submission
        document.getElementById('user-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.createUser();
        });

        // Refresh users button
        document.getElementById('refresh-users').addEventListener('click', () => {
            this.loadUsers();
        });

        // Initialize Bootstrap toasts
        this.successToast = new bootstrap.Toast(document.getElementById('success-toast'));
        this.errorToast = new bootstrap.Toast(document.getElementById('error-toast'));
    }

    async loadInitialData() {
        await Promise.all([
            this.checkHealth(),
            this.loadUsers(),
            this.loadMetrics(),
            this.checkObservabilityStack()
        ]);
    }

    startPeriodicUpdates() {
        // Update health status every 30 seconds
        setInterval(() => this.checkHealth(), 30000);

        // Update metrics every 15 seconds
        setInterval(() => this.loadMetrics(), 15000);

        // Update observability stack status every 45 seconds
        setInterval(() => this.checkObservabilityStack(), 45000);
    }

    async checkHealth() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/health`);
            const data = await response.json();

            // Extract trace ID if available
            if (response.headers.get('x-trace-id')) {
                this.currentTraceId = response.headers.get('x-trace-id');
                document.getElementById('last-trace-id').innerHTML = 
                    `<span class="trace-id">${this.currentTraceId}</span>`;
            }

            const healthElement = document.getElementById('health-status');

            if (response.ok && data.status === 'healthy') {
                healthElement.innerHTML = `
                    <span class="health-indicator health-healthy"></span>
                    <span><strong>System Healthy</strong> - Last checked: ${new Date().toLocaleTimeString()}</span>
                `;
            } else {
                throw new Error('Health check failed');
            }
        } catch (error) {
            const healthElement = document.getElementById('health-status');
            healthElement.innerHTML = `
                <span class="health-indicator health-unhealthy"></span>
                <span><strong>System Unhealthy</strong> - Unable to connect to backend</span>
            `;
            console.error('Health check error:', error);
        }
    }

    async checkObservabilityStack() {
        // Check ELK Stack
        await this.checkElasticsearchStatus();
        await this.checkKibanaStatus();
        await this.checkJaegerStatus();
    }

    async checkElasticsearchStatus() {
        try {
            const response = await fetch('http://localhost:9200/_cluster/health', {
                mode: 'no-cors',
                method: 'GET'
            });

            // Since we can't actually check due to CORS, we'll use a proxy endpoint
            const proxyResponse = await fetch(`${this.apiBaseUrl}/observability/elasticsearch/status`);

            if (proxyResponse.ok) {
                const data = await proxyResponse.json();
                document.getElementById('es-status').innerHTML = 
                    `<span class="status-healthy">✅ ${data.status}</span>`;
            } else {
                throw new Error('Elasticsearch check failed');
            }
        } catch (error) {
            document.getElementById('es-status').innerHTML = 
                '<span class="status-unhealthy">❌ Unavailable</span>';
        }
    }

    async checkKibanaStatus() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/observability/kibana/status`);
            if (response.ok) {
                const data = await response.json();
                document.getElementById('kibana-status').innerHTML = 
                    `<span class="status-healthy">✅ ${data.status}</span>`;
            } else {
                throw new Error('Kibana check failed');
            }
        } catch (error) {
            document.getElementById('kibana-status').innerHTML = 
                '<span class="status-unhealthy">❌ Unavailable</span>';
        }
    }

    async checkJaegerStatus() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/observability/jaeger/status`);
            if (response.ok) {
                const data = await response.json();
                document.getElementById('jaeger-status-value').innerHTML = 
                    `<span class="status-healthy">✅ ${data.status}</span>`;
            } else {
                throw new Error('Jaeger check failed');
            }
        } catch (error) {
            document.getElementById('jaeger-status-value').innerHTML = 
                '<span class="status-unhealthy">❌ Unavailable</span>';
        }
    }

    async loadUsers() {
        try {
            this.showUsersLoading();

            // Generate trace ID for this request
            const traceId = this.generateTraceId();

            const response = await fetch(`${this.apiBaseUrl}/api/users`, {
                headers: {
                    'X-Trace-ID': traceId
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const data = await response.json();
            this.users = data.users || [];
            this.renderUsers();

        } catch (error) {
            this.showUsersError(error.message);
            console.error('Load users error:', error);
        }
    }

    async loadMetrics() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/metrics`);

            if (response.ok) {
                const metricsText = await response.text();
                this.parseAndDisplayMetrics(metricsText);
            }
        } catch (error) {
            console.error('Load metrics error:', error);
            this.displayMetricsError();
        }
    }

    parseAndDisplayMetrics(metricsText) {
        const metricsElement = document.getElementById('metrics-data');

        // Parse basic metrics from Prometheus format
        const lines = metricsText.split('\n');
        const metrics = {};

        lines.forEach(line => {
            if (line.startsWith('http_requests_total')) {
                const match = line.match(/http_requests_total.*?(\d+(?:\.\d+)?)/);
                if (match) {
                    metrics.totalRequests = match[1];
                }
            }
            if (line.startsWith('jaeger_spans_total')) {
                const match = line.match(/jaeger_spans_total.*?(\d+(?:\.\d+)?)/);
                if (match) {
                    metrics.totalSpans = match[1];
                }
            }
        });

        // Display metrics
        metricsElement.innerHTML = `
            <div class="metrics-item">
                <span class="metrics-label">Total Requests</span>
                <span class="metrics-value">${metrics.totalRequests || 'N/A'}</span>
            </div>
            <div class="metrics-item">
                <span class="metrics-label">Active Users</span>
                <span class="metrics-value">${this.users.length}</span>
            </div>
            <div class="metrics-item">
                <span class="metrics-label">Total Spans</span>
                <span class="metrics-value">${metrics.totalSpans || 'N/A'}</span>
            </div>
            <div class="metrics-item">
                <span class="metrics-label">Last Update</span>
                <span class="metrics-value">${new Date().toLocaleTimeString()}</span>
            </div>
        `;
    }

    displayMetricsError() {
        const metricsElement = document.getElementById('metrics-data');
        metricsElement.innerHTML = `
            <div class="error-state">
                <i class="fas fa-exclamation-triangle"></i>
                <p>Unable to load metrics</p>
            </div>
        `;
    }

    async createUser() {
        const name = document.getElementById('userName').value.trim();
        const email = document.getElementById('userEmail').value.trim();

        if (!name || !email) {
            this.showError('Please fill in all fields');
            return;
        }

        try {
            const traceId = this.generateTraceId();

            const response = await fetch(`${this.apiBaseUrl}/api/users`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Trace-ID': traceId
                },
                body: JSON.stringify({ name, email }),
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            const newUser = await response.json();

            // Reset form
            document.getElementById('user-form').reset();

            // Reload users
            await this.loadUsers();

            this.showSuccess(`User "${newUser.name}" created successfully! Trace ID: ${traceId}`);

        } catch (error) {
            this.showError(`Failed to create user: ${error.message}`);
            console.error('Create user error:', error);
        }
    }

    async deleteUser(userId) {
        if (!confirm('Are you sure you want to delete this user?')) {
            return;
        }

        try {
            const traceId = this.generateTraceId();

            const response = await fetch(`${this.apiBaseUrl}/api/users/${userId}`, {
                method: 'DELETE',
                headers: {
                    'X-Trace-ID': traceId
                }
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            await this.loadUsers();
            this.showSuccess(`User deleted successfully! Trace ID: ${traceId}`);

        } catch (error) {
            this.showError(`Failed to delete user: ${error.message}`);
            console.error('Delete user error:', error);
        }
    }

    async editUser(userId) {
        const user = this.users.find(u => u.id === userId);
        if (!user) return;

        const newName = prompt('Enter new name:', user.name);
        if (!newName || newName.trim() === '') return;

        try {
            const traceId = this.generateTraceId();

            const response = await fetch(`${this.apiBaseUrl}/api/users/${userId}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Trace-ID': traceId
                },
                body: JSON.stringify({ name: newName.trim() }),
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            await this.loadUsers();
            this.showSuccess(`User updated successfully! Trace ID: ${traceId}`);

        } catch (error) {
            this.showError(`Failed to update user: ${error.message}`);
            console.error('Update user error:', error);
        }
    }

    generateTraceId() {
        // Generate a simple trace ID for demonstration
        return 'frontend-' + Date.now().toString(36) + '-' + Math.random().toString(36).substr(2, 9);
    }

    showUsersLoading() {
        document.getElementById('users-loading').style.display = 'block';
        document.getElementById('users-table').style.display = 'none';
        document.getElementById('users-error').style.display = 'none';
    }

    showUsersError(message) {
        document.getElementById('users-loading').style.display = 'none';
        document.getElementById('users-table').style.display = 'none';
        document.getElementById('users-error').style.display = 'block';
        document.getElementById('error-message').textContent = message;
    }

    renderUsers() {
        const tbody = document.getElementById('users-tbody');

        if (this.users.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="4" class="text-center text-muted">
                        No users found. Add a new user to get started.
                    </td>
                </tr>
            `;
        } else {
            tbody.innerHTML = this.users.map(user => `
                <tr>
                    <td>${user.id}</td>
                    <td>${this.escapeHtml(user.name)}</td>
                    <td>${this.escapeHtml(user.email)}</td>
                    <td>
                        <div class="action-buttons">
                            <button class="btn btn-outline-primary btn-sm" onclick="app.editUser(${user.id})">
                                <i class="fas fa-edit"></i> Edit
                            </button>
                            <button class="btn btn-outline-danger btn-sm" onclick="app.deleteUser(${user.id})">
                                <i class="fas fa-trash"></i> Delete
                            </button>
                        </div>
                    </td>
                </tr>
            `).join('');
        }

        document.getElementById('users-loading').style.display = 'none';
        document.getElementById('users-table').style.display = 'block';
        document.getElementById('users-error').style.display = 'none';
    }

    showSuccess(message) {
        document.getElementById('success-message').textContent = message;
        this.successToast.show();
    }

    showError(message) {
        document.getElementById('error-toast-message').textContent = message;
        this.errorToast.show();
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new DevSecOpsELKApp();
});

// Service Worker for offline capability (optional)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}
