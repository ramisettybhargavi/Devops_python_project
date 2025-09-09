// FIXED DevSecOps Frontend Application JavaScript
// Uses PUBLIC_IP from environment variables to construct all URLs

class DevSecOpsApp {
    constructor() {
        // Load configuration from environment variables
        this.config = this.loadEnvironmentConfig();
        this.baseURL = this.config.backendUrl;
        this.traceId = this.generateTraceId();
        this.currentPage = 1;
        this.retryCount = 0;
        this.maxRetries = 3;
        
        console.log('App Configuration:', this.config);
        this.init();
    }

    // Load configuration from environment variables
    loadEnvironmentConfig() {
        const publicIP = process.env.PUBLIC_IP || window.location.hostname;
        const backendPort = process.env.BACKEND_PORT || '5000';
        const protocol = window.location.protocol;
        const isProduction = process.env.NODE_ENV === 'production';

        // Determine backend URL
        let backendUrl;
        if (publicIP && publicIP !== 'localhost' && publicIP !== '127.0.0.1') {
            backendUrl = `${protocol}//${publicIP}:${backendPort}`;
        } else {
            backendUrl = `${protocol}//localhost:${backendPort}`;
        }

        // Standard observability ports (fixed as per your requirement)
        const standardPorts = {
            kibana: 5601,
            jaeger: 16686,
            grafana: 3000,
            elasticsearch: 9200,
            prometheus: 9090
        };

        return {
            backendUrl: backendUrl,
            publicIP: publicIP,
            kibanaUrl: `${protocol}//${publicIP}:${standardPorts.kibana}`,
            jaegerUrl: `${protocol}//${publicIP}:${standardPorts.jaeger}`,
            grafanaUrl: `${protocol}//${publicIP}:${standardPorts.grafana}`,
            elasticsearchUrl: `${protocol}//${publicIP}:${standardPorts.elasticsearch}`,
            prometheusUrl: `${protocol}//${publicIP}:${standardPorts.prometheus}`,
            isProduction: isProduction,
            standardPorts: standardPorts
        };
    }

    generateTraceId() {
        return 'trace-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
    }

    init() {
        this.updateTraceIdDisplay();
        this.updateObservabilityLinks();
        this.refreshHealthStatus();
        this.loadUsers();
        this.startMetricsPolling();
        this.setupPeriodicRefresh();
        
        // Display environment info for debugging
        this.displayEnvironmentInfo();
    }

    displayEnvironmentInfo() {
        console.log('Environment Configuration:');
        console.log('- Public IP:', this.config.publicIP);
        console.log('- Backend URL:', this.config.backendUrl);
        console.log('- Kibana URL:', this.config.kibanaUrl);
        console.log('- Jaeger URL:', this.config.jaegerUrl);
        console.log('- Grafana URL:', this.config.grafanaUrl);
        console.log('- Production Mode:', this.config.isProduction);
    }

    setupPeriodicRefresh() {
        setTimeout(() => {
            this.refreshHealthStatus();
            this.updateMetrics();
        }, 5000);

        setInterval(() => {
            this.refreshHealthStatus();
            this.updateMetrics();
        }, 30000);
    }

    updateObservabilityLinks() {
        const links = {
            'kibana-link': this.config.kibanaUrl,
            'jaeger-link': this.config.jaegerUrl,
            'grafana-link': this.config.grafanaUrl,
            'elasticsearch-link': this.config.elasticsearchUrl,
            'prometheus-link': this.config.prometheusUrl
        };

        Object.entries(links).forEach(([id, url]) => {
            const element = document.getElementById(id);
            if (element) {
                element.href = url;
                element.target = '_blank';
                element.setAttribute('data-url', url);
            }
        });

        this.updateUrlDisplays();
    }

    updateUrlDisplays() {
        const displays = {
            'kibana-url-display': this.config.kibanaUrl,
            'jaeger-url-display': this.config.jaegerUrl,
            'grafana-url-display': this.config.grafanaUrl,
            'elasticsearch-url-display': this.config.elasticsearchUrl,
            'prometheus-url-display': this.config.prometheusUrl,
            'backend-url-display': this.config.backendUrl,
            'public-ip-display': this.config.publicIP
        };

        Object.entries(displays).forEach(([id, url]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = url;
                element.setAttribute('title', url);
            }
        });
    }

    updateTraceIdDisplay() {
        const displays = ['traceIdDisplay', 'footerTraceId'];
        displays.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = this.traceId;
            }
        });
    }

    async makeRequest(url, options = {}) {
        const defaultOptions = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'X-Trace-ID': this.traceId,
                'Accept': 'application/json',
                ...options.headers
            }
        };

        const mergedOptions = { ...defaultOptions, ...options };

        try {
            console.log(`Making request to: ${url}`);
            const response = await fetch(url, mergedOptions);

            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`HTTP ${response.status}: ${errorText}`);
            }

            this.retryCount = 0;
            return response;
        } catch (error) {
            console.error('Request failed:', error);

            if (this.retryCount < this.maxRetries) {
                this.retryCount++;
                const retryDelay = Math.pow(2, this.retryCount) * 1000;
                console.log(`Retrying in ${retryDelay}ms... (Attempt ${this.retryCount}/${this.maxRetries})`);

                await new Promise(resolve => setTimeout(resolve, retryDelay));
                return this.makeRequest(url, options);
            } else {
                this.showAlert(`Network error: Unable to connect to ${url}. Check if services are running on ${this.config.publicIP}`, 'danger');
                throw error;
            }
        }
    }

    async refreshHealthStatus() {
        const refreshIcon = document.getElementById('refreshIcon');
        const statusContainer = document.getElementById('healthStatusContainer');

        if (refreshIcon) refreshIcon.classList.add('loading');

        try {
            if (statusContainer) {
                statusContainer.innerHTML = `
                    <div class="alert alert-info">
                        <div class="spinner-border spinner-border-sm me-2" role="status"></div>
                        Checking system health at: ${this.baseURL}/health
                    </div>
                `;
            }

            const response = await this.makeRequest(`${this.baseURL}/health`);
            const healthData = await response.json();
            this.displayHealthStatus(healthData);
        } catch (error) {
            console.error('Health check failed:', error);
            this.displayHealthError(error.message);
        } finally {
            if (refreshIcon) refreshIcon.classList.remove('loading');
        }
    }

    displayHealthStatus(healthData) {
        const container = document.getElementById('healthStatusContainer');
        if (!container) return;

        const isHealthy = healthData.status === 'healthy';
        const statusClass = isHealthy ? 'success' : 'danger';

        let observabilityHtml = '';
        if (healthData.observability) {
            Object.entries(healthData.observability).forEach(([service, status]) => {
                const serviceHealthy = status.healthy;
                observabilityHtml += `
                    <div class="col-md-4 mb-2">
                        <div class="badge ${serviceHealthy ? 'bg-success' : 'bg-danger'} w-100 p-2">
                            ${serviceHealthy ? '✓' : '✗'} ${service.charAt(0).toUpperCase() + service.slice(1)}
                            ${status.response_time ? ` (${Math.round(status.response_time * 1000)}ms)` : ''}
                        </div>
                    </div>
                `;
            });
        }

        container.innerHTML = `
            <div class="alert alert-${statusClass}">
                <h5><i class="bi bi-${isHealthy ? 'check-circle' : 'exclamation-triangle'}"></i> 
                    System Status: ${healthData.status.toUpperCase()}</h5>
                <p class="mb-1">Server: ${this.config.publicIP}</p>
                <p class="mb-1">Backend: ${this.baseURL}</p>
                <p class="mb-1">Last updated: ${new Date(healthData.timestamp).toLocaleString()}</p>
                <p class="mb-0">Uptime: ${Math.round(healthData.uptime || 0)} seconds</p>
            </div>

            ${observabilityHtml ? `
                <div class="mt-3">
                    <h6>Observability Services:</h6>
                    <div class="row">
                        ${observabilityHtml}
                    </div>
                </div>
            ` : ''}
        `;
    }

    displayHealthError(errorMessage) {
        const container = document.getElementById('healthStatusContainer');
        if (!container) return;

        container.innerHTML = `
            <div class="alert alert-danger">
                <h5><i class="bi bi-exclamation-triangle"></i> Unable to fetch system health status</h5>
                <p class="mb-1">Server IP: ${this.config.publicIP}</p>
                <p class="mb-1">Backend URL: ${this.baseURL}</p>
                <p class="mb-1">Error: ${errorMessage || 'Connection failed'}</p>
                <small>Please check if backend service is running on port ${process.env.BACKEND_PORT || '5000'}</small>
            </div>
        `;
    }

    async loadUsers(page = 1) {
        const tableBody = document.getElementById('usersTableBody');

        try {
            if (tableBody) {
                tableBody.innerHTML = `
                    <tr>
                        <td colspan="6" class="text-center">
                            <div class="spinner-border spinner-border-sm me-2" role="status"></div>
                            Loading users from: ${this.config.publicIP}
                        </td>
                    </tr>
                `;
            }

            const response = await this.makeRequest(`${this.baseURL}/api/users?page=${page}&per_page=10`);
            const data = await response.json();
            this.displayUsers(data.users || []);
            this.displayPagination(data.pagination || {});
            this.currentPage = page;
        } catch (error) {
            console.error('Failed to load users:', error);
            this.displayUsersError();
        }
    }

    displayUsers(users) {
        const tbody = document.getElementById('usersTableBody');
        if (!tbody) return;

        if (users.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="6" class="text-center text-muted">
                        No users found on server: ${this.config.publicIP}
                    </td>
                </tr>
            `;
            return;
        }

        tbody.innerHTML = users.map(user => `
            <tr>
                <td>${user.id}</td>
                <td>${this.escapeHtml(user.name)}</td>
                <td>${this.escapeHtml(user.email)}</td>
                <td>${new Date(user.created_at).toLocaleDateString()}</td>
                <td>
                    <span class="badge bg-${user.is_active ? 'success' : 'secondary'}">
                        ${user.is_active ? 'Active' : 'Inactive'}
                    </span>
                </td>
                <td>
                    <button class="btn btn-sm btn-outline-primary me-1" onclick="app.viewUser(${user.id})">
                        View
                    </button>
                    <button class="btn btn-sm btn-outline-warning me-1" onclick="app.editUser(${user.id})">
                        Edit
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="app.deleteUser(${user.id})">
                        Delete
                    </button>
                </td>
            </tr>
        `).join('');
    }

    displayUsersError() {
        const tbody = document.getElementById('usersTableBody');
        if (!tbody) return;

        tbody.innerHTML = `
            <tr>
                <td colspan="6" class="text-center">
                    <div class="alert alert-danger mb-0">
                        <i class="bi bi-exclamation-triangle"></i>
                        Failed to load users from server: ${this.config.publicIP}<br>
                        <small>Backend service may be unavailable on port ${process.env.BACKEND_PORT || '5000'}</small>
                    </div>
                </td>
            </tr>
        `;
    }

    displayPagination(pagination) {
        const container = document.getElementById('usersPagination');
        if (!container || !pagination.pages) return;

        let paginationHtml = '';

        if (pagination.has_prev) {
            paginationHtml += `
                <li class="page-item">
                    <a class="page-link" href="#" onclick="app.loadUsers(${pagination.page - 1}); return false;">
                        Previous
                    </a>
                </li>
            `;
        }

        for (let i = 1; i <= pagination.pages; i++) {
            const isActive = i === pagination.page;
            paginationHtml += `
                <li class="page-item ${isActive ? 'active' : ''}">
                    <a class="page-link" href="#" onclick="app.loadUsers(${i}); return false;">
                        ${i}
                    </a>
                </li>
            `;
        }

        if (pagination.has_next) {
            paginationHtml += `
                <li class="page-item">
                    <a class="page-link" href="#" onclick="app.loadUsers(${pagination.page + 1}); return false;">
                        Next
                    </a>
                </li>
            `;
        }

        container.innerHTML = paginationHtml;
    }

    async createUser() {
        const name = document.getElementById('userName').value.trim();
        const email = document.getElementById('userEmail').value.trim();
        const password = document.getElementById('userPassword').value;

        if (!name || !email) {
            this.showAlert('Please fill in all required fields', 'warning');
            return;
        }

        try {
            const userData = { name, email };
            if (password) userData.password = password;

            const response = await this.makeRequest(`${this.baseURL}/api/users`, {
                method: 'POST',
                body: JSON.stringify(userData)
            });

            const result = await response.json();
            this.showAlert('User created successfully!', 'success');
            this.clearCreateUserForm();
            this.loadUsers(this.currentPage);

            const modal = bootstrap.Modal.getInstance(document.getElementById('createUserModal'));
            if (modal) modal.hide();

        } catch (error) {
            console.error('Create user error:', error);
            this.showAlert('Failed to create user. Please try again.', 'danger');
        }
    }

    async deleteUser(userId) {
        if (!confirm('Are you sure you want to delete this user?')) return;

        try {
            await this.makeRequest(`${this.baseURL}/api/users/${userId}`, {
                method: 'DELETE'
            });

            this.showAlert('User deleted successfully!', 'success');
            this.loadUsers(this.currentPage);
        } catch (error) {
            console.error('Delete user error:', error);
            this.showAlert('Failed to delete user. Please try again.', 'danger');
        }
    }

    viewUser(userId) {
        this.traceId = this.generateTraceId();
        this.updateTraceIdDisplay();
        this.showAlert(`View user functionality - User ID: ${userId}`, 'info');
    }

    editUser(userId) {
        this.traceId = this.generateTraceId();
        this.updateTraceIdDisplay();
        this.showAlert(`Edit user functionality - User ID: ${userId}`, 'info');
    }

    clearCreateUserForm() {
        document.getElementById('userName').value = '';
        document.getElementById('userEmail').value = '';
        document.getElementById('userPassword').value = '';
    }

    showAlert(message, type = 'info') {
        const existingAlerts = document.querySelectorAll('.custom-alert');
        existingAlerts.forEach(alert => alert.remove());

        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show position-fixed custom-alert`;
        alertDiv.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px; max-width: 500px;';
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;

        document.body.appendChild(alertDiv);

        setTimeout(() => {
            if (alertDiv.parentNode) alertDiv.parentNode.removeChild(alertDiv);
        }, 5000);
    }

    escapeHtml(text) {
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return text.replace(/[&<>"']/g, m => map[m]);
    }

    startMetricsPolling() {
        this.updateMetrics();
        setInterval(() => this.updateMetrics(), 10000);
    }

    updateMetrics() {
        const responseTime = Math.floor(Math.random() * 200) + 50;
        const totalRequests = Math.floor(Math.random() * 10000) + 1000;
        const errorRate = (Math.random() * 5).toFixed(2);

        const responseTimeElement = document.getElementById('responseTimeMetric');
        const totalRequestsElement = document.getElementById('totalRequestsMetric');
        const errorRateElement = document.getElementById('errorRateMetric');

        if (responseTimeElement) responseTimeElement.textContent = responseTime;
        if (totalRequestsElement) totalRequestsElement.textContent = totalRequests.toLocaleString();
        if (errorRateElement) errorRateElement.textContent = errorRate + '%';
    }
}

// Global functions for onclick handlers
function refreshHealthStatus() {
    if (window.app) window.app.refreshHealthStatus();
}

function createUser() {
    if (window.app) window.app.createUser();
}

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    console.log('Initializing DevSecOps App with PUBLIC_IP configuration...');
    window.app = new DevSecOpsApp();
});
