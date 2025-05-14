/**
 * HARDN Network Module
 * Handles network monitoring and connection visualization
 */

const HARDNNetwork = {
  // Cache TTL in milliseconds (30 seconds)
  CACHE_TTL: 30000,
  
  // Cache for network data
  _cache: {
    networkData: null,
    lastUpdate: 0
  },
  
  /**
   * Initialize the network module
   */
  init() {
    console.log('Initializing HARDN Network module...');
    
    // Create network view
    this.createNetworkView();
    
    // Fetch and render network data
    this.updateNetworkData();
    
    // Set up auto-refresh for real-time data
    setInterval(() => this.updateNetworkData(), 30000);
  },
  
  /**
   * Create the network view
   */
  createNetworkView() {
    const mainContent = document.getElementById('main-content');
    if (!mainContent) return;
    
    mainContent.innerHTML = `
      <div class="network-header">
        <h1>Network Connections</h1>
        <div class="controls">
          <span id="network-last-updated">Last updated: --:--</span>
          <button id="refresh-network" class="btn btn-refresh">
            <i class="fas fa-sync-alt"></i>
          </button>
        </div>
      </div>
      
      <div id="network-content" class="network-content">
        <div class="loading-indicator">
          <div class="spinner"></div>
          <p>Loading network data...</p>
        </div>
      </div>
    `;
    
    // Add refresh button handler
    document.getElementById('refresh-network')?.addEventListener('click', () => {
      this.updateNetworkData(true);
    });
  },
  
  /**
   * Fetch network data from the API
   * @param {boolean} forceRefresh - Whether to bypass cache
   * @returns {Promise<Array>} Network connection data
   */
  async fetchNetworkData(forceRefresh = false) {
    // Check cache first
    const now = Date.now();
    if (!forceRefresh && 
        this._cache.networkData && 
        (now - this._cache.lastUpdate < this.CACHE_TTL)) {
      return this._cache.networkData;
    }
    
    try {
      // Use centralized APIClient
      const data = await window.APIClient.getNetworkStatus();
      
      // Update cache
      this._cache.networkData = data;
      this._cache.lastUpdate = now;
      
      return data;
    } catch (error) {
      console.error('Error fetching network data:', error);
      return null;
    }
  },
  
  /**
   * Update network data and UI
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateNetworkData(forceRefresh = false) {
    try {
      const data = await this.fetchNetworkData(forceRefresh);
      if (data) {
        this.renderNetworkData(data);
      } else {
        this.showError('Unable to fetch network data');
      }
    } catch (error) {
      console.error('Network update error:', error);
      this.showError('Error updating network data: ' + error.message);
      }
    
    // Update timestamp
    const timestampElement = document.getElementById('network-last-updated');
    if (timestampElement) {
      const now = new Date();
      timestampElement.textContent = `Last updated: ${now.toLocaleTimeString()}`;
    }
  },
  
  /**
   * Render network data to the UI
   * @param {Object} data - Network data from API
   */
  renderNetworkData(data) {
    const container = document.getElementById('network-content');
    if (!container) return;
    
    // Check if we have connections data
    const connections = data.connections || [];
    
    // Build HTML structure
    let html = `
      <div class="network-overview">
        <div class="status-card ${data.status || 'warning'}">
          <h3>Network Status</h3>
          <div class="status-value">${data.status === 'ok' ? 'Secure' : 'Warning'}</div>
          <div class="status-message">${data.message || 'No status message available'}</div>
        </div>
        
        <div class="connection-stats">
          <div class="stat-item">
            <span class="stat-value">${connections.length}</span>
            <span class="stat-label">Active Connections</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">0</span>
            <span class="stat-label">Blocked Threats</span>
          </div>
        </div>
      </div>
      
      <div class="data-card">
        <div class="card-header">
          <h3>Active Connections</h3>
          <div class="card-actions">
            <button class="btn-text" id="network-filter"><i class="fas fa-filter"></i> Filter</button>
            <button class="btn-text" id="network-export"><i class="fas fa-download"></i> Export</button>
          </div>
        </div>
        
        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>IP Address</th>
                <th>Port</th>
                <th>Type</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
    `;
    
    if (connections.length > 0) {
      connections.forEach(conn => {
        html += `
          <tr>
            <td>${conn.ip}</td>
            <td>${conn.port}</td>
            <td>${conn.type || 'unknown'}</td>
            <td><span class="badge ${conn.status === 'established' ? 'success' : 'warning'}">${conn.status || 'unknown'}</span></td>
            <td>
              <button class="btn-icon small" title="Connection Details"><i class="fas fa-info-circle"></i></button>
              <button class="btn-icon small" title="Block Connection"><i class="fas fa-ban"></i></button>
            </td>
          </tr>
        `;
      });
    } else {
      html += `
        <tr>
          <td colspan="5" class="text-center">No active connections found</td>
        </tr>
      `;
    }
    
    html += `
            </tbody>
          </table>
        </div>
      </div>
    `;
    
    container.innerHTML = html;
    
    // Add event listeners for the action buttons
    document.getElementById('network-filter')?.addEventListener('click', () => {
      this.showNotImplemented('Filtering connections');
    });
    
    document.getElementById('network-export')?.addEventListener('click', () => {
      this.showNotImplemented('Exporting connections');
    });
  },
  
  /**
   * Show an error message
   * @param {string} message - Error message
   */
  showError(message) {
    const container = document.getElementById('network-content');
    if (!container) return;
    
    container.innerHTML = `
      <div class="error-message">
        <i class="fas fa-exclamation-circle"></i>
        <h3>Network Error</h3>
        <p>${message}</p>
        <button id="retry-network" class="btn btn-action">
          <i class="fas fa-sync-alt"></i> Retry
        </button>
      </div>
    `;
    
    document.getElementById('retry-network')?.addEventListener('click', () => {
      this.updateNetworkData(true);
    });
  },
  
  /**
   * Show a "not implemented" toast for incomplete features
   * @param {string} feature - Feature name
   */
  showNotImplemented(feature) {
    // Use global toast if available
    if (typeof showToast === 'function') {
      showToast(`${feature} is not implemented in this version`, 'info');
    } else {
      console.log(`${feature} is not implemented in this version`);
        }
  }
};

// Export to window for access by main.js
window.HARDNNetwork = HARDNNetwork; 