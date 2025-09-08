// FIXED DevSecOps Frontend Application JavaScript
// Addresses hardcoded localhost URLs and adds dynamic configuration

class DevSecOpsApp {
    constructor() {
        // FIXED: Use environment-based configuration instead of hardcoded localhost
        this.config = this.getConfiguration();
        this.baseURL = this.config.backendUrl;
        this.traceId = this.generateTraceId();
        this.currentPage = 1;
        this.init();
    }

    // NEW: Dynamic configuration based on environment
    getConfiguration() {
        // Check if running in development or production
        const hostname = window.location.hostname;
        const protocol = window.location.protocol;
        
        // Try to get configuration from environment variables or meta tags
        const backendUrl = document.querySelector('meta[name="backend-url"]')?.content || 
                          this.getBackendUrl(hostname, protocol);
        
        const publicIP = document.querySelector('meta[name="public-ip"]')?.content || hostname;
        
        return {
            backendUrl: backendUrl,
            publicIP: publicIP,
            kibanaUrl: `${protocol}//${publicIP}:5601`,
            jaegerUrl: `${protocol}//${publicIP}:16686`,
            grafanaUrl: `${protocol}//${publicIP}:3000`,
            elasticsearchUrl: `${protocol}//${publicIP}:9200`,
            prometheusUrl: `${protocol}//${publicIP}:9090`
        };
    }

    // NEW: Smart backend URL detection
    getBackendUrl(hostname, protocol) {
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return `${protocol}//localhost:5000`;
        } else {
            // For EC2 deployment, use the same host with port 5000
            return `${protocol}//${hostname}:5000`;
        }
    }

    generateTraceId() {
        return 'trace-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
    }

    init() {
        this.updateTraceIdDisplay();
        this.updateObservabilityLinks(); // NEW: Update observability links
        this.refreshHealthStatus();
        this.loadUsers();
        this.startMetricsPolling();
        
        // Set up periodic refresh
        setInterval(() => {
            this.refreshHealthStatus();
            this.updateMetrics();
        }, 30000); // Every 30 seconds
    }

    // NEW: Update observability links with correct URLs
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
            }
        });

        // Update any display elements showing URLs
        this.updateUrlDisplays();
    }

    // NEW: Update URL displays in the UI
    updateUrlDisplays() {
        const displays = {
            'kibana-url-display': this.config.kibanaUrl,
            'jaeger-url-display': this.config.jaegerUrl,
            'grafana-url-display': this.config.grafanaUrl,
            'elasticsearch-url-display': this.config.elasticsearchUrl
        };

        Object.entries(displays).forEach(([id, url]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = url;
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
            headers: {
                'Content-Type': 'application/json',
                'X-Trace-ID': this.traceId,
                ...options.headers
            }
        };

        const mergedOptions = { ...defaultOptions, ...options };
        
        try {
            const response = await fetch(url, mergedOptions);
            
            // Update trace ID if provided in response
            const responseTraceId = response.headers.get('X-Trace-ID');
            if (responseTraceId) {
                this.traceId = responseTraceId;
                this.updateTraceIdDisplay();
            }
            
            return response;
        } catch (error) {
            console.error('Request failed:', error);
            this.showAlert('Network error occurred. Please check if the backend service is running.', 'danger');
            throw error;
        }
    }

    async refreshHealthStatus() {
        const refreshIcon = document.getElementById('refreshIcon');
        if (refreshIcon) {
            refreshIcon.classList.add('loading');
        }

        try {
            const response = await this.makeRequest(`${this.baseURL}/health`);
            const healthData = await response.json();
            
            this.displayHealthStatus(healthData);
        } catch (error) {
            console.error('Health check failed:', error);
            this.displayHealthError();
        } finally {
            if (refreshIcon) {
                refreshIcon.classList.remove('loading');
            }
        }
    }

    displayHealthStatus(healthData) {
        const container = document.getElementById('healthStatusContainer');
        if (!container) return;

        const isHealthy = healthData.status === 'healthy';
        const statusClass = isHealthy ? 'success' : 'danger';
        const statusIcon = isHealthy ? 'check-circle' : 'exclamation-triangle';

        let observabilityHtml = '';
        if (healthData.observability) {
            Object.entries(healthData.observability).forEach(([service, status]) => {
                const serviceHealthy = status.healthy;
                const serviceClass = serviceHealthy ? 'status-healthy' : 'status-unhealthy';
                const serviceName = service.charAt(0).toUpperCase() + service.slice(1);
                
                observabilityHtml += `
                    <div class="col-md-6 mb-2">
                        <div class="d-flex align-items-center">
                            <span class="badge ${serviceClass} me-2">${serviceHealthy ? '✓' : '✗'}</span>
                            <span class="fw-medium">${serviceName}</span>
                            ${status.response_time ? `<small class="text-muted ms-auto">${Math.round(status.response_time * 1000)}ms</small>` : ''}
                        </div>
                    </div>
                `;
            });
        }

        container.innerHTML = `
            <div class="alert alert-${statusClass} mb-3">
                <div class="d-flex align-items-center">
                    <i class="fas fa-${statusIcon} me-2"></i>
                    <div>
                        <strong>System Status: ${healthData.status.toUpperCase()}</strong><br>
                        <small>Last updated: ${new Date(healthData.timestamp).toLocaleString()}</small><br>
                        <small>Uptime: ${Math.round(healthData.uptime || 0)} seconds</small>
                    </div>
                </div>
            </div>
            
            <div class="row">
                <div class="col-12">
                    <h6 class="fw-bold mb-3">Observability Stack:</h6>
                </div>
                <div class="row">
                    ${observabilityHtml}
                </div>
            </div>
        `;
    }

    displayHealthError() {
        const container = document.getElementById('healthStatusContainer');
        if (!container) return;

        container.innerHTML = `
            <div class="alert alert-danger">
                <div class="d-flex align-items-center">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    <div>
                        <strong>Unable to fetch system health status</strong><br>
                        <small>Please check if the backend service is running at ${this.baseURL}</small>
                    </div>
                </div>
            </div>
        `;
    }

    async loadUsers(page = 1) {
        try {
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
                    <td colspan="6" class="text-center">No users found</td>
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
                    <span class="badge ${user.is_active ? 'bg-success' : 'bg-secondary'}">
                        ${user.is_active ? 'Active' : 'Inactive'}
                    </span>
                </td>
                <td>
                    <button class="btn btn-sm btn-outline-primary me-1" onclick="app.viewUser(${user.id})" title="View">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-warning me-1" onclick="app.editUser(${user.id})" title="Edit">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="app.deleteUser(${user.id})" title="Delete">
                        <i class="fas fa-trash"></i>
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
                <td colspan="6" class="text-center text-danger">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    Failed to load users. Backend service may be unavailable.
                </td>
            </tr>
        `;
    }

    displayPagination(pagination) {
        const container = document.getElementById('usersPagination');
        if (!container || !pagination.pages) return;

        let paginationHtml = '';

        // Previous button
        if (pagination.has_prev) {
            paginationHtml += `
                <li class="page-item">
                    <a class="page-link" href="#" onclick="app.loadUsers(${pagination.page - 1}); return false;">Previous</a>
                </li>
            `;
        }

        // Page numbers
        for (let i = 1; i <= pagination.pages; i++) {
            const isActive = i === pagination.page;
            paginationHtml += `
                <li class="page-item ${isActive ? 'active' : ''}">
                    <a class="page-link" href="#" onclick="app.loadUsers(${i}); return false;">${i}</a>
                </li>
            `;
        }

        // Next button
        if (pagination.has_next) {
            paginationHtml += `
                <li class="page-item">
                    <a class="page-link" href="#" onclick="app.loadUsers(${pagination.page + 1}); return false;">Next</a>
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
            if (password) {
                userData.password = password;
            }

            const response = await this.makeRequest(`${this.baseURL}/api/users`, {
                method: 'POST',
                body: JSON.stringify(userData)
            });

            if (response.ok) {
                const result = await response.json();
                this.showAlert('User created successfully!', 'success');
                this.clearCreateUserForm();
                this.loadUsers(this.currentPage);
                
                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('createUserModal'));
                if (modal) modal.hide();
            } else {
                const error = await response.json();
                this.showAlert(error.error || 'Failed to create user', 'danger');
            }
        } catch (error) {
            console.error('Create user error:', error);
            this.showAlert('Network error occurred', 'danger');
        }
    }

    async deleteUser(userId) {
        if (!confirm('Are you sure you want to delete this user?')) {
            return;
        }

        try {
            const response = await this.makeRequest(`${this.baseURL}/api/users/${userId}`, {
                method: 'DELETE'
            });

            if (response.ok) {
                this.showAlert('User deleted successfully!', 'success');
                this.loadUsers(this.currentPage);
            } else {
                const error = await response.json();
                this.showAlert(error.error || 'Failed to delete user', 'danger');
            }
        } catch (error) {
            console.error('Delete user error:', error);
            this.showAlert('Network error occurred', 'danger');
        }
    }

    viewUser(userId) {
        // Generate new trace for this operation
        this.traceId = this.generateTraceId();
        this.updateTraceIdDisplay();
        
        alert(`View user functionality - User ID: ${userId}\nTrace ID: ${this.traceId}`);
    }

    editUser(userId) {
        // Generate new trace for this operation
        this.traceId = this.generateTraceId();
        this.updateTraceIdDisplay();
        
        alert(`Edit user functionality - User ID: ${userId}\nTrace ID: ${this.traceId}`);
    }

    clearCreateUserForm() {
        document.getElementById('userName').value = '';
        document.getElementById('userEmail').value = '';
        document.getElementById('userPassword').value = '';
    }

    showAlert(message, type = 'info') {
        // Create alert element
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
        alertDiv.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        `;

        document.body.appendChild(alertDiv);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (alertDiv.parentNode) {
                alertDiv.parentNode.removeChild(alertDiv);
            }
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
        // Simulate metrics updates
        this.updateMetrics();
        setInterval(() => this.updateMetrics(), 10000); // Every 10 seconds
    }

    updateMetrics() {
        // Simulate metrics data
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
    if (window.app) {
        window.app.refreshHealthStatus();
    }
}

function createUser() {
    if (window.app) {
        window.app.createUser();
    }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    window.app = new DevSecOpsApp();
    
    // Display configuration info in console for debugging
    console.log('DevSecOps App Configuration:', window.app.config);
});
