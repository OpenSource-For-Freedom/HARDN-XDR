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
const API_URL = 'http://localhost:8080/api';
const SETUP_ENDPOINTS = {
  GET_SYSTEM_STATUS: 'get_system_status',
  CHECK_SELINUX: 'check_selinux',
  CHECK_FIREWALL: 'check_firewall',
  CHECK_APPARMOR: 'check_apparmor',
  CHECK_PERMISSIONS: 'check_permissions',
  RUN_SETUP: 'run_setup',
  RUN_PACKAGES: 'run_packages',
  RUN_SECURITY_TOOL: 'run_security_tool',
  SECURITY_TOOL_STATUS: 'security_tool_status'
};

// Security Tools definitions
const SECURITY_TOOLS = {
  apparmor: {
    name: "AppArmor",
    description: "Mandatory Access Control (MAC) system that restricts programs' capabilities",
    status: null,
    canEnable: true
  },
  aide: {
    name: "AIDE",
    description: "Advanced Intrusion Detection Environment - monitors file changes",
    status: null,
    canEnable: true
  },
  fail2ban: {
    name: "Fail2Ban",
    description: "Intrusion prevention framework that protects against brute-force attacks",
    status: null,
    canEnable: true
  },
  firejail: {
    name: "Firejail",
    description: "Security sandbox program that reduces the risk of security breaches",
    status: null,
    canEnable: true
  },
  rkhunter: {
    name: "RKHunter",
    description: "Rootkit Hunter - scans for rootkits, backdoors and local exploits",
    status: null,
    canEnable: true
  }
};

// Cache for system status
let systemStatusCache = null;
let lastStatusCheck = 0;
const STATUS_CACHE_TTL = 60000; // 1 minute

/**
 * Initialize security tools status
 * This will query the backend for the status of each tool
 */
async function initializeSecurityToolsStatus() {
  for (const [toolId, toolInfo] of Object.entries(SECURITY_TOOLS)) {
    try {
      const status = await getSecurityToolStatus(toolId);
      SECURITY_TOOLS[toolId].status = status.enabled ? 'enabled' : 'disabled';
      SECURITY_TOOLS[toolId].details = status.details || {};
    } catch (err) {
      console.error(`Failed to get status for ${toolId}:`, err);
      SECURITY_TOOLS[toolId].status = 'unknown';
    }
  }
  return SECURITY_TOOLS;
}

/**
 * Get status of a security tool
 * @param {string} toolId - Tool identifier (e.g., 'apparmor', 'aide')
 */
async function getSecurityToolStatus(toolId) {
  try {
    // Use centralized APIClient if available
    if (typeof window.APIClient === 'object' && typeof window.APIClient.getSecurityToolStatus === 'function') {
      return await window.APIClient.getSecurityToolStatus(toolId);
    } else {
      // Fallback to direct request
      return await setupApiRequest(`${SETUP_ENDPOINTS.SECURITY_TOOL_STATUS}/${toolId}`);
    }
  } catch (error) {
    console.error(`Error getting status for ${toolId}:`, error);
    return { enabled: false, error: error.message };
  }
}

/**
 * Run a security tool action
 * @param {string} toolId - Tool identifier
 * @param {string} action - Action to perform ('enable', 'disable', 'status', 'configure')
 * @param {Object} params - Additional parameters for the action
 */
async function runSecurityToolAction(toolId, action, params = {}) {
  try {
    // Use centralized APIClient if available
    if (typeof window.APIClient === 'object' && typeof window.APIClient.runSecurityTool === 'function') {
      return await window.APIClient.runSecurityTool(toolId, { action, ...params });
    } else {
      // Fallback to direct request
      return await setupApiRequest(SETUP_ENDPOINTS.RUN_SECURITY_TOOL, { 
        tool: toolId, 
        action, 
        params 
      }, 'POST');
    }
  } catch (error) {
    console.error(`Error running ${action} for ${toolId}:`, error);
    return { success: false, error: error.message };
  }
}

/**
 * Fetch system status from the backend
 * This will call the API endpoint for system status
 */
async function fetchSystemStatus(forceRefresh = false) {
  // Use cache if available and not expired
  const now = Date.now();
  if (!forceRefresh && systemStatusCache && (now - lastStatusCheck < STATUS_CACHE_TTL)) {
    return systemStatusCache;
  }

  try {
    // Ensure we have a valid token before making the request
    if (typeof window.ensureValidToken === 'function') {
      const tokenValid = await window.ensureValidToken();
      if (!tokenValid) {
        throw new Error('Authentication required');
      }
    }
    
    // Use centralized APIClient if available
    if (typeof window.APIClient === 'object' && typeof window.APIClient.getSystemStatus === 'function') {
      const data = await window.APIClient.getSystemStatus();
      systemStatusCache = data;
      lastStatusCheck = now;
      return data;
    } else {
      // Fallback to direct API call
      const data = await setupApiRequest(SETUP_ENDPOINTS.GET_SYSTEM_STATUS);
      systemStatusCache = data;
      lastStatusCheck = now;
      return data;
    }
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
 * Helper function for making API requests to setup endpoints
 * @param {string} endpoint - Endpoint path
 * @param {Object} data - Request data for POST requests
 * @param {string} method - HTTP method
 */
async function setupApiRequest(endpoint, data = null, method = 'GET') {
  const options = {
    method: method,
    headers: { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${window.authTokens?.accessToken || ''}`
    }
  };
  
  if (data && method !== 'GET') {
    options.body = JSON.stringify(data);
  }
  
  const response = await fetch(`${API_URL}/${endpoint}`, options);
  
  if (!response.ok) {
    throw new Error(`Server responded with ${response.status}`);
  }
  
  return await response.json();
}

/**
 * Run a specific setup action
 * @param {string} endpoint - The API endpoint to call (from SETUP_ENDPOINTS)
 * @param {Object} params - Additional parameters for the action
 */
async function runSetupAction(endpoint, params = {}) {
  try {
    // Ensure we have a valid token before making the request
    if (typeof window.ensureValidToken === 'function') {
      const tokenValid = await window.ensureValidToken();
      if (!tokenValid) {
        throw new Error('Authentication required');
      }
    }
    
    const data = await setupApiRequest(endpoint, params, 'POST');
    // Invalidate cache after any action
    systemStatusCache = null;
    return data;
  } catch (error) {
    console.error(`Error running setup action ${endpoint}:`, error);
    return { 
      error: true, 
      message: error.message 
    };
  }
}

/**
 * Run the full setup process
 * This will call the setup endpoint
 */
async function runFullSetup() {
  return runSetupAction(SETUP_ENDPOINTS.RUN_SETUP);
}

/**
 * Run just the packages validation
 * This will call the packages endpoint
 */
async function runPackagesValidation() {
  return runSetupAction(SETUP_ENDPOINTS.RUN_PACKAGES);
}

/**
 * Check specific component status
 * @param {string} component - The component to check (selinux, firewall, apparmor, permissions)
 */
async function checkComponentStatus(component) {
  const componentMap = {
    'selinux': SETUP_ENDPOINTS.CHECK_SELINUX,
    'firewall': SETUP_ENDPOINTS.CHECK_FIREWALL,
    'apparmor': SETUP_ENDPOINTS.CHECK_APPARMOR,
    'permissions': SETUP_ENDPOINTS.CHECK_PERMISSIONS
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

/**
 * HARDN System Integration
 * This module establishes and maintains the connection to the backend API
 */

// API configuration
const HARDN_API_URL = 'http://localhost:8080/api';
const API_RETRY_ATTEMPTS = 3;
const API_RETRY_DELAY = 1000; // 1 second

// Global API client for all components to use
const SystemAPIClient = {
  /**
   * Make an API request with retry logic
   * @param {string} endpoint - The API endpoint to request
   * @param {Object} params - Additional parameters (optional)
   * @param {string} method - HTTP method (GET or POST)
   * @param {boolean} suppressErrors - Whether to suppress error messages
   * @returns {Promise<Object>} - The API response
   */
  async request(endpoint, params = {}, method = 'POST', suppressErrors = false) {
    // Ensure we have a valid token before making the request
    if (typeof window.ensureValidToken === 'function') {
      const tokenValid = await window.ensureValidToken();
      if (!tokenValid && !suppressErrors) {
        throw new Error('Authentication required');
      }
    }

    let attempts = 0;
    
    while (attempts < API_RETRY_ATTEMPTS) {
      try {
        attempts++;
        
        const options = {
          method: method,
          headers: { 
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${window.authTokens?.accessToken || ''}`
          }
        };
        
        // Add request body for POST/PUT
        if (params && (method === 'POST' || method === 'PUT')) {
          options.body = JSON.stringify(params);
        }
        
        const response = await fetch(`${HARDN_API_URL}/${endpoint}`, options);
        
        if (!response.ok) {
          throw new Error(`API error: ${response.status}`);
        }
        
        return await response.json();
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
   * Get system status information
   * @returns {Promise<Object>} System status data
   */
  async getSystemStatus() {
    return this.request('get_system_status', null, 'GET');
  },
  
  /**
   * Get security status information
   * @returns {Promise<Object>} Security status data
   */
  async getSecurityStatus() {
    return this.request('get_security_status', null, 'GET');
  },
  
  /**
   * Get network status information
   * @returns {Promise<Object>} Network status data
   */
  async getNetworkStatus() {
    return this.request('get_network_status', null, 'GET');
  },
  
  /**
   * Get threat data information
   * @returns {Promise<Object>} Threat data
   */
  async getThreatData() {
    return this.request('get_threats', null, 'GET');
  },
  
  /**
   * Get system logs
   * @param {number} limit - Maximum number of logs to retrieve
   * @returns {Promise<Object>} System logs
   */
  async getSystemLogs(limit = 10) {
    return this.request(`get_logs?limit=${limit}`, null, 'GET');
  },
  
  /**
   * Run a security scan
   * @returns {Promise<Object>} Scan results
   */
  async runSecurityScan() {
    return this.request('run_security_scan', { scan_type: 'full' });
  },
  
  /**
   * Update the threat database
   * @returns {Promise<Object>} Update results
   */
  async updateThreatDB() {
    return this.request('update_threat_db');
  },

  /**
   * Run network analysis
   * @returns {Promise<Object>} Analysis results
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
      const result = await this.request('check_backend', null, 'GET', true);
      return result && !result.error;
    } catch (error) {
      return false;
    }
  }
};

// Detect if running in VM environment and update UI
document.addEventListener('DOMContentLoaded', async () => {
  try {
    const status = await SystemAPIClient.getSystemStatus();
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
  // Use global toast if available
  if (typeof window.showToast === 'function') {
    window.showToast(message, type);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
}

// Export functionality for use in main.js
window.HardnSetup = {
  fetchSystemStatus,
  runSetupAction,
  runFullSetup,
  runPackagesValidation,
  checkComponentStatus,
  renderSetupStatus,
  SETUP_ENDPOINTS,
  APIClient: SystemAPIClient
}; 
