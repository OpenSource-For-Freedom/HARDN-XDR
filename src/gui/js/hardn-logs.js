/**
 * HARDN Logs Module
 * Handles system log display and filtering
 */

// Logs-related functionality
const HARDNLogs = {
  // Cache
  _cache: {
    logData: null,
    lastUpdate: 0
  },
  
  // Cache TTL in milliseconds (15 seconds)
  CACHE_TTL: 15000,
  
  /**
   * Initialize the logs module
   */
  init() {
    console.log('Initializing HARDN Logs Module...');
    
    // Set up event delegation for log actions
    document.body.addEventListener('click', (e) => {
      // Handle logs refresh button
      if (e.target.closest('#refresh-logs')) {
        this.refreshLogData();
      }
      
      // Handle log filter button
      if (e.target.closest('.card-actions .btn-text')) {
        const button = e.target.closest('.btn-text');
        if (button.querySelector('.fa-filter')) {
          this.showLogFilter();
        } else if (button.querySelector('.fa-download')) {
          this.exportLogs();
        }
      }
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
      const response = await fetch('http://localhost:8081/api', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'logs' })
      });
      
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      
      const data = await response.json();
      
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
   * Refresh the log data and update the UI
   */
  async refreshLogData() {
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Refreshing logs...');
      }
      
      const logData = await this.fetchLogData(true);
      if (!logData) {
        if (window.HARDNDashboard) {
          window.HARDNDashboard.showToast('Failed to fetch logs', 'error');
        }
        return;
      }
      
      // Update the UI with new data
      this.renderLogData(logData);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Logs refreshed successfully', 'success');
      }
    } catch (error) {
      console.error('Error refreshing logs:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Error refreshing logs', 'error');
      }
    }
  },
  
  /**
   * Render log data in the UI
   * @param {Array} data - Log data
   */
  renderLogData(data) {
    const logContainer = document.querySelector('.log-container');
    if (!logContainer) return;
    
    // Clear existing logs
    logContainer.innerHTML = '';
    
    if (!data || data.length === 0) {
      logContainer.innerHTML = '<div class="log-item log-empty">No logs available</div>';
      return;
    }
    
    // Add log items
    data.forEach(log => {
      const logItem = document.createElement('div');
      
      // Determine log class based on content
      let logClass = '';
      if (log.toLowerCase().includes('error') || log.toLowerCase().includes('fail')) {
        logClass = 'log-error';
      } else if (log.toLowerCase().includes('warn') || log.toLowerCase().includes('attention')) {
        logClass = 'log-warning';
      }
      
      logItem.className = `log-item ${logClass}`;
      logItem.textContent = log;
      logContainer.appendChild(logItem);
    });
    
    // Update last updated time
    const timeElement = document.querySelector('.update-info span');
    if (timeElement) {
      const now = new Date();
      const time = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      timeElement.textContent = `Last updated: ${time}`;
    }
  },
  
  /**
   * Show log filtering options
   */
  showLogFilter() {
    // Create filter dropdown content
    let filterContent = `
      <div class="filter-dropdown" id="log-filter-dropdown">
        <div class="filter-header">
          <h4>Filter Logs</h4>
          <button class="close-filter">&times;</button>
        </div>
        <div class="filter-options">
          <label>
            <input type="checkbox" data-filter="all" checked> All Logs
          </label>
          <label>
            <input type="checkbox" data-filter="error"> Errors Only
          </label>
          <label>
            <input type="checkbox" data-filter="warning"> Warnings Only
          </label>
          <label>
            <input type="checkbox" data-filter="system"> System Logs
          </label>
          <label>
            <input type="checkbox" data-filter="security"> Security Logs
          </label>
        </div>
        <div class="filter-search">
          <input type="text" placeholder="Search logs..." id="log-search">
        </div>
        <div class="filter-actions">
          <button class="apply-filter">Apply Filters</button>
          <button class="reset-filter">Reset</button>
        </div>
      </div>
    `;
    
    // Create or update filter dropdown
    let dropdown = document.getElementById('log-filter-dropdown');
    
    if (!dropdown) {
      dropdown = document.createElement('div');
      dropdown.innerHTML = filterContent;
      document.querySelector('.card-header')?.appendChild(dropdown.firstElementChild);
      dropdown = document.getElementById('log-filter-dropdown');
    } else {
      dropdown.style.display = dropdown.style.display === 'block' ? 'none' : 'block';
    }
    
    // Add event listeners
    if (dropdown) {
      // Close button
      dropdown.querySelector('.close-filter')?.addEventListener('click', () => {
        dropdown.style.display = 'none';
      });
      
      // Apply filter button
      dropdown.querySelector('.apply-filter')?.addEventListener('click', () => {
        this.applyLogFilter(dropdown);
        dropdown.style.display = 'none';
      });
      
      // Reset filter button
      dropdown.querySelector('.reset-filter')?.addEventListener('click', () => {
        this.resetLogFilter(dropdown);
      });
      
      // All logs checkbox
      const allLogsCheckbox = dropdown.querySelector('input[data-filter="all"]');
      if (allLogsCheckbox) {
        allLogsCheckbox.addEventListener('change', (e) => {
          const checked = e.target.checked;
          dropdown.querySelectorAll('.filter-options input:not([data-filter="all"])')
            .forEach(input => {
              input.checked = false;
              input.disabled = checked;
            });
        });
      }
      
      // Other checkboxes
      dropdown.querySelectorAll('.filter-options input:not([data-filter="all"])')
        .forEach(input => {
          input.addEventListener('change', (e) => {
            const anyChecked = Array.from(
              dropdown.querySelectorAll('.filter-options input:not([data-filter="all"])')
            ).some(i => i.checked);
            
            const allCheckbox = dropdown.querySelector('input[data-filter="all"]');
            if (allCheckbox) {
              allCheckbox.checked = !anyChecked;
            }
          });
        });
    }
  },
  
  /**
   * Apply log filtering based on selected options
   * @param {HTMLElement} dropdown - The filter dropdown element
   */
  async applyLogFilter(dropdown) {
    try {
      // Get filter options
      const showAll = dropdown.querySelector('input[data-filter="all"]')?.checked;
      const showErrors = dropdown.querySelector('input[data-filter="error"]')?.checked;
      const showWarnings = dropdown.querySelector('input[data-filter="warning"]')?.checked;
      const showSystem = dropdown.querySelector('input[data-filter="system"]')?.checked;
      const showSecurity = dropdown.querySelector('input[data-filter="security"]')?.checked;
      
      // Get search text
      const searchText = dropdown.querySelector('#log-search')?.value.toLowerCase();
      
      // Get all logs
      const logs = await this.fetchLogData();
      if (!logs) return;
      
      // Apply filters
      let filteredLogs = logs;
      
      if (!showAll) {
        filteredLogs = logs.filter(log => {
          const logLower = log.toLowerCase();
          
          // Filter by type
          if (showErrors && (logLower.includes('error') || logLower.includes('fail'))) {
            return true;
          }
          
          if (showWarnings && (logLower.includes('warn') || logLower.includes('attention'))) {
            return true;
          }
          
          if (showSystem && (logLower.includes('system') || logLower.includes('startup'))) {
            return true;
          }
          
          if (showSecurity && (logLower.includes('security') || logLower.includes('auth'))) {
            return true;
          }
          
          return false;
        });
      }
      
      // Apply search text filter
      if (searchText) {
        filteredLogs = filteredLogs.filter(log => 
          log.toLowerCase().includes(searchText)
        );
      }
      
      // Render filtered logs
      this.renderLogData(filteredLogs);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Showing ${filteredLogs.length} filtered logs`);
      }
    } catch (error) {
      console.error('Error applying log filter:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Error applying log filter', 'error');
      }
    }
  },
  
  /**
   * Reset log filters
   * @param {HTMLElement} dropdown - The filter dropdown element
   */
  resetLogFilter(dropdown) {
    // Reset all checkboxes
    dropdown.querySelector('input[data-filter="all"]').checked = true;
    
    dropdown.querySelectorAll('.filter-options input:not([data-filter="all"])')
      .forEach(input => {
        input.checked = false;
        input.disabled = true;
      });
    
    // Clear search
    dropdown.querySelector('#log-search').value = '';
    
    // Refresh logs
    this.refreshLogData();
  },
  
  /**
   * Export logs to a downloadable file
   */
  async exportLogs() {
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Preparing logs for export...');
      }
      
      const logs = await this.fetchLogData();
      if (!logs || logs.length === 0) {
        if (window.HARDNDashboard) {
          window.HARDNDashboard.showToast('No logs to export', 'warning');
        }
        return;
      }
      
      // Create file content
      const content = logs.join('\n');
      
      // Create blob and download link
      const blob = new Blob([content], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      
      const date = new Date().toISOString().slice(0, 10);
      const filename = `hardn_logs_${date}.txt`;
      
      // Create download link
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.style.display = 'none';
      document.body.appendChild(a);
      a.click();
      
      // Clean up
      setTimeout(() => {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }, 100);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Logs exported successfully', 'success');
      }
    } catch (error) {
      console.error('Error exporting logs:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Error exporting logs', 'error');
      }
    }
  }
};

// Expose to window
window.HARDNLogs = HARDNLogs; 