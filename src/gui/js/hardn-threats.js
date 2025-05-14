/**
 * HARDN Threats Module
 * Handles threat detection and mitigation
 */

const HARDNThreats = {
  // Cache TTL in milliseconds (30 seconds)
  CACHE_TTL: 30000,
  
  // Cache for threat data
  _cache: {
    threatData: null,
    lastUpdate: 0
  },
  
  /**
   * Initialize the threats module
   */
  init() {
    console.log('Initializing HARDN Threats module...');
    
    // Create threats view
    this.createThreatsView();
    
    // Fetch and render threat data
    this.updateThreatData();
    
    // Set up auto-refresh for real-time data
    setInterval(() => this.updateThreatData(), 60000);
  },
  
  /**
   * Create the threats view
   */
  createThreatsView() {
    const mainContent = document.getElementById('main-content');
    if (!mainContent) return;
    
    mainContent.innerHTML = `
      <div class="threats-header">
        <h1>Threat Analysis</h1>
        <div class="controls">
          <span id="threats-last-updated">Last updated: --:--</span>
          <button id="refresh-threats" class="btn btn-refresh">
            <i class="fas fa-sync-alt"></i>
          </button>
        </div>
      </div>
      
      <div id="threats-content" class="threats-content">
        <div class="loading-indicator">
          <div class="spinner"></div>
          <p>Loading threat data...</p>
        </div>
      </div>
    `;
    
    // Add refresh button handler
    document.getElementById('refresh-threats')?.addEventListener('click', () => {
      this.updateThreatData(true);
    });
  },
  
  /**
   * Fetch threat data from the API
   * @param {boolean} forceRefresh - Whether to bypass cache
   * @returns {Promise<Object>} Threat data
   */
  async fetchThreatData(forceRefresh = false) {
    // Check cache first
    const now = Date.now();
    if (!forceRefresh && 
        this._cache.threatData && 
        (now - this._cache.lastUpdate < this.CACHE_TTL)) {
      return this._cache.threatData;
    }
    
    try {
      // Use centralized APIClient
      const data = await window.APIClient.getThreats();
      
      // Update cache
      this._cache.threatData = data;
      this._cache.lastUpdate = now;
      
      return data;
    } catch (error) {
      console.error('Error fetching threat data:', error);
      return null;
    }
  },
  
  /**
   * Update threat data and UI
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateThreatData(forceRefresh = false) {
    try {
      const data = await this.fetchThreatData(forceRefresh);
      if (data) {
        this.renderThreatData(data);
      } else {
        this.showError('Unable to fetch threat data');
      }
    } catch (error) {
      console.error('Threat update error:', error);
      this.showError('Error updating threat data: ' + error.message);
    }
    
    // Update timestamp
    const timestampElement = document.getElementById('threats-last-updated');
    if (timestampElement) {
      const now = new Date();
      timestampElement.textContent = `Last updated: ${now.toLocaleTimeString()}`;
    }
  },
  
  /**
   * Render threat data to the UI
   * @param {Object} data - Threat data from API
   */
  renderThreatData(data) {
    const container = document.getElementById('threats-content');
    if (!container) return;
    
    // Get threat level class
    const threatLevel = data.level || 0;
    const threatLevelClass = threatLevel >= 3 ? 'error' : 
                             threatLevel >= 1 ? 'warning' : 'ok';
    const threatLevelText = threatLevel >= 3 ? 'High' : 
                           threatLevel >= 1 ? 'Medium' : 'Low';
    
    // Build HTML structure
    let html = `
      <div class="threats-overview">
        <div class="status-card ${threatLevelClass}">
          <h3>Current Threat Level</h3>
          <div class="status-value">${threatLevelText}</div>
          <div class="status-message">${data.status || 'No status available'}</div>
        </div>
        
        <div class="threat-stats">
          <div class="stat-item">
            <span class="stat-value">${data.active_threats || 0}</span>
            <span class="stat-label">Active Threats</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">${data.last_update ? new Date(data.last_update).toLocaleDateString() : 'Unknown'}</span>
            <span class="stat-label">Last Database Update</span>
          </div>
        </div>
      </div>
    `;
    
    // Add threat items section if we have threats
    if (data.items && data.items.length > 0) {
      html += `
        <div class="data-card">
          <div class="card-header">
            <h3>Detected Threats</h3>
            <div class="card-actions">
              <button class="btn-text" id="threats-mitigate-all"><i class="fas fa-shield-alt"></i> Mitigate All</button>
              <button class="btn-text" id="threats-export"><i class="fas fa-download"></i> Export</button>
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
      `;
    
      // Add each threat item
    data.items.forEach(threat => {
        const levelClass = threat.level >= 3 ? 'high' : 
                         threat.level >= 2 ? 'medium' : 'low';
      
        html += `
          <tr>
        <td><span class="threat-level ${levelClass}">${threat.level}</span></td>
        <td>${threat.description}</td>
        <td>
          <button class="btn-icon small" title="Mitigate Threat"><i class="fas fa-shield-alt"></i></button>
          <button class="btn-icon small" title="Dismiss Threat"><i class="fas fa-times"></i></button>
        </td>
          </tr>
      `;
      });
      
      html += `
              </tbody>
            </table>
          </div>
        </div>
      `;
    } else {
      // No threats detected
      html += `
        <div class="data-card">
          <div class="card-header">
            <h3>Detected Threats</h3>
          </div>
          <div class="no-threats-message">
            <i class="fas fa-check-circle"></i>
            <p>No active threats detected</p>
            <p class="secondary">Your system is currently secure</p>
          </div>
        </div>
      `;
    }
    
    // Add threat scan section
    html += `
      <div class="action-panel">
        <h3>Threat Management</h3>
        <div class="action-buttons">
          <button id="run-threat-scan" class="btn btn-action">
            <i class="fas fa-search"></i>
            Run Threat Scan
          </button>
          <button id="update-threat-db" class="btn btn-action">
            <i class="fas fa-database"></i>
            Update Threat Database
          </button>
        </div>
      </div>
    `;
    
    container.innerHTML = html;
    
    // Add event listeners for actions
    document.getElementById('threats-mitigate-all')?.addEventListener('click', () => {
      this.showNotImplemented('Mitigate all threats');
    });
    
    document.getElementById('threats-export')?.addEventListener('click', () => {
      this.showNotImplemented('Export threats report');
    });
    
    document.getElementById('run-threat-scan')?.addEventListener('click', () => {
      this.runThreatScan();
    });
    
    document.getElementById('update-threat-db')?.addEventListener('click', () => {
      this.updateThreatDatabase();
    });
  },
  
  /**
   * Run a threat scan
   */
  async runThreatScan() {
    try {
      this.showToast('Starting threat scan...');
      
      // Use the API client to run a security scan
      const result = await window.APIClient.runSecurityScan({
        scan_type: 'threat',
        depth: 2
      });
      
      if (result.success) {
        this.showToast('Threat scan completed successfully');
        // Refresh data to show new results
        this.updateThreatData(true);
      } else {
        this.showToast('Threat scan failed: ' + (result.message || 'Unknown error'), 'error');
      }
    } catch (error) {
      console.error('Error running threat scan:', error);
      this.showToast('Error running threat scan', 'error');
    }
  },
  
  /**
   * Update the threat database
   */
  async updateThreatDatabase() {
    try {
      this.showToast('Updating threat database...');
      
      // Use the API client to update the threat database
      const result = await window.APIClient.updateThreatDatabase();
      
      if (result.success) {
        this.showToast('Threat database updated successfully');
        // Refresh data
        this.updateThreatData(true);
      } else {
        this.showToast(result.message || 'Threat database update failed', 'warning');
      }
    } catch (error) {
      console.error('Error updating threat database:', error);
      this.showToast('Error updating threat database', 'error');
    }
  },
  
  /**
   * Show a toast notification
   * @param {string} message - Message to display
   * @param {string} type - Notification type (info, success, warning, error)
   */
  showToast(message, type = 'info') {
    // Use global toast if available
    if (typeof window.showToast === 'function') {
      window.showToast(message, type);
    } else {
      // Simple console fallback
      console.log(`[${type.toUpperCase()}] ${message}`);
      
      // Create a simple toast if no global function
      const toast = document.createElement('div');
      toast.className = `toast toast-${type}`;
      toast.textContent = message;
      
      document.body.appendChild(toast);
      
      // Remove after 3 seconds
      setTimeout(() => {
        toast.classList.add('fade-out');
        setTimeout(() => {
          if (document.body.contains(toast)) {
            document.body.removeChild(toast);
          }
        }, 300);
      }, 3000);
    }
  },
  
  /**
   * Show an error message
   * @param {string} message - Error message
   */
  showError(message) {
    const container = document.getElementById('threats-content');
    if (!container) return;
    
    container.innerHTML = `
      <div class="error-message">
        <i class="fas fa-exclamation-circle"></i>
        <h3>Threat Analysis Error</h3>
        <p>${message}</p>
        <button id="retry-threats" class="btn btn-action">
          <i class="fas fa-sync-alt"></i> Retry
        </button>
      </div>
    `;
    
    document.getElementById('retry-threats')?.addEventListener('click', () => {
      this.updateThreatData(true);
    });
  },
  
  /**
   * Show a "not implemented" toast for incomplete features
   * @param {string} feature - Feature name
   */
  showNotImplemented(feature) {
    this.showToast(`${feature} is not implemented in this version`, 'info');
  }
};

// Export to window for access by main.js
window.HARDNThreats = HARDNThreats; 