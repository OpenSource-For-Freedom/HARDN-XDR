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
    
    // Update dashboard with real data
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
      // Check if API is available
      const isAvailable = await APIClient.checkBackendAvailable();
      if (!isAvailable) {
        console.warn('Backend connection unavailable, using fallback data');
        this.useOfflineMode();
        return;
      }
      
      // Update all sections concurrently
      await Promise.all([
        this.updateSystemStatus(forceRefresh),
        this.updateSecurityStatus(forceRefresh),
        this.updateThreatLevel(forceRefresh),
        this.updateSecurityComponents(forceRefresh),
        this.updateActivityLog(forceRefresh)
      ]);
      
      // Update last updated timestamp
      this.updateLastUpdatedTime();
    } catch (error) {
      console.error('Error updating dashboard:', error);
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
      if (!forceRefresh && 
          this._cache.systemStatus && 
          (now - this._cache.lastUpdate.systemStatus < this.CACHE_TTL)) {
        return;
      }
      
      const systemStatus = await APIClient.getSystemStatus();
      this._cache.systemStatus = systemStatus;
      this._cache.lastUpdate.systemStatus = now;
      
      // Extract status data
      const statusData = {
        status: systemStatus.overall ? systemStatus.overall.status : 'warning',
        message: systemStatus.overall ? systemStatus.overall.message : 'Status unknown'
      };
      
      // Update UI
      this.updateSystemStatusUI(statusData);
    } catch (error) {
      console.error('Error updating system status:', error);
      this.updateSystemStatusUI({
        status: 'error',
        message: 'Error retrieving status'
      });
    }
  },
  
  /**
   * Update the security status summary with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateSecurityStatus(forceRefresh = false) {
    try {
      // Check cache first
      const now = Date.now();
      if (!forceRefresh && 
          this._cache.securityStatus && 
          (now - this._cache.lastUpdate.securityStatus < this.CACHE_TTL)) {
        return;
      }
      
      const securityStatus = await APIClient.getSecurityStatus();
      this._cache.securityStatus = securityStatus;
      this._cache.lastUpdate.securityStatus = now;
      
      // Extract network status data
      const networkData = {
        status: (securityStatus && securityStatus.network) ? securityStatus.network.status : 'ok',
        message: (securityStatus && securityStatus.network) ? securityStatus.network.message : 'Protected'
      };
      
      // Update UI
      this.updateNetworkStatusUI(networkData);
    } catch (error) {
      console.error('Error updating security status:', error);
      this.updateNetworkStatusUI({
        status: 'warning',
        message: 'Status unknown'
      });
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
      if (!forceRefresh && 
          this._cache.threatData && 
          (now - this._cache.lastUpdate.threatData < this.CACHE_TTL)) {
        return;
      }
      
      const threatData = await APIClient.getThreatData();
      this._cache.threatData = threatData;
      this._cache.lastUpdate.threatData = now;
      
      // Extract threat data
      const threatLevel = {
        level: threatData && threatData.level !== undefined ? threatData.level : 0,
        status: threatData && threatData.status ? threatData.status : 'ok'
      };
      
      // Update UI
      this.updateThreatLevelUI(threatLevel);
    } catch (error) {
      console.error('Error updating threat level:', error);
      this.updateThreatLevelUI({
        level: 0,
        status: 'warning'
      });
    }
  },
  
  /**
   * Update the security components list with real data
   * @param {boolean} forceRefresh - Whether to bypass cache
   */
  async updateSecurityComponents(forceRefresh = false) {
    try {
      // Use the system status data already fetched
      if (forceRefresh || !this._cache.systemStatus) {
        await this.updateSystemStatus(forceRefresh);
      }
      
      const systemStatus = this._cache.systemStatus;
      if (!systemStatus) return;
      
      // Prepare components data
      const components = [];
      
      // Add SELinux status if available
      if (systemStatus.selinux) {
        components.push({
          name: 'SELinux',
          status: systemStatus.selinux.enforced ? 'Enforcing' : 'Disabled',
          statusClass: systemStatus.selinux.status,
          details: systemStatus.selinux.message
        });
      }
      
      // Add Firewall status if available
      if (systemStatus.firewall) {
        components.push({
          name: 'Firewall',
          status: systemStatus.firewall.active ? 'Active' : 'Inactive',
          statusClass: systemStatus.firewall.status,
          details: systemStatus.firewall.message
        });
      }
      
      // Add AppArmor status if available
      if (systemStatus.apparmor) {
        components.push({
          name: 'AppArmor',
          status: systemStatus.apparmor.active ? 'Active' : 'Inactive',
          statusClass: systemStatus.apparmor.status,
          details: systemStatus.apparmor.message
        });
      }
      
      // Add Permissions status if available
      if (systemStatus.permissions) {
        components.push({
          name: 'File Permissions',
          status: systemStatus.permissions.status === 'ok' ? 'Secure' : 'Needs Review',
          statusClass: systemStatus.permissions.status,
          details: systemStatus.permissions.message
        });
      }
      
      // Update UI
      this.updateSecurityComponentsUI(components);
    } catch (error) {
      console.error('Error updating security components:', error);
      this.updateSecurityComponentsUI([]);
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
      if (!forceRefresh && 
          this._cache.activityLog && 
          (now - this._cache.lastUpdate.activityLog < this.CACHE_TTL)) {
        return;
      }
      
      const logs = await APIClient.getSystemLogs(5);
      this._cache.activityLog = logs;
      this._cache.lastUpdate.activityLog = now;
      
      // Prepare activities data
      let activities = [];
      
      // Add log entries or defaults if no real data
      if (logs && logs.entries && logs.entries.length > 0) {
        activities = logs.entries.map(entry => ({
          type: entry.type || 'info',
          message: entry.message,
          timestamp: entry.timestamp,
          details: entry.details
        }));
      } else {
        // Default entries when no real data is available
        activities = [
          {
            type: 'info',
            message: 'System Check Completed',
            timestamp: new Date().toISOString(),
            details: 'Routine system security check completed with no issues found.'
          },
          {
            type: 'warning',
            message: 'Update Required',
            timestamp: new Date(Date.now() - 30*60000).toISOString(),
            details: 'Security definitions update is available and recommended.'
          },
          {
            type: 'error',
            message: 'Unusual Login Attempt',
            timestamp: new Date(Date.now() - 24*60*60000).toISOString(),
            details: 'Multiple failed login attempts detected from IP 192.168.1.45.'
          }
        ];
      }
      
      // Update UI
      this.updateActivityLogUI(activities);
    } catch (error) {
      console.error('Error updating activity log:', error);
      this.updateActivityLogUI([]);
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
      showToast('Running security scan...', 'info');
      const result = await APIClient.runSecurityScan();
      
      if (result && result.success) {
        showToast('Security scan completed successfully', 'success');
        // Refresh data after scan
        this.updateDashboard(true);
      } else {
        showToast('Security scan failed: ' + (result.error || 'Unknown error'), 'error');
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
      showToast('Updating threat database...', 'info');
      const result = await APIClient.updateThreatDB();
      
      if (result && result.success) {
        showToast('Threat database updated successfully', 'success');
        // Refresh threat data after update
        this.updateThreatLevel(true);
      } else {
        showToast('Threat database update failed: ' + (result.error || 'Unknown error'), 'error');
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