/**
 * HARDN Main Application
 * Handles UI navigation and component initialization
 */

// Current active section
let currentSection = 'dashboard';

// Initialize the application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  console.log('HARDN GUI Initializing...');
  
  // Set up navigation
  setupNavigation();
  
  // Load dashboard by default
  loadSection('dashboard');
  
  // Add status bar text updater
  setupStatusBar();
});

/**
 * Set up navigation event listeners
 */
function setupNavigation() {
  // Navigation items
  const navItems = {
    'dashboard': document.getElementById('nav-dashboard'),
    'network': document.getElementById('nav-network'),
    'threats': document.getElementById('nav-threats'),
    'logs': document.getElementById('nav-logs'),
    'setup': document.getElementById('nav-setup')
  };
  
  // Add click handlers
  Object.entries(navItems).forEach(([section, element]) => {
    if (element) {
      element.addEventListener('click', () => loadSection(section));
    }
  });
}

/**
 * Load a specific section
 * @param {string} section - Section name to load
 */
function loadSection(section) {
  console.log(`Loading section: ${section}`);
  
  // Update active navigation item
  document.querySelectorAll('.nav-item').forEach(item => {
    item.classList.remove('active');
  });
  
  const navButton = document.getElementById(`nav-${section}`);
  if (navButton) {
    navButton.classList.add('active');
  }
  
  // Store current section
  currentSection = section;
  
  // Clear main content
  const mainContent = document.getElementById('main-content');
  if (!mainContent) return;
  
  // Show loading state
  mainContent.innerHTML = `
    <div class="section-loading">
      <div class="loading-spinner"></div>
      <p>Loading ${section} data...</p>
    </div>
  `;
  
  // Check backend connection before loading component
  APIClient.checkBackendAvailable()
    .then(isAvailable => {
      if (!isAvailable) {
        mainContent.innerHTML = `
          <div class="connection-error">
            <i class="fas fa-exclamation-triangle"></i>
            <h3>Backend Connection Error</h3>
            <p>Unable to connect to the HARDN backend services. Please ensure the backend is running.</p>
            <button class="btn btn-action" onclick="loadSection('${section}')">
              <i class="fas fa-sync-alt"></i> Retry Connection
            </button>
          </div>
        `;
        return;
      }
      
      // Initialize the appropriate component based on section
      switch (section) {
        case 'dashboard':
          // Initialize dashboard
          if (typeof HARDNDashboard !== 'undefined') {
            HARDNDashboard.init();
          } else {
            mainContent.innerHTML = '<div class="error-message">Dashboard component not available</div>';
          }
          break;
          
        case 'network':
          // Initialize network view
          if (typeof HARDNNetwork !== 'undefined') {
            HARDNNetwork.init();
          } else {
            mainContent.innerHTML = '<div class="error-message">Network component not available</div>';
          }
          break;
          
        case 'threats':
          // Initialize threats view
          if (typeof HARDNThreats !== 'undefined') {
            HARDNThreats.init();
          } else {
            mainContent.innerHTML = '<div class="error-message">Threats component not available</div>';
          }
          break;
          
        case 'logs':
          // Initialize logs view
          if (typeof HARDNLogs !== 'undefined') {
            HARDNLogs.init();
          } else {
            mainContent.innerHTML = '<div class="error-message">Logs component not available</div>';
          }
          break;
          
        case 'setup':
          // Initialize setup view
          if (typeof HARDNSetup !== 'undefined') {
            HARDNSetup.init();
          } else {
            mainContent.innerHTML = '<div class="error-message">Setup component not available</div>';
          }
          break;
          
        default:
          mainContent.innerHTML = '<div class="error-message">Unknown section requested</div>';
      }
    })
    .catch(error => {
      console.error('Error checking backend availability:', error);
      mainContent.innerHTML = `
        <div class="connection-error">
          <i class="fas fa-exclamation-triangle"></i>
          <h3>Connection Error</h3>
          <p>An error occurred: ${error.message}</p>
          <button class="btn btn-action" onclick="loadSection('${section}')">
            <i class="fas fa-sync-alt"></i> Retry
          </button>
        </div>
      `;
    });
  
  // Update footer status
  updateFooterStatus(`${section.charAt(0).toUpperCase() + section.slice(1)} view loaded`);
}

/**
 * Set up the status bar in the footer
 */
function setupStatusBar() {
  // Update timestamp periodically
  const updateTimestamp = () => {
    const footerStatus = document.querySelector('footer span');
    if (footerStatus) {
      const now = new Date();
      const hours = now.getHours().toString().padStart(2, '0');
      const minutes = now.getMinutes().toString().padStart(2, '0');
      const seconds = now.getSeconds().toString().padStart(2, '0');
      
      footerStatus.textContent = `[${hours}:${minutes}:${seconds}] Ready`;
    }
  };
  
  // Update every second
  updateTimestamp();
  setInterval(updateTimestamp, 1000);
}

/**
 * Update footer status text
 * @param {string} message - Status message to display
 */
function updateFooterStatus(message) {
  const footerStatus = document.querySelector('footer span');
  if (footerStatus) {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    const seconds = now.getSeconds().toString().padStart(2, '0');
    
    footerStatus.textContent = `[${hours}:${minutes}:${seconds}] ${message}`;
  }
}

/**
 * Check if backend services are available
 * @returns {Promise<boolean>} True if backend is available
 */
async function checkBackendAvailable() {
  try {
    if (typeof APIClient !== 'undefined') {
      return await APIClient.checkBackendAvailable();
    }
    return false;
  } catch (error) {
    console.error('Error checking backend:', error);
    return false;
  }
}

// Global helper to format timestamps
function formatTime(timestamp) {
  if (!timestamp) return '';
  
  const date = new Date(timestamp);
  return date.toLocaleTimeString();
}

// Global helper to format dates
function formatDate(timestamp) {
  if (!timestamp) return '';
  
  const date = new Date(timestamp);
  return date.toLocaleDateString();
}

// Expose functions to window scope
window.HARDN = {
  loadSection,
  updateFooterStatus,
  checkBackendAvailable,
  formatTime,
  formatDate
};

// Navigation logic
document.addEventListener('DOMContentLoaded', () => {
  const navButtons = document.querySelectorAll('.nav-item');
  const mainContent = document.getElementById('main-content');
  const statusBar = document.querySelector('footer span:first-child');
  
  // Make sure the VM indicator works and detect environment
  const envIndicator = document.getElementById('vm-environment');
  if (envIndicator) {
    detectEnvironment(envIndicator);
  }

  // Set up HARDN module initializations
  initializeHARDNModules();

  navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      navButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const section = btn.id.replace('nav-', '');
      loadSection(section);
    });
  });
  
  function setStatus(msg, isError = false) {
    if (statusBar) {
      statusBar.textContent = msg;
      statusBar.style.color = isError ? 'var(--accent-danger)' : '';
    }
  }
  
  function loadSection(section) {
    console.log(`Loading section: ${section}`);
    setStatus('Loading ' + section + '...');
    
    switch (section) {
      case 'dashboard':
        loadDashboardView();
        break;
      case 'network':
        fetchBackend('network');
        break;
      case 'threats':
        fetchBackend('threats');
        break;
      case 'logs':
        fetchBackend('logs');
        break;
      case 'setup':
        loadSetupView();
        break;
      default:
        mainContent.innerHTML = '<div class="section-header"><h2>Unknown Section</h2></div><p>This section is not available.</p>';
        setStatus('Unknown section.', true);
    }
    
    // Dispatch a custom event when a section is loaded
    document.dispatchEvent(new CustomEvent('sectionLoaded', { 
      detail: { section } 
    }));
  }
  
  function loadDashboardView() {
    // Default dashboard content
    const dashboardContent = `
      <section class="section-header">
        <h2>Security Dashboard</h2>
        <div class="update-info">
          <span>Last updated: <span id="last-updated-time">--:--</span></span>
          <button class="btn-refresh"><i class="fas fa-sync-alt"></i></button>
        </div>
      </section>
      
      <section class="security-summary">
        <div class="summary-card">
          <h3>System Security</h3>
          <span id="system-security-status" class="summary-status ok">Secure</span>
        </div>
        <div class="summary-card">
          <h3>Network Status</h3>
          <span id="network-status" class="summary-status ok">Protected</span>
        </div>
        <div class="summary-card">
          <h3>Threat Level</h3>
          <span id="threat-level-status" class="summary-status ok">Low</span>
        </div>
      </section>
      
      <section class="security-components" id="status-container">
        <h3>Security Components</h3>
        <ul id="security-components-list" class="security-components-list">
          <!-- Security components will be inserted here by JavaScript -->
        </ul>
      </section>
      
      <section class="quick-actions">
        <h3>Quick Actions</h3>
        <div class="action-buttons">
          <button id="run-scan-button" class="action-btn">
            <i class="fas fa-search"></i>
            <span>Run Security Scan</span>
          </button>
          <button id="update-db-button" class="action-btn">
            <i class="fas fa-database"></i>
            <span>Update Threat DB</span>
          </button>
          <button id="network-analysis-button" class="action-btn">
            <i class="fas fa-network-wired"></i>
            <span>Network Analysis</span>
          </button>
          <button id="view-report-button" class="action-btn">
            <i class="fas fa-file-alt"></i>
            <span>View Full Report</span>
          </button>
        </div>
      </section>
      
      <section class="recent-activity">
        <h3>Recent Activity</h3>
        <div class="activity-log">
          <div class="activity-item">
            <div class="activity-icon info">
              <i class="fas fa-info-circle"></i>
            </div>
            <div class="activity-content">
              <span class="activity-title">System Check Completed</span>
              <span class="activity-time">Today, 10:45 AM</span>
              <p class="activity-description">Routine system security check completed with no issues found.</p>
            </div>
          </div>
          
          <div class="activity-item">
            <div class="activity-icon warning">
              <i class="fas fa-exclamation-triangle"></i>
            </div>
            <div class="activity-content">
              <span class="activity-title">Update Required</span>
              <span class="activity-time">Today, 09:30 AM</span>
              <p class="activity-description">Security definitions update is available and recommended.</p>
            </div>
          </div>
          
          <div class="activity-item">
            <div class="activity-icon error">
              <i class="fas fa-times-circle"></i>
            </div>
            <div class="activity-content">
              <span class="activity-title">Unusual Login Attempt</span>
              <span class="activity-time">Yesterday, 11:52 PM</span>
              <p class="activity-description">Multiple failed login attempts detected from IP 192.168.1.45.</p>
            </div>
          </div>
        </div>
      </section>
    `;
    
    mainContent.innerHTML = dashboardContent;
    
    // Initialize dashboard components
    initializeDashboard();
    setStatus('Dashboard loaded.');
  }
  
  function loadSetupView() {
    mainContent.innerHTML = `
      <section class="section-header">
        <h2>System Setup</h2>
        <div class="update-info">
          <span>Last updated: <span id="setup-last-updated">--:--</span></span>
          <button class="btn-refresh" id="refresh-setup"><i class="fas fa-sync-alt"></i></button>
        </div>
      </section>
      <div id="setup-container"><p>Loading system status...</p></div>
    `;
    
    // Use the setup integration module
    if (window.HardnSetup) {
      window.HardnSetup.fetchSystemStatus()
        .then(status => {
          const container = document.getElementById('setup-container');
          window.HardnSetup.renderSetupStatus(container, status);
          document.getElementById('setup-last-updated').textContent = formatTime(new Date());
          setStatus('Setup view loaded.');
        })
        .catch(err => {
          mainContent.innerHTML = `<div class="error-message">
            <h3>Error Loading Setup</h3>
            <p>${err.message}</p>
            <button class="action-button" id="retry-setup">Retry</button>
          </div>`;
          setStatus('Failed to load setup view', true);
          
          document.getElementById('retry-setup')?.addEventListener('click', () => loadSetupView());
        });
    } else {
      mainContent.innerHTML = `<div class="error-message">
        <h3>Setup Module Not Available</h3>
        <p>The setup integration module could not be loaded. Please check that all required files are present.</p>
      </div>`;
      setStatus('Setup module not available', true);
    }
  }
  
  async function fetchBackend(action, data = {}) {
    const contentMapping = {
      'network': 'Network Connections',
      'threats': 'Threat Analysis', 
      'logs': 'System Logs'
    };
    
    mainContent.innerHTML = `
      <section class="section-header">
        <h2>${contentMapping[action] || action.charAt(0).toUpperCase() + action.slice(1)}</h2>
        <div class="update-info">
          <span>Fetching data...</span>
        </div>
      </section>
      <div class="loading-container">
        <div class="loading-spinner"></div>
        <p>Connecting to secure backend...</p>
      </div>
    `;
    
    setStatus('Contacting backend...');
    try {
      const res = await fetch('http://localhost:8081/api', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, ...data })
      });
      
      if (!res.ok) throw new Error('Proxy error: ' + res.status);
      const result = await res.json();
      renderSection(action, result);
      setStatus(`${contentMapping[action] || action} loaded.`);
      
    } catch (err) {
      mainContent.innerHTML = `
        <section class="section-header">
          <h2>${contentMapping[action] || action.charAt(0).toUpperCase() + action.slice(1)}</h2>
        </section>
        <div class="error-message">
          <h3>Connection Error</h3>
          <p>${err.message}</p>
          <button class="action-button" id="retry-${action}">Retry</button>
        </div>
      `;
      
      setStatus(`Failed to load ${action}`, true);
      document.getElementById(`retry-${action}`)?.addEventListener('click', () => fetchBackend(action, data));
    }
  }
  
  function renderSection(section, data) {
    switch (section) {
      case 'network':
        renderNetworkSection(data);
        break;
      case 'threats':
        renderThreatsSection(data);
        break;
      case 'logs':
        renderLogsSection(data);
        break;
      default:
        mainContent.innerHTML = `
          <section class="section-header">
            <h2>Unknown Data</h2>
          </section>
          <p>The requested data could not be displayed.</p>
        `;
    }
  }
  
  function renderNetworkSection(data) {
    let connectionList = '';
    
    if (data && data.length) {
      connectionList = data.map(conn => `
        <tr>
          <td>${conn.ip}</td>
          <td>${conn.port}</td>
          <td><span class="badge badge-success">Open</span></td>
          <td>
            <button class="btn-icon small"><i class="fas fa-info-circle"></i></button>
            <button class="btn-icon small"><i class="fas fa-ban"></i></button>
          </td>
        </tr>
      `).join('');
    } else {
      connectionList = `
        <tr>
          <td colspan="4" class="text-center">No active connections found</td>
        </tr>
      `;
    }
    
    mainContent.innerHTML = `
      <section class="section-header">
        <h2>Network Connections</h2>
        <div class="update-info">
          <span>Last updated: ${formatTime(new Date())}</span>
          <button class="btn-refresh" id="refresh-network"><i class="fas fa-sync-alt"></i></button>
        </div>
      </section>
      
      <section class="data-card">
        <div class="card-header">
          <h3>Active Network Connections</h3>
          <div class="card-actions">
            <button class="btn-text"><i class="fas fa-filter"></i> Filter</button>
            <button class="btn-text"><i class="fas fa-download"></i> Export</button>
          </div>
        </div>
        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>IP Address</th>
                <th>Port</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              ${connectionList}
            </tbody>
          </table>
        </div>
      </section>
      
      <section class="data-card">
        <div class="card-header">
          <h3>Network Statistics</h3>
        </div>
        <div class="stat-grid">
          <div class="stat-item">
            <span class="stat-value">${data ? data.length : 0}</span>
            <span class="stat-label">Active Connections</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">0</span>
            <span class="stat-label">Blocked Attempts</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">100%</span>
            <span class="stat-label">Uptime</span>
          </div>
        </div>
      </section>
    `;
    
    // Initialize network module
    if (window.HARDNNetwork) {
      window.HARDNNetwork.renderNetworkData(data);
    }
    
    setStatus('Network view loaded.');
  }
  
  function renderThreatsSection(data) {
    let threatItems = '';
    
    if (data && data.items && data.items.length) {
      threatItems = data.items.map(threat => {
        const levelClass = threat.level > 2 ? 'high' : (threat.level > 1 ? 'medium' : 'low');
        return `
          <tr>
            <td><span class="threat-level ${levelClass}">${threat.level}</span></td>
            <td>${threat.description}</td>
            <td>
              <button class="btn-icon small"><i class="fas fa-shield-alt"></i></button>
              <button class="btn-icon small"><i class="fas fa-times"></i></button>
            </td>
          </tr>
        `;
      }).join('');
    } else {
      threatItems = `
        <tr>
          <td colspan="3" class="text-center">No threats detected</td>
        </tr>
      `;
    }
    
    mainContent.innerHTML = `
      <section class="section-header">
        <h2>Threat Analysis</h2>
        <div class="update-info">
          <span>Last updated: ${formatTime(new Date())}</span>
          <button class="btn-refresh" id="refresh-threats"><i class="fas fa-sync-alt"></i></button>
        </div>
      </section>
      
      <section class="security-summary">
        <div class="summary-card">
          <h3>Current Threat Level</h3>
          <span class="summary-status ${data && data.level > 2 ? 'error' : (data && data.level > 1 ? 'warning' : 'ok')}">
            ${data ? (data.level > 2 ? 'High' : (data.level > 1 ? 'Medium' : 'Low')) : 'Unknown'}
          </span>
        </div>
        <div class="summary-card">
          <h3>Active Threats</h3>
          <span class="summary-status ${data && data.items && data.items.length > 0 ? 'warning' : 'ok'}">
            ${data && data.items ? data.items.length : 0} Detected
          </span>
        </div>
        <div class="summary-card">
          <h3>Last Scan</h3>
          <span class="summary-status ok">Today, ${formatTime(new Date())}</span>
        </div>
      </section>
      
      <section class="data-card">
        <div class="card-header">
          <h3>Detected Threats</h3>
          <div class="card-actions">
            <button class="btn-text"><i class="fas fa-shield-alt"></i> Mitigate All</button>
            <button class="btn-text"><i class="fas fa-download"></i> Export</button>
          </div>
        </div>
        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>Level</th>
                <th>Description</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              ${threatItems}
            </tbody>
          </table>
        </div>
      </section>
    `;
    
    // Initialize threats module
    if (window.HARDNThreats) {
      window.HARDNThreats.renderThreatData(data);
    }
    
    setStatus('Threats view loaded.');
  }
  
  function renderLogsSection(data) {
    let logItems = '';
    
    if (data && data.length) {
      logItems = data.map(log => {
        const isError = log.toLowerCase().includes('error') || log.toLowerCase().includes('fail');
        const isWarning = log.toLowerCase().includes('warn') || log.toLowerCase().includes('attention');
        const logClass = isError ? 'log-error' : (isWarning ? 'log-warning' : '');
        
        return `<div class="log-item ${logClass}">${log}</div>`;
      }).join('');
    } else {
      logItems = `<div class="log-item log-empty">No logs available</div>`;
    }
    
    mainContent.innerHTML = `
      <section class="section-header">
        <h2>System Logs</h2>
        <div class="update-info">
          <span>Last updated: ${formatTime(new Date())}</span>
          <button class="btn-refresh" id="refresh-logs"><i class="fas fa-sync-alt"></i></button>
        </div>
      </section>
      
      <section class="data-card">
        <div class="card-header">
          <h3>System Logs</h3>
          <div class="card-actions">
            <button class="btn-text"><i class="fas fa-filter"></i> Filter</button>
            <button class="btn-text"><i class="fas fa-download"></i> Export</button>
          </div>
        </div>
        <div class="log-container">
          ${logItems}
        </div>
      </section>
    `;
    
    // Initialize logs module
    if (window.HARDNLogs) {
      window.HARDNLogs.renderLogData(data);
    }
    
    setStatus('Logs view loaded.');
  }
  
  // Load dashboard by default
  loadDashboardView();
  
  // Rest of the initialization code
  const API_BASE_URL = 'http://localhost:8082';
  
  // DOM elements
  const statusContainer = document.getElementById('status-container');
  const securityComponentsList = document.getElementById('security-components-list');
  const systemSecurityStatus = document.getElementById('system-security-status');
  const networkStatus = document.getElementById('network-status');
  const threatLevelStatus = document.getElementById('threat-level-status');
  const lastUpdatedTime = document.getElementById('last-updated-time');
  
  // Initialize the dashboard
  function initializeDashboard() {
    updateStatus();
    setupEventListeners();
  }
  
  /**
   * Set up event listeners for all interactive elements
   */
  function setupEventListeners() {
    // Quick action buttons
    document.getElementById('run-scan-button')?.addEventListener('click', runSecurityScan);
    document.getElementById('update-db-button')?.addEventListener('click', updateThreatDatabase);
    document.getElementById('network-analysis-button')?.addEventListener('click', runNetworkAnalysis);
    document.getElementById('view-report-button')?.addEventListener('click', viewFullReport);
  }
  
  /**
   * Fetch and update system status information
   */
  async function updateStatus() {
    try {
      // For demo, just update the UI with hard-coded data
      updateSummaryItems();
      updateSecurityComponents();
      checkVmStatus();
      updateLastUpdatedTime();
    } catch (error) {
      console.error('Status update failed:', error);
      setServiceOfflineState();
    }
  }
  
  /**
   * Update the summary items with current status data
   */
  function updateSummaryItems() {
    if (systemSecurityStatus) {
      systemSecurityStatus.textContent = "Secure";
      systemSecurityStatus.className = "summary-status ok";
    }
    
    if (networkStatus) {
      networkStatus.textContent = "Protected";
      networkStatus.className = "summary-status ok";
    }
    
    if (threatLevelStatus) {
      threatLevelStatus.textContent = "Low";
      threatLevelStatus.className = "summary-status ok";
    }
  }
  
  /**
   * Update the security components list with current status
   */
  function updateSecurityComponents() {
    if (!securityComponentsList) return;
    
    // Clear existing list items
    securityComponentsList.innerHTML = '';
    
    // Add sample components
    addComponentStatus(
      securityComponentsList,
      'Core System',
      'Online',
      'status-online',
      'All security features active',
      'Last checked: ' + formatTime(new Date())
    );
    
    addComponentStatus(
      securityComponentsList,
      'Network Scanner',
      'Active',
      'status-online',
      'No threats detected',
      'Last scan: ' + formatTime(new Date(Date.now() - 3600000)) // 1 hour ago
    );
    
    addComponentStatus(
      securityComponentsList,
      'Threat Database',
      'Updated',
      'status-online',
      'Latest definitions',
      'Last update: ' + formatTime(new Date(Date.now() - 86400000)) // 1 day ago
    );
    
    addComponentStatus(
      securityComponentsList,
      'AppArmor',
      'Enforcing',
      'status-online',
      'Profiles loaded',
      'Status checked: ' + formatTime(new Date())
    );
  }
  
  /**
   * Add a component status to the security components list
   */
  function addComponentStatus(parentElement, name, status, statusClass, details, timestamp) {
    const li = document.createElement('li');
    
    const statusIndicator = document.createElement('span');
    statusIndicator.className = `status ${statusClass}`;
    
    const nameSpan = document.createElement('span');
    nameSpan.textContent = name;
    
    const statusLabel = document.createElement('span');
    statusLabel.className = 'highlight';
    statusLabel.textContent = status;
    
    const detailsDiv = document.createElement('div');
    detailsDiv.className = 'component-details';
    
    const statusDetails = document.createElement('span');
    statusDetails.className = 'status-details';
    statusDetails.textContent = details;
    
    const timestampSpan = document.createElement('span');
    timestampSpan.className = 'component-timestamp';
    timestampSpan.textContent = timestamp;
    
    detailsDiv.appendChild(statusDetails);
    detailsDiv.appendChild(timestampSpan);
    
    li.appendChild(statusIndicator);
    li.appendChild(nameSpan);
    li.appendChild(statusLabel);
    li.appendChild(detailsDiv);
    
    parentElement.appendChild(li);
  }
  
  /**
   * Check if system is running in a VM and detect environment type
   */
  async function checkVmStatus() {
    // For demo purposes, detect and show environment indicator
    const envIndicator = document.getElementById('vm-environment');
    if (envIndicator) {
      detectEnvironment(envIndicator);
    }
  }
  
  /**
   * Detect the current environment type and update the indicator
   */
  function detectEnvironment(indicator) {
    // Try to detect environment - this is a simplified detection
    // In a real implementation, this would use more robust methods
    const userAgent = navigator.userAgent.toLowerCase();
    let envType = "Unknown";
    let icon = "fas fa-server";
    
    if (window.navigator.platform.includes('Win')) {
      envType = "Windows Environment";
      icon = "fab fa-windows";
    } else if (window.navigator.platform.includes('Mac')) {
      envType = "macOS Environment";
      icon = "fab fa-apple";
    } else if (userAgent.includes('linux')) {
      envType = "Linux Environment";
      icon = "fab fa-linux";
    } else if (userAgent.includes('android')) {
      envType = "Android Environment";
      icon = "fab fa-android";
    } else if (/iphone|ipad|ipod/.test(userAgent)) {
      envType = "iOS Environment";
      icon = "fab fa-apple";
    }
    
    // Check for common virtualization signatures
    if (userAgent.includes('virtualbox') || userAgent.includes('vmware') || 
        document.referrer.includes('virtualbox') || document.referrer.includes('vmware')) {
      envType = "VM Environment";
      icon = "fas fa-server";
    }
    
    // Additional check via WebGL (might detect some VM environments)
    try {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl');
      if (gl) {
        const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
        if (debugInfo) {
          const renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL).toLowerCase();
          if (renderer.includes('vmware') || renderer.includes('virtualbox') || 
              renderer.includes('llvmpipe') || renderer.includes('swiftshader')) {
            envType = "VM Environment";
            icon = "fas fa-server";
          }
        }
      }
    } catch (e) {
      console.error("WebGL detection failed:", e);
    }
    
    // Update the indicator
    indicator.innerHTML = `<i class="${icon}"></i><span>${envType}</span>`;
    indicator.style.display = 'flex';
  }
  
  /**
   * Update the last updated time display
   */
  function updateLastUpdatedTime() {
    if (lastUpdatedTime) {
      lastUpdatedTime.textContent = formatTime(new Date());
    }
  }
  
  /**
   * Security scan action
   */
  function runSecurityScan() {
    showToast('Running security scan...');
    // Placeholder for actual implementation
    setTimeout(() => {
      showToast('Security scan completed - No threats detected');
      updateStatus();
    }, 2000);
  }
  
  /**
   * Update threat database action
   */
  function updateThreatDatabase() {
    showToast('Updating threat database...');
    // Placeholder for actual implementation
    setTimeout(() => {
      showToast('Threat database updated successfully');
      updateStatus();
    }, 2000);
  }
  
  /**
   * Run network analysis action
   */
  function runNetworkAnalysis() {
    showToast('Running network analysis...');
    // Placeholder for actual implementation
    setTimeout(() => {
      showToast('Network analysis completed - All connections secure');
      updateStatus();
    }, 3000);
  }
  
  /**
   * View full security report action
   */
  function viewFullReport() {
    // Navigate to reports section
    const reportsButton = document.querySelector('.nav-item:nth-child(6)');
    if (reportsButton) {
      reportsButton.click();
    } else {
      showToast('Full report feature coming soon');
    }
  }
  
  /**
   * Show a toast notification
   */
  function showToast(message) {
    // Create toast container if it doesn't exist
    let toastContainer = document.getElementById('toast-container');
    if (!toastContainer) {
      toastContainer = document.createElement('div');
      toastContainer.id = 'toast-container';
      toastContainer.style.position = 'fixed';
      toastContainer.style.bottom = '20px';
      toastContainer.style.right = '20px';
      toastContainer.style.zIndex = '9999';
      document.body.appendChild(toastContainer);
    }
    
    // Create toast element
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    
    // Add to container
    toastContainer.appendChild(toast);
    
    // Remove after 3 seconds
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => {
        if (toastContainer.contains(toast)) {
          toastContainer.removeChild(toast);
        }
      }, 300);
    }, 3000);
  }
  
  /**
   * Set the UI state when service is offline
   */
  function setServiceOfflineState() {
    // Display error message
    showErrorMessage('Security service is not responding. Please check if the service is running.');
    
    // Set all status indicators to offline/unknown
    document.querySelectorAll('.summary-status').forEach(element => {
      element.textContent = 'Unknown';
      element.className = 'summary-status error';
    });
  }
  
  /**
   * Show error message in the UI
   */
  function showErrorMessage(message) {
    console.error(message);
    showToast('Error: ' + message);
  }
});

// HARDN Interface JavaScript
document.addEventListener('DOMContentLoaded', function() {
    initializeInterface();
    setupEventListeners();
    simulateNetworkActivity();
});

function initializeInterface() {
    updateSystemStatus();
    updateDateTime();
    setInterval(updateDateTime, 1000);
}

function setupEventListeners() {
    // Toggle sidebar
    const toggleBtn = document.querySelector('.sidebar-toggle');
    if (toggleBtn) {
        toggleBtn.addEventListener('click', function() {
            document.body.classList.toggle('sidebar-collapsed');
        });
    }

    // Command input handling
    const cmdInput = document.querySelector('.command-input');
    if (cmdInput) {
        cmdInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                processCommand(this.value);
                this.value = '';
            }
        });
    }

    // Tab switching
    const tabs = document.querySelectorAll('.tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', function() {
            const tabId = this.getAttribute('data-tab');
            activateTab(tabId);
        });
    });
}

function processCommand(cmd) {
    if (!cmd.trim()) return;
    
    const output = document.querySelector('.terminal-output');
    if (!output) return;
    
    // Log command
    const cmdLine = document.createElement('div');
    cmdLine.className = 'terminal-line user-input';
    cmdLine.innerHTML = `<span class="prompt">></span> ${cmd}`;
    output.appendChild(cmdLine);
    
    // Process command (basic simulation)
    let response;
    const lcCmd = cmd.toLowerCase().trim();
    
    if (lcCmd === 'help') {
        response = `Available commands:
- status: System status
- scan: Network scan
- secure: Enable security protocol
- clear: Clear terminal`;
    } else if (lcCmd === 'status') {
        response = 'System status: OPERATIONAL - Defense systems active';
    } else if (lcCmd === 'scan') {
        response = 'Network scan initiated...';
        setTimeout(() => addTerminalLine('Network scan complete: No threats detected'), 2000);
    } else if (lcCmd === 'secure') {
        response = 'Enhanced security protocol activated';
        document.querySelector('.status-indicator')?.classList.add('secure');
    } else if (lcCmd === 'clear') {
        output.innerHTML = '';
        return;
    } else {
        response = `Command not recognized: "${cmd}"`;
    }
    
    addTerminalLine(response);
    output.scrollTop = output.scrollHeight;
}

function addTerminalLine(text) {
    const output = document.querySelector('.terminal-output');
    if (!output) return;
    
    const line = document.createElement('div');
    line.className = 'terminal-line system-output';
    line.textContent = text;
    output.appendChild(line);
}

function activateTab(tabId) {
    // Hide all panels
    document.querySelectorAll('.panel').forEach(panel => {
        panel.classList.remove('active');
    });
    
    // Deactivate all tabs
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Activate selected tab and panel
    document.querySelector(`.tab[data-tab="${tabId}"]`)?.classList.add('active');
    document.querySelector(`.panel[data-panel="${tabId}"]`)?.classList.add('active');
}

function updateSystemStatus() {
    const statuses = ['NOMINAL', 'SECURE', 'STANDBY', 'SCANNING'];
    const statusIndicators = document.querySelectorAll('.status-indicator');
    
    statusIndicators.forEach(indicator => {
        const randomStatus = statuses[Math.floor(Math.random() * statuses.length)];
        indicator.textContent = randomStatus;
        indicator.className = 'status-indicator';
        indicator.classList.add(randomStatus.toLowerCase());
    });
}

function updateDateTime() {
    const dateDisplay = document.querySelector('.date-time');
    if (!dateDisplay) return;
    
    const now = new Date();
    const formattedDate = now.toISOString().replace('T', ' ').slice(0, 19);
    dateDisplay.textContent = formattedDate;
}

function simulateNetworkActivity() {
    const activityLog = document.querySelector('.activity-log');
    if (!activityLog) return;
    
    const activities = [
        'Perimeter scan complete - No intrusions detected',
        'Encrypted communication channel established',
        'Security protocol ALPHA active',
        'System integrity check: PASSED',
        'Threat database updated',
        'Network traffic analysis running',
        'Remote sensor array online',
        'Defensive countermeasures ready'
    ];
    
    // Initial logs
    for (let i = 0; i < 3; i++) {
        const randomActivity = activities[Math.floor(Math.random() * activities.length)];
        addActivityLog(randomActivity);
    }
    
    // Periodic updates
    setInterval(() => {
        if (Math.random() > 0.7) {
            const randomActivity = activities[Math.floor(Math.random() * activities.length)];
            addActivityLog(randomActivity);
        }
    }, 5000);
}

function addActivityLog(message) {
    const activityLog = document.querySelector('.activity-log');
    if (!activityLog) return;
    
    const now = new Date();
    const timestamp = now.toTimeString().slice(0, 8);
    
    const logEntry = document.createElement('div');
    logEntry.className = 'log-entry';
    logEntry.innerHTML = `<span class="log-time">[${timestamp}]</span> ${message}`;
    
    activityLog.appendChild(logEntry);
    
    // Keep log at a reasonable size
    if (activityLog.children.length > 50) {
        activityLog.removeChild(activityLog.firstChild);
    }
    
    activityLog.scrollTop = activityLog.scrollHeight;
}

/**
 * Initialize all HARDN modules
 */
function initializeHARDNModules() {
  // Listen for section changes to initialize the right modules
  document.addEventListener('sectionLoaded', (e) => {
    const section = e.detail.section;
    
    // Initialize modules based on active section
    switch (section) {
      case 'dashboard':
        if (window.HARDNDashboard) {
          window.HARDNDashboard.init();
        }
        break;
      case 'network':
        if (window.HARDNNetwork) {
          window.HARDNNetwork.init();
        }
        break;
      case 'threats':
        if (window.HARDNThreats) {
          window.HARDNThreats.init();
        }
        break;
      case 'logs':
        if (window.HARDNLogs) {
          window.HARDNLogs.init();
        }
        break;
    }
  });
} 