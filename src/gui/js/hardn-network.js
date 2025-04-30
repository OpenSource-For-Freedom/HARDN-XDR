/**
 * HARDN Network Module
 * Handles network data display and analysis
 */

// Network-related functionality
const HARDNNetwork = {
  // Cache
  _cache: {
    networkData: null,
    lastUpdate: 0
  },
  
  // Cache TTL in milliseconds (30 seconds)
  CACHE_TTL: 30000,
  
  /**
   * Initialize the network module
   */
  init() {
    console.log('Initializing HARDN Network Module...');
    
    // Set up event delegation for network actions
    document.body.addEventListener('click', (e) => {
      // Handle network refresh button
      if (e.target.closest('#refresh-network')) {
        this.refreshNetworkData();
      }
      
      // Handle network action buttons (block, info)
      if (e.target.closest('.btn-icon')) {
        const button = e.target.closest('.btn-icon');
        const row = button.closest('tr');
        
        if (row) {
          const ip = row.querySelector('td:first-child')?.textContent;
          const port = row.querySelector('td:nth-child(2)')?.textContent;
          
          if (button.querySelector('.fa-ban')) {
            this.blockConnection(ip, port);
          } else if (button.querySelector('.fa-info-circle')) {
            this.showConnectionInfo(ip, port);
          }
        }
      }
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
      const response = await fetch('http://localhost:8081/api', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'network' })
      });
      
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      
      const data = await response.json();
      
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
   * Refresh the network data and update the UI
   */
  async refreshNetworkData() {
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Refreshing network data...');
      }
      
      const networkData = await this.fetchNetworkData(true);
      if (!networkData) {
        if (window.HARDNDashboard) {
          window.HARDNDashboard.showToast('Failed to fetch network data', 'error');
        }
        return;
      }
      
      // Update the UI with new data
      this.renderNetworkData(networkData);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Network data refreshed successfully', 'success');
      }
    } catch (error) {
      console.error('Error refreshing network data:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Error refreshing network data', 'error');
      }
    }
  },
  
  /**
   * Render network data in the UI
   * @param {Array} data - Network connection data
   */
  renderNetworkData(data) {
    const tableBody = document.querySelector('.data-table tbody');
    if (!tableBody) return;
    
    // Clear existing rows
    tableBody.innerHTML = '';
    
    if (!data || data.length === 0) {
      tableBody.innerHTML = `
        <tr>
          <td colspan="4" class="text-center">No active connections found</td>
        </tr>
      `;
      return;
    }
    
    // Add network connection rows
    data.forEach(conn => {
      const row = document.createElement('tr');
      row.innerHTML = `
        <td>${conn.ip}</td>
        <td>${conn.port}</td>
        <td><span class="badge badge-success">Open</span></td>
        <td>
          <button class="btn-icon small" title="Connection Info"><i class="fas fa-info-circle"></i></button>
          <button class="btn-icon small" title="Block Connection"><i class="fas fa-ban"></i></button>
        </td>
      `;
      tableBody.appendChild(row);
    });
    
    // Update stat values
    const statValue = document.querySelector('.stat-value');
    if (statValue) {
      statValue.textContent = data.length;
    }
    
    // Update last updated time
    const timeElement = document.querySelector('.update-info span');
    if (timeElement) {
      const now = new Date();
      const time = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      timeElement.textContent = `Last updated: ${time}`;
    }
  },
  
  /**
   * Block a network connection
   * @param {string} ip - IP address
   * @param {string} port - Port number
   */
  async blockConnection(ip, port) {
    if (!ip || !port) return;
    
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Blocking connection ${ip}:${port}...`);
      }
      
      // In a real implementation, this would call the backend to block the connection
      // For now, we'll just simulate it with a delay
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      // For demo purposes, just refresh the data
      await this.fetchNetworkData(true);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Connection ${ip}:${port} has been blocked`, 'success');
      }
      
      // Increment blocked count (this is just for the UI demo)
      const blockedCountEl = document.querySelector('.stat-grid .stat-item:nth-child(2) .stat-value');
      if (blockedCountEl) {
        const currentCount = parseInt(blockedCountEl.textContent, 10) || 0;
        blockedCountEl.textContent = (currentCount + 1).toString();
      }
      
    } catch (error) {
      console.error(`Error blocking connection ${ip}:${port}:`, error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Failed to block connection ${ip}:${port}`, 'error');
      }
    }
  },
  
  /**
   * Show detailed information about a connection
   * @param {string} ip - IP address
   * @param {string} port - Port number
   */
  async showConnectionInfo(ip, port) {
    if (!ip || !port) return;
    
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Loading information for ${ip}:${port}...`);
      }
      
      // In a real implementation, this would fetch detailed info from the backend
      // For now, we'll simulate with a delay and show a fake modal
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Create modal
      let modal = document.getElementById('network-modal');
      if (!modal) {
        modal = document.createElement('div');
        modal.id = 'network-modal';
        modal.className = 'modal';
        document.body.appendChild(modal);
      }
      
      // Generate some fake connection details
      const protocol = port == 80 ? 'HTTP' : 
                      port == 443 ? 'HTTPS' : 
                      port == 22 ? 'SSH' : 
                      port == 3306 ? 'MySQL' : 'TCP';
      
      const status = 'Active';
      const established = new Date();
      established.setMinutes(established.getMinutes() - Math.floor(Math.random() * 60));
      const duration = Math.floor((new Date() - established) / 60000);
      
      const sent = Math.floor(Math.random() * 1000000);
      const received = Math.floor(Math.random() * 5000000);
      
      // Create modal content
      modal.innerHTML = `
        <div class="modal-content">
          <div class="modal-header">
            <h3>Connection Details: ${ip}:${port}</h3>
            <button class="modal-close">&times;</button>
          </div>
          <div class="modal-body">
            <div class="info-grid">
              <div class="info-row">
                <div class="info-label">IP Address</div>
                <div class="info-value">${ip}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Port</div>
                <div class="info-value">${port}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Protocol</div>
                <div class="info-value">${protocol}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Status</div>
                <div class="info-value">${status}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Established</div>
                <div class="info-value">${established.toLocaleTimeString()} (${duration} min ago)</div>
              </div>
              <div class="info-row">
                <div class="info-label">Data Sent</div>
                <div class="info-value">${(sent / 1024).toFixed(2)} KB</div>
              </div>
              <div class="info-row">
                <div class="info-label">Data Received</div>
                <div class="info-value">${(received / 1024).toFixed(2)} KB</div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="action-btn" id="block-connection-btn">
              <i class="fas fa-ban"></i> Block Connection
            </button>
            <button class="action-btn" id="close-modal-btn">Close</button>
          </div>
        </div>
      `;
      
      // Show modal
      modal.style.display = 'flex';
      
      // Add event listeners
      modal.querySelector('.modal-close').addEventListener('click', () => {
        modal.style.display = 'none';
      });
      
      modal.querySelector('#close-modal-btn').addEventListener('click', () => {
        modal.style.display = 'none';
      });
      
      modal.querySelector('#block-connection-btn').addEventListener('click', () => {
        modal.style.display = 'none';
        this.blockConnection(ip, port);
      });
      
      // Close when clicking outside
      modal.addEventListener('click', (e) => {
        if (e.target === modal) {
          modal.style.display = 'none';
        }
      });
      
    } catch (error) {
      console.error(`Error showing info for ${ip}:${port}:`, error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Failed to load connection info`, 'error');
      }
    }
  }
};

// Expose to window
window.HARDNNetwork = HARDNNetwork; 