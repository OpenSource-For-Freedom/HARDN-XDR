/**
 * HARDN Logs Module
 * Handles system log display and management
 */

const HARDNLogs = {
  // Cache TTL in milliseconds (30 seconds)
  CACHE_TTL: 30000,
  
  // Cache for log data
  _cache: {
    logData: null,
    lastUpdate: 0
  },
  
  /**
   * Initialize the logs module
   */
  init() {
    console.log('Initializing HARDN Logs module...');
    
    // Create logs view
    this.createLogsView();
    
    // Fetch and render log data
    this.updateLogData();
    
    // Set up auto-refresh for real-time data
    setInterval(() => this.updateLogData(), 60000);
  },
  
  /**
   * Create the logs view
   */
  createLogsView() {
    const mainContent = document.getElementById('main-content');
    if (!mainContent) return;
    
    mainContent.innerHTML = `
      <div class="logs-header">
        <h1>System Logs</h1>
        <div class="controls">
          <span id="logs-last-updated">Last updated: --:--</span>
          <button id="refresh-logs" class="btn btn-refresh">
            <i class="fas fa-sync-alt"></i>
          </button>
        </div>
      </div>
      
      <div id="logs-content" class="logs-content">
        <div class="loading-indicator">
          <div class="spinner"></div>
          <p>Loading log data...</p>
        </div>
      </div>
    `;
    
    // Add refresh button handler
    document.getElementById('refresh-logs')?.addEventListener('click', () => {
      this.updateLogData(true);
    });
  },
  
  /**
   * Fetch log data from the API
   * @param {boolean} forceRefresh - Whether to bypass cache
   * @returns {Promise<Array>} Log data
   */
  async fetchLogData(forceRefresh = false) {
    // Check cache first
    const now = Date.now();
    if (!forceRefresh && 
        this._cache.logData && 
        (now - this._cache.lastUpdate < this.CACHE_TTL)) {
      return this._cache.logData;
    }
    
    try {
      // Use centralized APIClient
      const data = await window.APIClient.getLogs();
      
      // Update cache
      this._cache.logData = data;
      this._cache.lastUpdate = now;
      
      return data;
    } catch (error) {
      console.error('Error fetching log data:', error);
      return null;
    }
  },
  
  /**
   * Update log data and UI
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateLogData(forceRefresh = false) {
    try {
      const data = await this.fetchLogData(forceRefresh);
      if (data) {
        this.renderLogData(data);
      } else {
        this.showError('Unable to fetch log data');
      }
    } catch (error) {
      console.error('Log update error:', error);
      this.showError('Error updating log data: ' + error.message);
      }
    
    // Update timestamp
    const timestampElement = document.getElementById('logs-last-updated');
    if (timestampElement) {
      const now = new Date();
      timestampElement.textContent = `Last updated: ${now.toLocaleTimeString()}`;
    }
  },
  
  /**
   * Render log data to the UI
   * @param {Object} data - Log data from API
   */
  renderLogData(data) {
    const container = document.getElementById('logs-content');
    if (!container) return;
    
    // Get log entries
    const logs = data.logs || [];
    
    // Build HTML structure
    let html = `
      <div class="data-card">
        <div class="card-header">
          <h3>System Logs</h3>
          <div class="card-actions">
            <button class="btn-text" id="logs-filter"><i class="fas fa-filter"></i> Filter</button>
            <button class="btn-text" id="logs-export"><i class="fas fa-download"></i> Export</button>
          </div>
        </div>
        
        <div class="log-container">
    `;
    
    if (logs.length > 0) {
      logs.forEach(log => {
        // Determine log type/severity
        const logType = log.level || 'info';
        const logClass = logType === 'error' ? 'log-error' : 
                       logType === 'warning' ? 'log-warning' : 'log-info';
    
        // Format timestamp
        const timestamp = log.timestamp ? new Date(log.timestamp).toLocaleString() : '';
        
        html += `
          <div class="log-entry ${logClass}">
            <div class="log-timestamp">${timestamp}</div>
            <div class="log-level">${logType.toUpperCase()}</div>
            <div class="log-message">${log.message}</div>
          </div>
        `;
      });
    } else {
      html += `
        <div class="no-logs-message">
          <i class="fas fa-info-circle"></i>
          <p>No log entries available</p>
        </div>
      `;
    }
    
    html += `
        </div>
        </div>
      
      <div class="action-panel">
        <h3>Log Management</h3>
        <div class="action-buttons">
          <button id="clear-logs" class="btn btn-action">
            <i class="fas fa-trash"></i>
            Clear Logs
          </button>
          <button id="download-logs" class="btn btn-action">
            <i class="fas fa-download"></i>
            Download Logs
          </button>
        </div>
      </div>
    `;
    
    container.innerHTML = html;
    
    // Add event listeners for actions
    document.getElementById('logs-filter')?.addEventListener('click', () => {
      this.showNotImplemented('Filtering logs');
      });
      
    document.getElementById('logs-export')?.addEventListener('click', () => {
      this.exportLogs();
    });
    
    document.getElementById('clear-logs')?.addEventListener('click', () => {
      this.showNotImplemented('Clearing logs');
        });
    
    document.getElementById('download-logs')?.addEventListener('click', () => {
      this.exportLogs();
    });
  },
  
  /**
   * Export logs to a downloadable file
   */
  exportLogs() {
    try {
      const logs = this._cache.logData?.logs || [];
      if (logs.length === 0) {
        this.showToast('No logs available to export', 'warning');
        return;
      }
      
      // Format log entries as text
      let logContent = '';
      logs.forEach(log => {
        const timestamp = log.timestamp || new Date().toISOString();
        const level = log.level?.toUpperCase() || 'INFO';
        const message = log.message || '';
        
        logContent += `[${timestamp}] [${level}] ${message}\n`;
      });
      
      // Create downloadable blob
      const blob = new Blob([logContent], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      
      // Create download link and trigger download
      const a = document.createElement('a');
      a.href = url;
      a.download = `hardn-logs-${new Date().toISOString().slice(0, 10)}.txt`;
      document.body.appendChild(a);
      a.click();
      
      // Clean up
        document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
      
      this.showToast('Logs exported successfully', 'success');
    } catch (error) {
      console.error('Error exporting logs:', error);
      this.showToast('Error exporting logs', 'error');
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
    const container = document.getElementById('logs-content');
    if (!container) return;
    
    container.innerHTML = `
      <div class="error-message">
        <i class="fas fa-exclamation-circle"></i>
        <h3>Logs Error</h3>
        <p>${message}</p>
        <button id="retry-logs" class="btn btn-action">
          <i class="fas fa-sync-alt"></i> Retry
        </button>
      </div>
    `;
    
    document.getElementById('retry-logs')?.addEventListener('click', () => {
      this.updateLogData(true);
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
window.HARDNLogs = HARDNLogs; 