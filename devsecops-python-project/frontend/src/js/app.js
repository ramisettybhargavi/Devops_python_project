// DevSecOps Frontend Application JavaScript
// Handles API communication, trace propagation, and UI updates

class DevSecOpsApp {
    constructor() {
        this.baseURL = 'http://localhost:5000';
        this.traceId = this.generateTraceId();
        this.currentPage = 1;
        this.init();
    }

    generateTraceId() {
        return 'trace-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
    }

    init() {
        this.updateTraceIdDisplay();
        this.refreshHealthStatus();
        this.loadUsers();
        this.startMetricsPolling();
        
        // Set up periodic refresh
        setInterval(() => {
            this.refreshHealthStatus();
            this.updateMetrics();
        }, 30000); // Every 30 seconds
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
            this.showAlert('Network error occurred', 'danger');
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
                    <div class="col-md-3 mb-2">
                        <div class="d-flex align-items-center">
                            <span class="status-indicator ${serviceClass}"></span>
                            <span>${serviceName}</span>
                            ${status.response_time ? `<small class="ms-auto text-muted">${Math.round(status.response_time * 1000)}ms</small>` : ''}
                        </div>
                    </div>
                `;
            });
        }

        container.innerHTML = `
            <div class="col-md-6">
                <div class="alert alert-${statusClass} mb-0">
                    <i class="fas fa-${statusIcon} me-2"></i>
                    <strong>System Status: ${healthData.status.toUpperCase()}</strong>
                    <br>
                    <small>Last updated: ${new Date(healthData.timestamp).toLocaleString()}</small>
                    <br>
                    <small>Uptime: ${Math.round(healthData.uptime || 0)} seconds</small>
                </div>
            </div>
            <div class="col-md-6">
                <h6>Observability Stack:</h6>
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
            <div class="col-12">
                <div class="alert alert-danger mb-0">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    <strong>Unable to fetch system health status</strong>
                    <br>
                    <small>Please check if the backend service is running</small>
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
                    <td colspan="6" class="text-center text-muted">
                        <i class="fas fa-user-slash"></i> No users found
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
                    <span class="badge ${user.is_active ? 'bg-success' : 'bg-secondary'}">
                        ${user.is_active ? 'Active' : 'Inactive'}
                    </span>
                </td>
                <td>
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-primary" onclick="app.viewUser(${user.id})" title="View">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-outline-warning" onclick="app.editUser(${user.id})" title="Edit">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-outline-danger" onclick="app.deleteUser(${user.id})" title="Delete">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
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
                    <i class="fas fa-exclamation-triangle"></i> Failed to load users
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
                    <a class="page-link" href="#" onclick="app.loadUsers(${pagination.page - 1})">Previous</a>
                </li>
            `;
        }

        // Page numbers
        for (let i = 1; i <= pagination.pages; i++) {
            const isActive = i === pagination.page;
            paginationHtml += `
                <li class="page-item ${isActive ? 'active' : ''}">
                    <a class="page-link" href="#" onclick="app.loadUsers(${i})">${i}</a>
                </li>
            `;
        }

        // Next button
        if (pagination.has_next) {
            paginationHtml += `
                <li class="page-item">
                    <a class="page-link" href="#" onclick="app.loadUsers(${pagination.page + 1})">Next</a>
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
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
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

        document.getElementById('responseTimeMetric').textContent = responseTime;
        document.getElementById('totalRequestsMetric').textContent = totalRequests.toLocaleString();
        document.getElementById('errorRateMetric').textContent = errorRate + '%';
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
});
