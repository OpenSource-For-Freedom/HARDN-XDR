/**
 * HARDN Dashboard Module
 * Displays the system dashboard with real-time security information
 */

// Dashboard component
const HARDNDashboard = {
  // Cache TTL in milliseconds (30 seconds)
  CACHE_TTL: 30000,
  
  // Cache for dashboard data
  _cache: {
    systemStatus: null,
    securityStatus: null,
    threatData: null,
    activityLog: null,
    lastUpdate: {
      systemStatus: 0,
      securityStatus: 0,
      threatData: 0,
      activityLog: 0
    }
  },
  
  /**
   * Initialize the dashboard with real data
   */
  init() {
    console.log('Initializing HARDN Dashboard...');
    
    // Create dashboard layout
    this.createDashboardLayout();
    
    // Update dashboard with real data immediately
    this.updateDashboard();
    
    // Set up refresh button listener
    document.getElementById('dashboard-refresh')?.addEventListener('click', () => {
      this.updateDashboard(true);
    });
    
    // Set up auto-refresh (every 60 seconds)
    setInterval(() => this.updateDashboard(), 60000);
  },
  
  /**
   * Create the dashboard layout
   */
  createDashboardLayout() {
    const content = document.getElementById('main-content');
    if (!content) return;
    
    content.innerHTML = `
      <div class="dashboard-header">
        <h1>Security Dashboard</h1>
        <div class="dashboard-controls">
          <span id="last-updated">Last updated: --:--</span>
          <button id="dashboard-refresh" class="btn btn-refresh">
            <i class="fas fa-sync-alt"></i>
          </button>
        </div>
      </div>
      
      <div class="dashboard-sections">
        <section class="dashboard-section status-summary">
          <h2>System Security</h2>
          <div id="system-security-status" class="summary-status loading">Loading...</div>
        </section>
        
        <section class="dashboard-section status-summary">
          <h2>Network Status</h2>
          <div id="network-status" class="summary-status loading">Loading...</div>
        </section>
        
        <section class="dashboard-section status-summary">
          <h2>Threat Level</h2>
          <div id="threat-level-status" class="summary-status loading">Loading...</div>
        </section>
        
        <section class="dashboard-section security-components">
          <h2>Security Components</h2>
          <ul id="security-components-list" class="component-list">
            <li class="loading-placeholder">Loading components...</li>
          </ul>
        </section>
        
        <section class="dashboard-section quick-actions">
          <h2>Quick Actions</h2>
          <div class="action-buttons">
            <button id="run-scan-button" class="btn btn-action">
              <i class="fas fa-search"></i>
              Run Security Scan
            </button>
            <button id="update-db-button" class="btn btn-action">
              <i class="fas fa-database"></i>
              Update Threat DB
            </button>
            <button id="network-analysis-button" class="btn btn-action">
              <i class="fas fa-network-wired"></i>
              Network Analysis
            </button>
            <button id="view-report-button" class="btn btn-action">
              <i class="fas fa-file-alt"></i>
              View Full Report
            </button>
          </div>
        </section>
        
        <section class="dashboard-section recent-activity">
          <h2>Recent Activity</h2>
          <ul id="activity-log" class="activity-list">
            <li class="loading-placeholder">Loading activity log...</li>
          </ul>
        </section>
      </div>
    `;
    
    // Set up quick action button listeners
    document.getElementById('run-scan-button')?.addEventListener('click', () => this.runSecurityScan());
    document.getElementById('update-db-button')?.addEventListener('click', () => this.updateThreatDatabase());
    document.getElementById('network-analysis-button')?.addEventListener('click', () => this.runNetworkAnalysis());
    document.getElementById('view-report-button')?.addEventListener('click', () => this.viewFullReport());
  },
  
  /**
   * Update the entire dashboard with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateDashboard(forceRefresh = false) {
    try {
      console.log('Updating dashboard, forceRefresh:', forceRefresh);
      
      // Add a loading indicator
      const content = document.getElementById('main-content');
      if (content) {
        const loadingIndicator = document.createElement('div');
        loadingIndicator.id = 'dashboard-loading';
        loadingIndicator.className = 'loading-indicator';
        loadingIndicator.innerHTML = '<div class="spinner"></div><p>Loading dashboard data...</p>';
        content.prepend(loadingIndicator);
      }
      
      // Check if API is available with multiple retries
      console.log('Checking backend availability...');
      let isAvailable = false;
      for (let i = 0; i < 3; i++) {
        console.log(`Backend check attempt ${i+1}/3`);
        if (window.APIClient) {
          isAvailable = await window.APIClient.checkBackendAvailable();
        } else {
          console.error('APIClient not available - waiting for initialization');
          await new Promise(resolve => setTimeout(resolve, 1000));
          continue;
        }
        console.log('Backend available:', isAvailable);
        if (isAvailable) break;
        // Wait a moment before retry
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
      
      // Remove loading indicator
      document.getElementById('dashboard-loading')?.remove();
      
      if (!isAvailable) {
        console.warn('Backend connection unavailable after multiple attempts, using fallback data');
        this.useOfflineMode();
        return;
      }
      
      console.log('Updating all dashboard sections...');
      
      // Use direct data endpoints instead of WebSockets
      await Promise.all([
        this.fetchDirectNetworkData(),
        this.fetchDirectSecurityData(),
        this.fetchDirectLogsData()
      ]);
      
      // Update last updated timestamp
      this.updateLastUpdatedTime();
      console.log('Dashboard update complete');
    } catch (error) {
      console.error('Error updating dashboard:', error);
      // Remove loading indicator if it exists
      document.getElementById('dashboard-loading')?.remove();
      showToast('Error updating dashboard, using fallback data', 'warning');
      this.useOfflineMode();
    }
  },
  
  /**
   * Use offline mode with simulated data
   */
  useOfflineMode() {
    // Provide fallback/demo data for offline mode
    const fallbackData = this.getFallbackData();
    
    // Update UI with fallback data
    this.updateSystemStatusUI(fallbackData.systemStatus);
    this.updateNetworkStatusUI(fallbackData.networkStatus);
    this.updateThreatLevelUI(fallbackData.threatLevel);
    this.updateSecurityComponentsUI(fallbackData.components);
    this.updateActivityLogUI(fallbackData.activities);
    
    // Show offline indicator
    const content = document.getElementById('main-content');
    if (content) {
      // Add offline banner if it doesn't exist
      if (!document.getElementById('offline-banner')) {
        const banner = document.createElement('div');
        banner.id = 'offline-banner';
        banner.className = 'offline-banner';
        banner.innerHTML = `
          <i class="fas fa-exclamation-triangle"></i>
          <span>Backend services unavailable. Showing simulated data.</span>
          <button id="retry-connection" class="btn btn-sm">
            <i class="fas fa-sync-alt"></i> Retry
          </button>
        `;
        content.insertBefore(banner, content.firstChild);
        
        // Add retry button handler
        document.getElementById('retry-connection')?.addEventListener('click', () => {
          // Remove the banner
          document.getElementById('offline-banner')?.remove();
          // Try to update with real data
          this.updateDashboard(true);
        });
      }
    }
    
    // Update last updated timestamp
    this.updateLastUpdatedTime();
  },
  
  /**
   * Get fallback data for offline mode
   * @returns {Object} Fallback data object
   */
  getFallbackData() {
    return {
      systemStatus: {
        status: 'warning',
        message: 'System running in offline mode'
      },
      networkStatus: {
        status: 'warning',
        message: 'Network monitoring unavailable'
      },
      threatLevel: {
        level: 1,
        status: 'warning'
      },
      components: [
        {
          name: 'SELinux',
          status: 'Offline',
          statusClass: 'warning',
          details: 'Status cannot be determined in offline mode'
        },
        {
          name: 'Firewall',
          status: 'Offline',
          statusClass: 'warning',
          details: 'Status cannot be determined in offline mode'
        },
        {
          name: 'AppArmor',
          status: 'Offline',
          statusClass: 'warning',
          details: 'Status cannot be determined in offline mode'
        },
        {
          name: 'File Permissions',
          status: 'Offline',
          statusClass: 'warning',
          details: 'Status cannot be determined in offline mode'
        }
      ],
      activities: [
        {
          type: 'warning',
          message: 'Backend Connectivity Issue',
          timestamp: new Date().toISOString(),
          details: 'Unable to connect to backend services. Showing simulated data.'
        },
        {
          type: 'info',
          message: 'System Running in Offline Mode',
          timestamp: new Date(Date.now() - 1000).toISOString(),
          details: 'Dashboard is displaying simulated data for demonstration purposes.'
        },
        {
          type: 'info',
          message: 'Last Known System Check',
          timestamp: new Date(Date.now() - 30*60000).toISOString(),
          details: 'Last successful system security check completed with no issues found.'
        }
      ]
    };
  },
  
  /**
   * Update the system status UI with provided data
   * @param {Object} data - System status data
   */
  updateSystemStatusUI(data) {
    const statusElement = document.getElementById('system-security-status');
    if (!statusElement) return;
    
    statusElement.classList.remove('loading', 'ok', 'warning', 'error');
    
    if (data) {
      statusElement.textContent = data.status === 'ok' ? 'Secure' : 
                                 data.status === 'warning' ? 'Warning' : 'Alert';
      statusElement.classList.add(data.status);
    } else {
      statusElement.textContent = 'Unknown';
      statusElement.classList.add('warning');
    }
  },
  
  /**
   * Update the network status UI with provided data
   * @param {Object} data - Network status data
   */
  updateNetworkStatusUI(data) {
    const networkStatus = document.getElementById('network-status');
    if (!networkStatus) return;
    
    networkStatus.classList.remove('loading', 'ok', 'warning', 'error');
    
    if (data) {
      networkStatus.textContent = data.message || 
                                 (data.status === 'ok' ? 'Protected' : 
                                  data.status === 'warning' ? 'Vulnerable' : 'Exposed');
      networkStatus.classList.add(data.status);
    } else {
      networkStatus.textContent = 'Unknown';
      networkStatus.classList.add('warning');
    }
  },
  
  /**
   * Update the threat level UI with provided data
   * @param {Object} data - Threat level data
   */
  updateThreatLevelUI(data) {
    const threatLevel = document.getElementById('threat-level-status');
    if (!threatLevel) return;
    
    threatLevel.classList.remove('loading', 'ok', 'warning', 'error');
    
    if (data) {
      let levelText = 'Low';
      let levelClass = 'ok';
      
      if (data.level >= 3) {
        levelText = 'High';
        levelClass = 'error';
      } else if (data.level >= 1) {
        levelText = 'Medium';
        levelClass = 'warning';
      }
      
      threatLevel.textContent = levelText;
      threatLevel.classList.add(levelClass);
    } else {
      threatLevel.textContent = 'Unknown';
      threatLevel.classList.add('warning');
    }
  },
  
  /**
   * Update the security components UI with provided data
   * @param {Array} components - Array of component data objects
   */
  updateSecurityComponentsUI(components) {
    const componentsList = document.getElementById('security-components-list');
    if (!componentsList) return;
    
    // Clear existing components
    componentsList.innerHTML = '';
    
    if (components && components.length > 0) {
      components.forEach(component => {
        this.addComponentStatus(
          componentsList,
          component.name,
          component.status,
          component.statusClass,
          component.details
        );
      });
    } else {
      componentsList.innerHTML = '<li class="component-error">No security components available</li>';
    }
  },
  
  /**
   * Update the activity log UI with provided data
   * @param {Array} activities - Array of activity data objects
   */
  updateActivityLogUI(activities) {
    const activityLog = document.getElementById('activity-log');
    if (!activityLog) return;
    
    // Clear existing logs
    activityLog.innerHTML = '';
    
    if (activities && activities.length > 0) {
      activities.forEach(activity => {
        this.addActivityLogEntry(
          activityLog,
          activity.type,
          activity.message,
          activity.timestamp,
          activity.details
        );
      });
    } else {
      activityLog.innerHTML = '<li class="component-error">No activity data available</li>';
    }
  },
  
  /**
   * Update the system status with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateSystemStatus(forceRefresh = false) {
    try {
      // Check cache first
      const now = Date.now();
      if (!forceRefresh && this._cache.systemStatus && 
          (now - this._cache.lastUpdate.systemStatus) < this.CACHE_TTL) {
        this.updateSystemStatusUI(this._cache.systemStatus);
        return;
      }
      
      // Fetch fresh data
      const data = await APIClient.getSystemStatus();
      
      // Update cache
      this._cache.systemStatus = data;
      this._cache.lastUpdate.systemStatus = now;
      
      // Update UI
      this.updateSystemStatusUI(data.overall);
    } catch (error) {
      console.error('Error fetching system status:', error);
      // Keep using cached data if available
      if (this._cache.systemStatus) {
        this.updateSystemStatusUI(this._cache.systemStatus);
      } else {
        // Show error state
        const statusElement = document.getElementById('system-security-status');
        if (statusElement) {
          statusElement.classList.remove('loading', 'ok', 'warning');
          statusElement.classList.add('error');
          statusElement.textContent = 'Error';
        }
      }
    }
  },
  
  /**
   * Update the network status with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateSecurityStatus(forceRefresh = false) {
    try {
      // Check cache first
      const now = Date.now();
      if (!forceRefresh && this._cache.securityStatus && 
          (now - this._cache.lastUpdate.securityStatus) < this.CACHE_TTL) {
        this.updateNetworkStatusUI(this._cache.securityStatus);
        return;
      }
      
      // Fetch fresh data
      const data = await APIClient.getNetworkStatus();
      
      // Update cache
      this._cache.securityStatus = data;
      this._cache.lastUpdate.securityStatus = now;
      
      // Update UI
      this.updateNetworkStatusUI(data);
    } catch (error) {
      console.error('Error fetching network status:', error);
      // Handle error (use cached data or fallback)
      if (this._cache.securityStatus) {
        this.updateNetworkStatusUI(this._cache.securityStatus);
      } else {
        const networkStatus = document.getElementById('network-status');
        if (networkStatus) {
          networkStatus.classList.remove('loading', 'ok', 'warning');
          networkStatus.classList.add('error');
          networkStatus.textContent = 'Error';
        }
      }
    }
  },
  
  /**
   * Update the threat level with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateThreatLevel(forceRefresh = false) {
    try {
      // Check cache first
      const now = Date.now();
      if (!forceRefresh && this._cache.threatData && 
          (now - this._cache.lastUpdate.threatData) < this.CACHE_TTL) {
        this.updateThreatLevelUI(this._cache.threatData);
        return;
      }
      
      // Fetch fresh data
      const data = await APIClient.getThreats();
      
      // Update cache
      this._cache.threatData = data;
      this._cache.lastUpdate.threatData = now;
      
      // Update UI
      this.updateThreatLevelUI(data);
    } catch (error) {
      console.error('Error fetching threat level:', error);
      // Handle error (use cached data or fallback)
      if (this._cache.threatData) {
        this.updateThreatLevelUI(this._cache.threatData);
      } else {
        const threatLevel = document.getElementById('threat-level-status');
        if (threatLevel) {
          threatLevel.classList.remove('loading', 'ok', 'warning');
          threatLevel.classList.add('error');
          threatLevel.textContent = 'Error';
        }
      }
    }
  },
  
  /**
   * Update the security components with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateSecurityComponents(forceRefresh = false) {
    try {
      // Check cache first
      const now = Date.now();
      if (!forceRefresh && this._cache.components &&
          (now - this._cache.lastUpdate.components) < this.CACHE_TTL) {
        this.updateSecurityComponentsUI(this._cache.components);
        return;
      }
      
      // Fetch fresh data
      const data = await APIClient.getSystemStatus();
      
      // Extract component data
      const components = [];
      if (data && data.components) {
        // Add SELinux
        if (data.components.selinux) {
          components.push({
            name: 'SELinux',
            status: data.components.selinux.message || 'Unknown',
            statusClass: data.components.selinux.status || 'warning',
            details: data.components.selinux.enforced ? 'Enforcing mode active' : 'Not in enforcing mode'
          });
        }
        
        // Add Firewall
        if (data.components.firewall) {
          components.push({
            name: 'Firewall',
            status: data.components.firewall.message || 'Unknown',
            statusClass: data.components.firewall.status || 'warning',
            details: data.components.firewall.active ? 'Firewall is running' : 'Firewall is not active'
          });
        }
        
        // Add AppArmor
        if (data.components.apparmor) {
          components.push({
            name: 'AppArmor',
            status: data.components.apparmor.message || 'Unknown',
            statusClass: data.components.apparmor.status || 'warning',
            details: data.components.apparmor.active ? 'AppArmor is active' : 'AppArmor is not active'
          });
        }
        
        // Add Permissions
        if (data.components.permissions) {
          components.push({
            name: 'File Permissions',
            status: data.components.permissions.message || 'Unknown',
            statusClass: data.components.permissions.status || 'warning',
            details: 'Critical file permissions'
          });
        }
      }
      
      // Update cache
      this._cache.components = components;
      this._cache.lastUpdate.components = now;
      
      // Update UI
      this.updateSecurityComponentsUI(components);
    } catch (error) {
      console.error('Error fetching security components:', error);
      // Handle error (use cached data or fallback)
      if (this._cache.components) {
        this.updateSecurityComponentsUI(this._cache.components);
      } else {
        const componentsList = document.getElementById('security-components-list');
        if (componentsList) {
          componentsList.innerHTML = `
            <li class="component-error">
              Error loading security components
            </li>
          `;
        }
      }
    }
  },
  
  /**
   * Add a component status to the list
   * @param {HTMLElement} parentElement - The parent element to add to
   * @param {string} name - Component name
   * @param {string} status - Status text
   * @param {string} statusClass - Status class (ok, warning, error)
   * @param {string} details - Detail text
   */
  addComponentStatus(parentElement, name, status, statusClass, details) {
    const li = document.createElement('li');
    li.className = `component-item status-${statusClass}`;
    
    li.innerHTML = `
      <div class="component-header">
        <span class="component-name">${name}</span>
        <span class="component-status">${status}</span>
      </div>
      <div class="component-details">${details || ''}</div>
    `;
    
    parentElement.appendChild(li);
  },
  
  /**
   * Update the activity log with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateActivityLog(forceRefresh = false) {
    try {
      // Check cache first
      const now = Date.now();
      if (!forceRefresh && this._cache.activityLog && 
          (now - this._cache.lastUpdate.activityLog) < this.CACHE_TTL) {
        this.updateActivityLogUI(this._cache.activityLog);
        return;
      }
      
      // Fetch fresh data
      const data = await APIClient.getLogs();
      
      // Format log entries
      const activities = [];
      if (data && data.logs) {
        data.logs.forEach(log => {
          activities.push({
            type: log.level || 'info',
            message: log.message || 'System event',
            timestamp: log.timestamp || new Date().toISOString(),
            details: log.details || ''
          });
        });
      }
      
      // Update cache
      this._cache.activityLog = activities;
      this._cache.lastUpdate.activityLog = now;
      
      // Update UI
      this.updateActivityLogUI(activities);
    } catch (error) {
      console.error('Error fetching activity log:', error);
      // Handle error (use cached data or fallback)
      if (this._cache.activityLog) {
        this.updateActivityLogUI(this._cache.activityLog);
      } else {
        const activityLog = document.getElementById('activity-log');
        if (activityLog) {
          activityLog.innerHTML = `
            <li class="component-error">
              Error loading activity log
            </li>
          `;
        }
      }
    }
  },
  
  /**
   * Add an activity log entry
   * @param {HTMLElement} parentElement - The parent element to add to
   * @param {string} type - Entry type (info, warning, error)
   * @param {string} message - Log message
   * @param {string} timestamp - ISO timestamp
   * @param {string} details - Additional details
   */
  addActivityLogEntry(parentElement, type, message, timestamp, details) {
    const date = new Date(timestamp);
    const formattedDate = date.toLocaleString();
    const timeDisplay = this.getRelativeTimeDisplay(date);
    
    const iconClass = type === 'error' ? 'fa-exclamation-circle' :
                     type === 'warning' ? 'fa-exclamation-triangle' : 'fa-info-circle';
    
    const li = document.createElement('li');
    li.className = `activity-item activity-${type}`;
    
    li.innerHTML = `
      <div class="activity-icon">
        <i class="fas ${iconClass}"></i>
      </div>
      <div class="activity-content">
        <div class="activity-header">
          <span class="activity-title">${message}</span>
          <span class="activity-time" title="${formattedDate}">${timeDisplay}</span>
        </div>
        <div class="activity-details">${details || ''}</div>
      </div>
    `;
    
    parentElement.appendChild(li);
  },
  
  /**
   * Get a relative time display string
   * @param {Date} date - The date to format
   * @returns {string} Formatted relative time
   */
  getRelativeTimeDisplay(date) {
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} ${diffMins === 1 ? 'minute' : 'minutes'} ago`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours} ${diffHours === 1 ? 'hour' : 'hours'} ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    
    return date.toLocaleDateString();
  },
  
  /**
   * Run a security scan
   */
  async runSecurityScan() {
    try {
      // Show toast notification
      showToast('Starting security scan...', 'info');
      
      // Call API
      const result = await APIClient.runSecurityScan({
        scan_type: 'full',
        depth: 3
      });
      
      if (result.success) {
        showToast('Security scan completed successfully', 'success');
        // Refresh dashboard data
        this.updateDashboard(true);
      } else {
        showToast(result.message || 'Security scan failed', 'error');
      }
    } catch (error) {
      console.error('Error running security scan:', error);
      showToast('Error running security scan', 'error');
    }
  },
  
  /**
   * Update the threat database
   */
  async updateThreatDatabase() {
    try {
      // Show toast notification
      showToast('Updating threat database...', 'info');
      
      // Call API
      const result = await APIClient.updateThreatDatabase();
      
      if (result.success) {
        showToast('Threat database updated successfully', 'success');
        // Refresh dashboard data
        this.updateDashboard(true);
      } else {
        showToast(result.message || 'Threat database update failed', 'warning');
      }
    } catch (error) {
      console.error('Error updating threat database:', error);
      showToast('Error updating threat database', 'error');
    }
  },
  
  /**
   * Run network analysis
   */
  async runNetworkAnalysis() {
    try {
      showToast('Running network analysis...', 'info');
      const result = await APIClient.runNetworkAnalysis();
      
      if (result && result.success) {
        showToast('Network analysis completed successfully', 'success');
        // Refresh data after analysis
        this.updateSecurityStatus(true);
      } else {
        showToast('Network analysis failed: ' + (result.error || 'Unknown error'), 'error');
      }
    } catch (error) {
      console.error('Error running network analysis:', error);
      showToast('Error running network analysis', 'error');
    }
  },
  
  /**
   * View full security report
   */
  viewFullReport() {
    // Create a modal for the full report if not already present
    let reportModal = document.getElementById('full-report-modal');
    
    if (!reportModal) {
      reportModal = document.createElement('div');
      reportModal.id = 'full-report-modal';
      reportModal.className = 'modal';
      
      // Using the cached security status data
      const systemStatus = this._cache.systemStatus || {};
      const securityStatus = this._cache.securityStatus || {};
      const threatData = this._cache.threatData || {};
      
      // Create a formatted report from available data
      const reportContent = `
        <div class="modal-content">
          <div class="modal-header">
            <h3>Full Security Report</h3>
            <button class="modal-close">&times;</button>
          </div>
          <div class="modal-body">
            <div class="report-section">
              <h4>System Security Status</h4>
              <div class="info-grid">
                <div class="info-row">
                  <span class="info-label">Overall Status:</span>
                  <span class="info-value ${systemStatus.overall?.status || 'warning'}">${systemStatus.overall?.status === 'ok' ? 'Secure' : systemStatus.overall?.status === 'warning' ? 'Warning' : 'Alert'}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Message:</span>
                  <span class="info-value">${systemStatus.overall?.message || 'Status information not available'}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Environment:</span>
                  <span class="info-value">${systemStatus.environment === 'virtual_machine' ? 'Virtual Machine' : 'Physical Machine'}</span>
                </div>
              </div>
            </div>
            
            <div class="report-section">
              <h4>Security Components</h4>
              <div class="component-status-grid">
                ${systemStatus.selinux ? `
                  <div class="component-status">
                    <h5>SELinux</h5>
                    <span class="status-badge ${systemStatus.selinux.status}">${systemStatus.selinux.enforced ? 'Enforcing' : 'Disabled'}</span>
                    <p>${systemStatus.selinux.message || 'No additional information available'}</p>
                  </div>
                ` : ''}
                
                ${systemStatus.firewall ? `
                  <div class="component-status">
                    <h5>Firewall</h5>
                    <span class="status-badge ${systemStatus.firewall.status}">${systemStatus.firewall.active ? 'Active' : 'Inactive'}</span>
                    <p>${systemStatus.firewall.message || 'No additional information available'}</p>
                  </div>
                ` : ''}
                
                ${systemStatus.apparmor ? `
                  <div class="component-status">
                    <h5>AppArmor</h5>
                    <span class="status-badge ${systemStatus.apparmor.status}">${systemStatus.apparmor.active ? 'Active' : 'Inactive'}</span>
                    <p>${systemStatus.apparmor.message || 'No additional information available'}</p>
                  </div>
                ` : ''}
                
                ${systemStatus.permissions ? `
                  <div class="component-status">
                    <h5>File Permissions</h5>
                    <span class="status-badge ${systemStatus.permissions.status}">${systemStatus.permissions.status === 'ok' ? 'Secure' : 'Needs Review'}</span>
                    <p>${systemStatus.permissions.message || 'No additional information available'}</p>
                  </div>
                ` : ''}
              </div>
            </div>
            
            <div class="report-section">
              <h4>Network Status</h4>
              <div class="info-grid">
                <div class="info-row">
                  <span class="info-label">Status:</span>
                  <span class="info-value ${securityStatus.network?.status || 'ok'}">${securityStatus.network?.status === 'ok' ? 'Protected' : securityStatus.network?.status === 'warning' ? 'Vulnerable' : 'Exposed'}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Details:</span>
                  <span class="info-value">${securityStatus.network?.message || 'No additional information available'}</span>
                </div>
              </div>
            </div>
            
            <div class="report-section">
              <h4>Threat Assessment</h4>
              <div class="info-grid">
                <div class="info-row">
                  <span class="info-label">Current Threat Level:</span>
                  <span class="info-value ${threatData.level >= 3 ? 'error' : threatData.level >= 1 ? 'warning' : 'ok'}">${threatData.level >= 3 ? 'High' : threatData.level >= 1 ? 'Medium' : 'Low'}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Active Threats:</span>
                  <span class="info-value">${threatData.active_threats || 0} detected</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Last Update:</span>
                  <span class="info-value">${threatData.last_update ? new Date(threatData.last_update).toLocaleString() : 'Unknown'}</span>
                </div>
              </div>
            </div>
            
            <div class="report-actions">
              <button id="print-report" class="btn btn-action">
                <i class="fas fa-print"></i>
                Print Report
              </button>
              <button id="export-report" class="btn btn-action">
                <i class="fas fa-file-export"></i>
                Export as PDF
              </button>
            </div>
          </div>
        </div>
      `;
      
      reportModal.innerHTML = reportContent;
      document.body.appendChild(reportModal);
      
      // Add event listeners
      reportModal.querySelector('.modal-close').addEventListener('click', () => {
        reportModal.classList.remove('show');
        setTimeout(() => reportModal.remove(), 300);
      });
      
      document.getElementById('print-report')?.addEventListener('click', () => {
        showToast('Print functionality not implemented in demo', 'info');
      });
      
      document.getElementById('export-report')?.addEventListener('click', () => {
        showToast('Export functionality not implemented in demo', 'info');
      });
      
      // Show the modal
      setTimeout(() => reportModal.classList.add('show'), 10);
    } else {
      // If modal already exists, just show it again
      reportModal.classList.add('show');
    }
  },
  
  /**
   * Update the last updated timestamp
   */
  updateLastUpdatedTime() {
    const element = document.getElementById('last-updated');
    if (element) {
      const now = new Date();
      element.textContent = `Last updated: ${now.toLocaleTimeString()}`;
    }
  },
  
  // Add these functions to load data directly
  async fetchDirectNetworkData() {
    try {
      console.log('Fetching direct network data');
      const API_URL = this.getApiUrl();
      const url = `${API_URL}/direct/network`;
      
      console.log(`Network API request to: ${url}`);
      
      // Direct fetch instead of using APIClient
      const response = await fetch(url);
      console.log('Network API response status:', response.status, response.statusText);
      
      if (!response.ok) {
        throw new Error(`Network request failed with status ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      console.log('Network data received:', data);
      
      // Update network status UI
      const networkStatus = document.getElementById('network-status');
      if (networkStatus && data.connections) {
        networkStatus.textContent = `${data.connections.length} active connections`;
        networkStatus.classList.remove('loading');
        networkStatus.classList.add('status-ok');
        console.log('Network UI updated successfully');
      } else {
        console.log('Network UI not updated - missing element or data:', { 
          elementExists: !!networkStatus, 
          dataValid: !!data.connections
        });
      }
      
      return data;
    } catch (error) {
      console.error('Error fetching network data:', error);
      // Try to use fallback data
      this.updateNetworkStatusUI(this.getFallbackData().networkStatus);
      console.log('Using fallback network data due to error');
      return null;
    }
  },
  
  async fetchDirectSecurityData() {
    try {
      console.log('Fetching direct security data');
      const API_URL = this.getApiUrl();
      const url = `${API_URL}/direct/security`;
      
      console.log(`Security API request to: ${url}`);
      
      // Direct fetch instead of using APIClient
      const response = await fetch(url);
      console.log('Security API response status:', response.status, response.statusText);
      
      if (!response.ok) {
        throw new Error(`Security request failed with status ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      console.log('Security data received:', data);
      
      // Update security status UI
      const systemSecurity = document.getElementById('system-security-status');
      if (systemSecurity && data.components) {
        const componentsStatus = Object.values(data.components);
        const allOk = componentsStatus.every(c => c.status === 'ok');
        
        systemSecurity.textContent = allOk ? 'All systems secure' : 'Security warnings detected';
        systemSecurity.classList.remove('loading');
        systemSecurity.classList.add(allOk ? 'status-ok' : 'status-warning');
        console.log('Security UI updated successfully');
        
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
          console.log('Components list updated successfully');
        } else {
          console.log('Components list not updated - element missing');
        }
      } else {
        console.log('Security UI not updated - missing element or data:', { 
          elementExists: !!systemSecurity, 
          dataValid: !!data.components
        });
      }
      
      return data;
    } catch (error) {
      console.error('Error fetching security data:', error);
      // Try to use fallback data
      this.updateSystemStatusUI(this.getFallbackData().systemStatus);
      console.log('Using fallback security data due to error');
      return null;
    }
  },
  
  async fetchDirectLogsData() {
    try {
      console.log('Fetching direct logs data');
      const API_URL = this.getApiUrl();
      const url = `${API_URL}/direct/logs`;
      
      console.log(`Logs API request to: ${url}`);
      
      // Direct fetch instead of using APIClient
      const response = await fetch(url);
      console.log('Logs API response status:', response.status, response.statusText);
      
      if (!response.ok) {
        throw new Error(`Logs request failed with status ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      console.log('Logs data received:', data);
      
      // Update activity log UI
      const activityLog = document.getElementById('activity-log');
      if (activityLog && data.logs) {
        activityLog.innerHTML = '';
        data.logs.slice(0, 10).forEach(log => {
          const li = document.createElement('li');
          li.className = `activity-item level-${log.level}`;
          li.innerHTML = `
            <span class="activity-time">${this.formatTime(new Date(log.timestamp))}</span>
            <span class="activity-message">${log.message}</span>
          `;
          activityLog.appendChild(li);
        });
        console.log('Activity log UI updated successfully');
        
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
          console.log('Threat level UI updated successfully');
        } else {
          console.log('Threat level UI not updated - element missing');
        }
      } else {
        console.log('Activity log UI not updated - missing element or data:', { 
          elementExists: !!activityLog, 
          dataValid: !!data.logs
        });
      }
      
      return data;
    } catch (error) {
      console.error('Error fetching logs data:', error);
      // Try to use fallback data
      this.updateThreatLevelUI(this.getFallbackData().threatLevel);
      this.updateActivityLogUI(this.getFallbackData().activities);
      console.log('Using fallback logs data due to error');
      return null;
    }
  },
  
  // Get API URL
  getApiUrl() {
    const hostname = window.location.hostname;
    const apiPort = 8080; // Backend API port
    return `http://${hostname}:${apiPort}/api`;
  },
  
  // Helper for formatting time
  formatTime(date) {
    return date.toLocaleTimeString();
  }
};

// Initialize the dashboard when the DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  // Only initialize if the dashboard tab is active or if this script is loaded for the dashboard view
  const dashboardButton = document.getElementById('nav-dashboard');
  if (dashboardButton && dashboardButton.classList.contains('active')) {
    HARDNDashboard.init();
  }
}); 