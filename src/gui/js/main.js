/**
 * HARDN Main Application
 * Handles UI navigation and component initialization
 */

// Define API URL for backend communication
const API_URL = 'http://localhost:8080/api';

// Use this to store authentication tokens
let authTokens = {
  accessToken: null,
  refreshToken: null,
  expiresAt: null
};

// Current active section
let currentSection = 'dashboard';

// Global WebSocket connections
let securityWs = null;
let networkWs = null;
let logsWs = null;

// Determine API URL
// If the page is hosted on a different domain, it will connect to the hostname with port 8080
// Otherwise use localhost:8080
function getApiUrl() {
  return 'http://localhost:8080/api';
}

// Get WebSocket URL
function getWebSocketUrl() {
  return 'ws://localhost:8080/ws';
}

/**
 * Initialize a WebSocket connection with retry capability
 * @param {string} dataType - Type of data to receive (network, security, logs)
 * @param {function} callback - Function to call with received data
 * @returns {WebSocket} WebSocket connection
 */
function connectWebSocket(dataType, callback) {
  const wsUrl = `${getWebSocketUrl()}/${dataType}`;
  console.log(`Connecting to WebSocket: ${wsUrl}`);
  
  let ws = new WebSocket(wsUrl);
  
  // Setup event handlers
  ws.onopen = () => {
    console.log(`WebSocket connection established for ${dataType}`);
  };
  
  ws.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      callback(data);
    } catch (error) {
      console.error(`Error parsing WebSocket data for ${dataType}:`, error);
    }
  };
  
  ws.onerror = (error) => {
    console.error(`WebSocket error for ${dataType}:`, error);
  };
  
  ws.onclose = (event) => {
    console.log(`WebSocket closed for ${dataType}:`, event.code, event.reason);
    
    // Auto-reconnect unless clean close
    if (event.code !== 1000) {
      console.log(`Reconnecting ${dataType} WebSocket in 5 seconds...`);
      setTimeout(() => {
        connectWebSocket(dataType, callback);
      }, 5000);
    }
  };
  
  return ws;
}

/**
 * Initialize WebSocket connections
 */
function initializeWebSockets() {
  // Initialize security data WebSocket
  securityWs = connectWebSocket('security', (data) => {
    console.log('Security WebSocket data received:', data);
    updateSecurityUI(data);
  });
  
  // Initialize network data WebSocket
  networkWs = connectWebSocket('network', (data) => {
    console.log('Network WebSocket data received:', data);
    updateNetworkUI(data);
  });
  
  // Initialize logs WebSocket
  logsWs = connectWebSocket('logs', (data) => {
    console.log('Logs WebSocket data received:', data);
    updateLogsUI(data);
  });
}

// Document ready function
document.addEventListener('DOMContentLoaded', function() {
  // Initialize authentication by checking for existing tokens
  loadTokens();
  
  // Set up navigation based on authentication status
  setupNavigation();
  
  // Set up status bar in footer
        setupStatusBar();
  
  // Check if we have valid authentication
  ensureValidToken().then(isValid => {
    if (isValid) {
      // User is authenticated
      afterSuccessfulLogin();
      } else {
      // Show login form
      showLoginForm();
    }
  }).catch(error => {
    console.error('Error checking token validity:', error);
    // Show login form on error
    showLoginForm();
  });
  
  // For demo/development, automatically "login" without validation
  const afterSuccessfulLogin = () => {
    // Hide login form if visible
    const loginForm = document.getElementById('login-form');
    if (loginForm) {
      loginForm.classList.add('hidden');
    }
    
    // Show main content
    const mainContent = document.getElementById('main-content');
    if (mainContent) {
      mainContent.classList.remove('hidden');
    }
    
    // Load default section (dashboard)
    loadSection('dashboard');
    
    // Initialize WebSockets for real-time data
    // Uncomment when backend WebSockets are ready
    // initializeWebSockets();
  };
  
  // Check if WebSocket is supported
  if (typeof WebSocket === 'undefined') {
    console.warn('WebSocket is not supported in this browser. Real-time updates disabled.');
  }
  
  // For now, auto-login for development
  afterSuccessfulLogin();
});

/**
 * Store auth tokens in localStorage
 * @param {Object} tokens - Auth tokens
 */
function saveTokens(tokens) {
  if (!tokens) return;
  
  // Store tokens in memory
  authTokens = {
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresAt: tokens.expiresAt
  };
  
  // Store in localStorage for persistence
  localStorage.setItem('auth_tokens', JSON.stringify(authTokens));
}

/**
 * Load auth tokens from localStorage
 */
function loadTokens() {
  const storedTokens = localStorage.getItem('auth_tokens');
  if (storedTokens) {
    try {
      authTokens = JSON.parse(storedTokens);
    } catch (error) {
      console.error('Error parsing stored tokens:', error);
      clearTokens();
    }
  }
}

/**
 * Clear auth tokens
 */
function clearTokens() {
  authTokens = {
    accessToken: null,
    refreshToken: null,
    expiresAt: null
  };
  localStorage.removeItem('auth_tokens');
}

/**
 * Refresh the authentication token
 * @param {string} refreshToken - Token to use for refresh
 * @returns {Promise<Object>} New auth tokens
 */
async function refreshAuthToken(refreshToken) {
  try {
    const response = await fetch(`${API_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken })
    });
    
    if (!response.ok) {
      throw new Error(`Token refresh failed: ${response.status}`);
    }
    
    const tokens = await response.json();
    saveTokens(tokens);
    return tokens;
  } catch (error) {
    console.error('Error refreshing token:', error);
    clearTokens();
    throw error;
  }
}

/**
 * Ensure we have a valid auth token
 * @returns {Promise<boolean>} Whether we have a valid token
 */
async function ensureValidToken() {
  // If we have no tokens, we need to authenticate
  if (!authTokens || !authTokens.accessToken) {
    return false;
  }
  
  // If token is expired, try to refresh
  if (authTokens.expiresAt && new Date(authTokens.expiresAt) < new Date()) {
    if (authTokens.refreshToken) {
      try {
        await refreshAuthToken(authTokens.refreshToken);
        return true;
      } catch (error) {
        return false;
      }
    }
    return false;
  }
  
  // Token is valid
  return true;
}

/**
 * Set up main navigation
 */
function setupNavigation() {
  // Add click handlers for main navigation items
  document.getElementById('nav-dashboard')?.addEventListener('click', () => loadSection('dashboard'));
  document.getElementById('nav-network')?.addEventListener('click', () => loadSection('network'));
  document.getElementById('nav-threats')?.addEventListener('click', () => loadSection('threats'));
  document.getElementById('nav-logs')?.addEventListener('click', () => loadSection('logs'));
  document.getElementById('nav-setup')?.addEventListener('click', () => loadSection('setup'));
  document.getElementById('nav-tools')?.addEventListener('click', () => loadSection('security-tools'));
  
  // Set default/current section in UI
  loadSection(currentSection);
}

/**
 * Load a specific section of the GUI
 * @param {string} section - Section name (dashboard, network, threats, logs, setup)
 */
function loadSection(section) {
  console.log(`Loading section: ${section}`);
  currentSection = section;
  
  // Update nav highlighting
  document.querySelectorAll('.nav-item').forEach(item => {
    item.classList.remove('active');
  });
  
  // Map section names to nav IDs
  const navMap = {
    'dashboard': 'nav-dashboard',
    'network': 'nav-network',
    'threats': 'nav-threats',
    'logs': 'nav-logs',
    'setup': 'nav-setup',
    'security-tools': 'nav-tools'
  };
  
  const navId = navMap[section];
  if (navId) {
    document.getElementById(navId)?.classList.add('active');
  }
  
  // Clear main content
  const mainContent = document.getElementById('main-content');
  if (!mainContent) {
    console.error('Main content element not found');
    return;
  }
  
  mainContent.innerHTML = '<div class="loading">Loading...</div>';
  
  // Update footer status
  updateFooterStatus(`Loading ${section}...`);
  
  // Load content based on section
  switch (section) {
    case 'dashboard':
      loadDashboard(mainContent);
      break;
    case 'network':
      loadNetworkSection(mainContent);
      break;
    case 'threats':
      loadThreatsSection(mainContent);
      break;
    case 'logs':
      loadLogsSection(mainContent);
      break;
    case 'setup':
      loadSetupSection(mainContent);
      break;
    case 'security-tools':
      loadSecurityToolsSection(mainContent);
      break;
    default:
      mainContent.innerHTML = '<div class="error">Unknown section</div>';
      updateFooterStatus('Error: Unknown section');
  }
}

/**
 * Load the security tools section
 * @param {HTMLElement} container - Container to load content into
 */
function loadSecurityToolsSection(container) {
  // Redirect to the security tools page
  window.location.href = 'security-tools.html';
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

// Use centralized API client for backend checking
async function checkBackendAvailable() {
  if (window.APIClient && window.APIClient.checkBackendAvailable) {
    return await window.APIClient.checkBackendAvailable();
  } else {
    // Fallback implementation
    console.log(`Fallback: Checking backend availability at: ${API_URL}/check_backend`);
    
    try {
      // Use a timeout to avoid hanging if the server is down
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3000); // 3 second timeout
      
      const response = await fetch(`${API_URL}/check_backend`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      console.log('Backend check response:', response.status, response.ok);
      
      if (response.ok) {
        return true;
      }
      
    return false;
  } catch (error) {
      console.warn('Backend check failed:', error.name === 'AbortError' ? 'Request timed out' : error.message);
    return false;
    }
  }
}

// Global helper to format timestamps
function formatTime(timestamp) {
  if (!timestamp) return '';
  
  const date = new Date(timestamp);
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const seconds = date.getSeconds().toString().padStart(2, '0');
  
  return `${hours}:${minutes}:${seconds}`;
}

// Global helper to format dates
function formatDate(timestamp) {
  if (!timestamp) return '';
  
  const date = new Date(timestamp);
  const day = date.getDate().toString().padStart(2, '0');
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const year = date.getFullYear();
  
  return `${year}-${month}-${day}`;
}

// Add a custom event for section loading complete
const sectionLoadedEvent = new CustomEvent('sectionLoaded', {
  bubbles: true,
  detail: { section: 'dashboard' }
});

// Initialize dashboard when loaded
function initializeDashboard() {
  console.log('Initializing dashboard');
  
  // Initial data load from direct API endpoints
  fetchDirectData();
  
  // Set up periodic refresh
  setInterval(fetchDirectData, 10000); // Refresh every 10 seconds
  
  // Try to initialize WebSockets as well
  try {
    initializeWebSockets();
  } catch (e) {
    console.warn('WebSocket initialization failed, falling back to REST API:', e);
  }
}
  
// Fetch data from direct API endpoints
async function fetchDirectData() {
  console.log('Fetching direct data from backend API');
  
  try {
    // Fetch network data
    try {
      const networkResponse = await fetch(`${API_URL}/direct/network`);
      if (networkResponse.ok) {
        const networkData = await networkResponse.json();
        console.log('Network data received:', networkData);
        updateNetworkUI(networkData);
      }
    } catch (e) {
      console.error('Failed to fetch network data:', e);
    }
    
    // Fetch security data
    try {
      const securityResponse = await fetch(`${API_URL}/direct/security`);
      if (securityResponse.ok) {
        const securityData = await securityResponse.json();
        console.log('Security data received:', securityData);
        updateSecurityUI(securityData);
      }
    } catch (e) {
      console.error('Failed to fetch security data:', e);
    }
    
    // Fetch logs data
    try {
      const logsResponse = await fetch(`${API_URL}/direct/logs`);
      if (logsResponse.ok) {
        const logsData = await logsResponse.json();
        console.log('Logs data received:', logsData);
        updateLogsUI(logsData);
      }
    } catch (e) {
      console.error('Failed to fetch logs data:', e);
    }
    
    // Update last updated time
  const lastUpdatedTime = document.getElementById('last-updated-time');
    if (lastUpdatedTime) {
      const now = new Date();
      lastUpdatedTime.textContent = now.toLocaleTimeString();
    }
    
    } catch (error) {
    console.error('Error fetching direct data:', error);
  }
}

// Update network UI with data
function updateNetworkUI(data) {
  const networkStatus = document.getElementById('network-status');
  if (networkStatus && data.connections) {
    networkStatus.textContent = `${data.connections.length} active connections`;
    networkStatus.classList.remove('loading');
    networkStatus.classList.add('status-ok');
  }
}

// Update security UI with data
function updateSecurityUI(data) {
  const systemSecurity = document.getElementById('system-security-status');
  if (systemSecurity && data.components) {
    const componentsStatus = Object.values(data.components);
    const allOk = componentsStatus.every(c => c.status === 'ok');
    
    systemSecurity.textContent = allOk ? 'All systems secure' : 'Security warnings detected';
    systemSecurity.classList.remove('loading');
    systemSecurity.classList.add(allOk ? 'status-ok' : 'status-warning');
    
    // Update components list if available
    const componentsList = document.getElementById('security-components-list');
    if (componentsList) {
      componentsList.innerHTML = '';
      Object.entries(data.components).forEach(([name, info]) => {
    const li = document.createElement('li');
        li.className = `component-item status-${info.status}`;
        li.innerHTML = `
          <span class="component-name">${name}</span>
          <span class="component-status">${info.message}</span>
        `;
        componentsList.appendChild(li);
      });
    }
  }
}

// Update logs UI with data
function updateLogsUI(data) {
  const activityLog = document.getElementById('activity-log');
  if (activityLog && data.logs) {
    activityLog.innerHTML = '';
    data.logs.slice(0, 10).forEach(log => {
      const li = document.createElement('li');
      li.className = `activity-item level-${log.level}`;
      li.innerHTML = `
        <span class="activity-time">${formatTime(new Date(log.timestamp))}</span>
        <span class="activity-message">${log.message}</span>
      `;
      activityLog.appendChild(li);
    });
    
    // Update threat level based on log severity
    const threatLevel = document.getElementById('threat-level-status');
    if (threatLevel) {
      const hasErrors = data.logs.some(log => log.level === 'error');
      const hasWarnings = data.logs.some(log => log.level === 'warning');
      
      let status = 'low';
      if (hasErrors) status = 'high';
      else if (hasWarnings) status = 'medium';
      
      threatLevel.textContent = status.charAt(0).toUpperCase() + status.slice(1);
      threatLevel.classList.remove('loading');
      threatLevel.className = `summary-status status-${status}`;
    }
  }
}

// HARDN Interface JavaScript
document.addEventListener('DOMContentLoaded', function() {
    initializeInterface();
    setupEventListeners();
});

function initializeInterface() {
    updateSystemStatus();
    updateDateTime();
    setInterval(updateDateTime, 1000);
  
  // Load dashboard section by default
  loadSection('dashboard');
}

function setupEventListeners() {
  // Set up quick access buttons
  document.querySelectorAll('.action-button').forEach(button => {
    button.addEventListener('click', function() {
      const action = this.getAttribute('data-action');
      if (action) {
        processCommand(action);
      }
    });
  });
  
  // Monitor backend connectivity
  setInterval(function() {
    checkBackendAvailable().then(available => {
      const statusIndicator = document.querySelector('.system-status');
      if (statusIndicator) {
        if (available) {
          statusIndicator.textContent = 'System Active';
          statusIndicator.classList.remove('offline');
    } else {
          statusIndicator.textContent = 'Offline';
          statusIndicator.classList.add('offline');
        }
      }
    });
  }, 30000);
}

function updateSystemStatus() {
  const statusIndicator = document.querySelector('.system-status');
  if (statusIndicator) {
    statusIndicator.textContent = 'System Active';
  }
}

function updateDateTime() {
  // Update date/time display if needed
}