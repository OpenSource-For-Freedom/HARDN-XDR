/**
 * HARDN - GUI Setup Integration Module
 * This module handles the integration between the GUI and the backend setup scripts
 * 
 * It provides functionality to:
 * 1. Check system status via setup.sh/packages.sh
 * 2. Allow user to run specific setup tasks
 * 3. Prepare for future integration with main.rs user checks
 */

// Configuration
const API_ENDPOINT = 'http://localhost:8081/api';
const SETUP_STATUS_ACTIONS = {
  CHECK_SELINUX: 'check_selinux',
  CHECK_FIREWALL: 'check_firewall',
  CHECK_APPARMOR: 'check_apparmor',
  CHECK_PERMISSIONS: 'check_permissions',
  RUN_SETUP: 'run_setup',
  RUN_PACKAGES: 'run_packages',
  GET_SYSTEM_STATUS: 'get_system_status'
};

// Cache for system status
let systemStatusCache = null;
let lastStatusCheck = 0;
const STATUS_CACHE_TTL = 60000; // 1 minute

/**
 * Fetch system status from the backend
 * This will be routed through the proxy to the Unix socket
 * and eventually to the appropriate script (setup.sh, packages.sh, or main.rs)
 */
async function fetchSystemStatus(forceRefresh = false) {
  // Use cache if available and not expired
  const now = Date.now();
  if (!forceRefresh && systemStatusCache && (now - lastStatusCheck < STATUS_CACHE_TTL)) {
    return systemStatusCache;
  }

  try {
    const response = await fetch(API_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        action: SETUP_STATUS_ACTIONS.GET_SYSTEM_STATUS 
      })
    });

    if (!response.ok) {
      throw new Error(`Server responded with ${response.status}`);
    }

    const data = await response.json();
    systemStatusCache = data;
    lastStatusCheck = now;
    return data;
  } catch (error) {
    console.error('Error fetching system status:', error);
    return { 
      error: true, 
      message: error.message,
      components: {
        selinux: { status: 'unknown' },
        firewall: { status: 'unknown' },
        apparmor: { status: 'unknown' },
        permissions: { status: 'unknown' }
      }
    };
  }
}

/**
 * Run a specific setup action
 * @param {string} action - The action to run (from SETUP_STATUS_ACTIONS)
 * @param {Object} params - Additional parameters for the action
 */
async function runSetupAction(action, params = {}) {
  try {
    const response = await fetch(API_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        action,
        ...params
      })
    });

    if (!response.ok) {
      throw new Error(`Server responded with ${response.status}`);
    }

    const data = await response.json();
    // Invalidate cache after any action
    systemStatusCache = null;
    return data;
  } catch (error) {
    console.error(`Error running setup action ${action}:`, error);
    return { 
      error: true, 
      message: error.message 
    };
  }
}

/**
 * Run the full setup process
 * This will call setup.sh with the appropriate parameters
 */
async function runFullSetup() {
  return runSetupAction(SETUP_STATUS_ACTIONS.RUN_SETUP);
}

/**
 * Run just the packages validation
 * This will call packages.sh to verify the system configuration
 */
async function runPackagesValidation() {
  return runSetupAction(SETUP_STATUS_ACTIONS.RUN_PACKAGES);
}

/**
 * Check specific component status
 * @param {string} component - The component to check (selinux, firewall, apparmor, permissions)
 */
async function checkComponentStatus(component) {
  const componentMap = {
    'selinux': SETUP_STATUS_ACTIONS.CHECK_SELINUX,
    'firewall': SETUP_STATUS_ACTIONS.CHECK_FIREWALL,
    'apparmor': SETUP_STATUS_ACTIONS.CHECK_APPARMOR,
    'permissions': SETUP_STATUS_ACTIONS.CHECK_PERMISSIONS
  };

  if (!componentMap[component]) {
    return { error: true, message: `Unknown component: ${component}` };
  }

  return runSetupAction(componentMap[component]);
}

/**
 * Render the setup status in the UI
 * @param {HTMLElement} container - The container element to render into
 * @param {Object} status - The status object from fetchSystemStatus
 */
function renderSetupStatus(container, status) {
  if (!container) return;

  if (status.error) {
    container.innerHTML = `      <div class="error-message">
        <h3>Error Retrieving Status</h3>
        <p>${status.message}</p>
      </div>
      <button id="retry-status" class="action-button">Retry</button>
    `;
    document.getElementById('retry-status')?.addEventListener('click', async () => {
      container.innerHTML = '<p>Loading status...</p>';
      const newStatus = await fetchSystemStatus(true);
      renderSetupStatus(container, newStatus);
    });
    return;
  }

  // Create status indicators
  const components = status.components || {};
  let html = `
    <h2>System Security Status</h2>
    <div class="status-grid">
  `;

  for (const [name, info] of Object.entries(components)) {
    const statusClass = info.status === 'ok' ? 'status-online' : 
                       (info.status === 'warning' ? 'status-warning' : 'status-offline');
    
    html += `
      <div class="status-item">
        <span class="status ${statusClass}"></span>
        <span class="status-name">${name.charAt(0).toUpperCase() + name.slice(1)}</span>
        <span class="status-info">${info.message || ''}</span>
        <button class="check-button" data-component="${name}">Check</button>
      </div>
    `;
  }

  html += `
    </div>
    <div class="action-buttons">
      <button id="run-setup" class="action-button">Run Full Setup</button>
      <button id="run-packages" class="action-button">Validate Packages</button>
      <button id="refresh-status" class="action-button">Refresh Status</button>
    </div>
    <div id="action-output"></div>
  `;

  container.innerHTML = html;

  // Add event listeners
  document.getElementById('run-setup')?.addEventListener('click', async () => {
    const outputEl = document.getElementById('action-output');
    outputEl.innerHTML = '<p>Running setup...</p>';
    const result = await runFullSetup();
    outputEl.innerHTML = `<pre>${JSON.stringify(result, null, 2)}</pre>`;
  });

  document.getElementById('run-packages')?.addEventListener('click', async () => {
    const outputEl = document.getElementById('action-output');
    outputEl.innerHTML = '<p>Validating packages...</p>';
    const result = await runPackagesValidation();
    outputEl.innerHTML = `<pre>${JSON.stringify(result, null, 2)}</pre>`;
  });

  document.getElementById('refresh-status')?.addEventListener('click', async () => {
    container.innerHTML = '<p>Refreshing status...</p>';
    const newStatus = await fetchSystemStatus(true);
    renderSetupStatus(container, newStatus);
  });

  // Add listeners for individual component checks
  document.querySelectorAll('.check-button').forEach(button => {
    button.addEventListener('click', async () => {
      const component = button.dataset.component;
      const outputEl = document.getElementById('action-output');
      outputEl.innerHTML = `<p>Checking ${component}...</p>`;
      const result = await checkComponentStatus(component);
      outputEl.innerHTML = `<pre>${JSON.stringify(result, null, 2)}</pre>`;
    });
  });
}

// Export functions for use in main.js
window.HardnSetup = {
  fetchSystemStatus,
  runSetupAction,
  runFullSetup,
  runPackagesValidation,
  checkComponentStatus,
  renderSetupStatus,
  SETUP_STATUS_ACTIONS
};

/**
 * HARDN System Integration
 * This module establishes and maintains the connection to the backend proxy API
 */

// API configuration
const HARDN_API_ENDPOINT = 'http://localhost:8081/api';
const API_RETRY_ATTEMPTS = 3;
const API_RETRY_DELAY = 1000; // 1 second

// Global API client for all components to use
const APIClient = {
  /**
   * Make an API request with retry logic
   * @param {string} action - The API action to request
   * @param {Object} params - Additional parameters (optional)
   * @param {boolean} suppressErrors - Whether to suppress error messages
   * @returns {Promise<Object>} - The API response
   */
  async request(action, params = {}, suppressErrors = false) {
    const requestData = {
      action,
      ...params
    };

    let attempts = 0;
    
    while (attempts < API_RETRY_ATTEMPTS) {
      try {
        attempts++;
        const response = await fetch(HARDN_API_ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(requestData)
        });
        
        if (!response.ok) {
          throw new Error(`API error: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Check for API-level errors
        if (data.error) {
          throw new Error(data.error);
        }
        
        return data;
      } catch (error) {
        if (attempts >= API_RETRY_ATTEMPTS) {
          if (!suppressErrors) {
            console.error(`API request failed after ${attempts} attempts:`, error);
            // Show error in UI if available
            if (typeof showToast === 'function') {
              showToast(`Connection error: ${error.message}`, 'error');
            }
          }
          return { error: error.message, status: 'error' };
        }
        
        // Wait before retrying
        await new Promise(resolve => setTimeout(resolve, API_RETRY_DELAY));
      }
    }
  },
  
  /**
   * Get system status from the backend
   * @returns {Promise<Object>} The system status data
   */
  async getSystemStatus() {
    return this.request('get_system_status');
  },
  
  /**
   * Get security status summary
   * @returns {Promise<Object>} The security status summary
   */
  async getSecurityStatus() {
    return this.request('status');
  },
  
  /**
   * Get network status data
   * @returns {Promise<Object>} The network status data
   */
  async getNetworkStatus() {
    return this.request('network_status');
  },
  
  /**
   * Get threat data
   * @returns {Promise<Object>} The threat data
   */
  async getThreatData() {
    return this.request('threats');
  },
  
  /**
   * Get system logs
   * @param {number} limit - Maximum number of logs to retrieve
   * @returns {Promise<Object>} The system logs
   */
  async getSystemLogs(limit = 10) {
    return this.request('get_logs', { limit });
  },
  
  /**
   * Run a security scan
   * @returns {Promise<Object>} The scan results
   */
  async runSecurityScan() {
    return this.request('run_security_scan');
  },
  
  /**
   * Update the threat database
   * @returns {Promise<Object>} The update results
   */
  async updateThreatDB() {
    return this.request('update_threat_db');
  },

  /**
   * Run network analysis
   * @returns {Promise<Object>} The analysis results
   */
  async runNetworkAnalysis() {
    return this.request('run_network_analysis');
  },
  
  /**
   * Check if the backend is available
   * @returns {Promise<boolean>} True if backend is available
   */
  async checkBackendAvailable() {
    try {
      const response = await this.request('ping', {}, true);
      return response && !response.error;
    } catch (error) {
      return false;
    }
  }
};

// Detect if running in VM environment and update UI
document.addEventListener('DOMContentLoaded', async () => {
  try {
    const status = await APIClient.getSystemStatus();
    if (status && status.environment === 'virtual_machine') {
      const vmIndicator = document.getElementById('vm-environment');
      if (vmIndicator) {
        vmIndicator.classList.add('active');
      }
    }
  } catch (error) {
    console.error('Error detecting environment:', error);
  }
});

// Global helper to format timestamps
function formatTimestamp(timestamp) {
  if (!timestamp) return 'Unknown';
  
  const date = new Date(timestamp);
  return date.toLocaleString();
}

// Global helper to show toast notifications
function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `
    <div class="toast-content">
      <i class="fas ${type === 'info' ? 'fa-info-circle' : type === 'error' ? 'fa-exclamation-circle' : 'fa-check-circle'}"></i>
      <span>${message}</span>
    </div>
  `;
  
  document.body.appendChild(toast);
  
  // Animate in
  setTimeout(() => {
    toast.classList.add('show');
  }, 10);
  
  // Animate out after 3 seconds
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => {
      document.body.removeChild(toast);
    }, 300);
  }, 3000);
} 
