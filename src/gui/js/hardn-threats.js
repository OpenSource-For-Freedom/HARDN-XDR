/**
 * HARDN Threats Module
 * Handles threat detection and response
 */

// Threats-related functionality
const HARDNThreats = {
  // Cache
  _cache: {
    threatData: null,
    lastUpdate: 0
  },
  
  // Cache TTL in milliseconds (30 seconds)
  CACHE_TTL: 30000,
  
  /**
   * Initialize the threats module
   */
  init() {
    console.log('Initializing HARDN Threats Module...');
    
    // Set up event delegation for threat actions
    document.body.addEventListener('click', (e) => {
      // Handle threats refresh button
      if (e.target.closest('#refresh-threats')) {
        this.refreshThreatData();
      }
      
      // Handle threat action buttons (mitigate, block)
      if (e.target.closest('.btn-icon')) {
        const button = e.target.closest('.btn-icon');
        const row = button.closest('tr');
        
        if (row) {
          const description = row.querySelector('td:nth-child(2)')?.textContent;
          
          if (button.querySelector('.fa-shield-alt')) {
            this.mitigateThreat(description);
          } else if (button.querySelector('.fa-times')) {
            this.dismissThreat(description);
          }
        }
      }
      
      // Handle mitigate all button
      if (e.target.closest('.card-actions .btn-text')) {
        const button = e.target.closest('.btn-text');
        if (button.querySelector('.fa-shield-alt')) {
          this.mitigateAllThreats();
        }
      }
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
      const response = await fetch('http://localhost:8081/api', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'threats' })
      });
      
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      
      const data = await response.json();
      
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
   * Refresh the threat data and update the UI
   */
  async refreshThreatData() {
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Refreshing threat data...');
      }
      
      const threatData = await this.fetchThreatData(true);
      if (!threatData) {
        if (window.HARDNDashboard) {
          window.HARDNDashboard.showToast('Failed to fetch threat data', 'error');
        }
        return;
      }
      
      // Update the UI with new data
      this.renderThreatData(threatData);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Threat data refreshed successfully', 'success');
      }
    } catch (error) {
      console.error('Error refreshing threat data:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Error refreshing threat data', 'error');
      }
    }
  },
  
  /**
   * Render threat data in the UI
   * @param {Object} data - Threat data
   */
  renderThreatData(data) {
    // Update summary cards
    this.updateThreatSummary(data);
    
    // Update threat table
    this.updateThreatTable(data);
    
    // Update last updated time
    const timeElement = document.querySelector('.update-info span');
    if (timeElement) {
      const now = new Date();
      const time = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      timeElement.textContent = `Last updated: ${time}`;
    }
  },
  
  /**
   * Update the threat summary cards
   * @param {Object} data - Threat data
   */
  updateThreatSummary(data) {
    if (!data) return;
    
    // Update threat level
    const threatLevelCard = document.querySelector('.security-summary .summary-card:nth-child(1) .summary-status');
    if (threatLevelCard) {
      let levelClass = data.level > 2 ? 'error' : (data.level > 1 ? 'warning' : 'ok');
      let levelText = data.level > 2 ? 'High' : (data.level > 1 ? 'Medium' : 'Low');
      
      threatLevelCard.className = `summary-status ${levelClass}`;
      threatLevelCard.textContent = levelText;
    }
    
    // Update active threats count
    const activeThreatsCard = document.querySelector('.security-summary .summary-card:nth-child(2) .summary-status');
    if (activeThreatsCard) {
      const count = data.items ? data.items.length : 0;
      let statusClass = count > 0 ? 'warning' : 'ok';
      
      activeThreatsCard.className = `summary-status ${statusClass}`;
      activeThreatsCard.textContent = `${count} Detected`;
    }
  },
  
  /**
   * Update the threat table
   * @param {Object} data - Threat data
   */
  updateThreatTable(data) {
    const tableBody = document.querySelector('.data-table tbody');
    if (!tableBody) return;
    
    // Clear existing rows
    tableBody.innerHTML = '';
    
    if (!data || !data.items || data.items.length === 0) {
      tableBody.innerHTML = `
        <tr>
          <td colspan="3" class="text-center">No threats detected</td>
        </tr>
      `;
      return;
    }
    
    // Add threat rows
    data.items.forEach(threat => {
      const row = document.createElement('tr');
      
      // Determine level class
      const levelClass = threat.level > 2 ? 'high' : (threat.level > 1 ? 'medium' : 'low');
      
      row.innerHTML = `
        <td><span class="threat-level ${levelClass}">${threat.level}</span></td>
        <td>${threat.description}</td>
        <td>
          <button class="btn-icon small" title="Mitigate Threat"><i class="fas fa-shield-alt"></i></button>
          <button class="btn-icon small" title="Dismiss Threat"><i class="fas fa-times"></i></button>
        </td>
      `;
      tableBody.appendChild(row);
    });
  },
  
  /**
   * Mitigate a specific threat
   * @param {string} description - Threat description
   */
  async mitigateThreat(description) {
    if (!description) return;
    
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Mitigating threat: ${description}...`);
      }
      
      // In a real implementation, this would call the backend to mitigate the threat
      // For now, we'll just simulate it with a delay
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Refresh data after mitigation
      const threatData = await this.fetchThreatData(true);
      
      // For demo purposes, remove the threat from the list
      if (threatData && threatData.items) {
        const index = threatData.items.findIndex(item => item.description === description);
        if (index !== -1) {
          threatData.items.splice(index, 1);
          
          // Recalculate threat level based on remaining threats
          threatData.level = threatData.items.length > 0 ? 
            Math.max(...threatData.items.map(item => item.level)) : 0;
            
          // Update cache
          this._cache.threatData = threatData;
          
          // Update UI
          this.renderThreatData(threatData);
        }
      }
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Threat mitigated successfully`, 'success');
      }
      
    } catch (error) {
      console.error(`Error mitigating threat: ${description}`, error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Failed to mitigate threat`, 'error');
      }
    }
  },
  
  /**
   * Dismiss a specific threat (mark as false positive)
   * @param {string} description - Threat description
   */
  async dismissThreat(description) {
    if (!description) return;
    
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Dismissing threat: ${description}...`);
      }
      
      // In a real implementation, this would call the backend
      // For now, we'll just simulate it with a delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Refresh data after dismissal
      const threatData = await this.fetchThreatData(true);
      
      // For demo purposes, remove the threat from the list
      if (threatData && threatData.items) {
        const index = threatData.items.findIndex(item => item.description === description);
        if (index !== -1) {
          threatData.items.splice(index, 1);
          
          // Recalculate threat level based on remaining threats
          threatData.level = threatData.items.length > 0 ? 
            Math.max(...threatData.items.map(item => item.level)) : 0;
            
          // Update cache
          this._cache.threatData = threatData;
          
          // Update UI
          this.renderThreatData(threatData);
        }
      }
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Threat dismissed`, 'success');
      }
      
    } catch (error) {
      console.error(`Error dismissing threat: ${description}`, error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Failed to dismiss threat`, 'error');
      }
    }
  },
  
  /**
   * Mitigate all detected threats
   */
  async mitigateAllThreats() {
    try {
      const threatData = await this.fetchThreatData(true);
      
      if (!threatData || !threatData.items || threatData.items.length === 0) {
        if (window.HARDNDashboard) {
          window.HARDNDashboard.showToast('No threats to mitigate', 'info');
        }
        return;
      }
      
      const count = threatData.items.length;
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Mitigating ${count} threats...`);
      }
      
      // In a real implementation, this would call the backend
      // For now, we'll just simulate it with a delay
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // For demo purposes, clear all threats
      threatData.items = [];
      threatData.level = 0;
      
      // Update cache
      this._cache.threatData = threatData;
      
      // Update UI
      this.renderThreatData(threatData);
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast(`Successfully mitigated ${count} threats`, 'success');
      }
      
    } catch (error) {
      console.error('Error mitigating all threats:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Failed to mitigate threats', 'error');
      }
    }
  },
  
  /**
   * Run a security scan to detect threats
   */
  async runThreatScan() {
    try {
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Running threat scan...');
      }
      
      // In a real implementation, this would call the backend
      // For now, we'll just simulate it with a delay
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Refresh threats data
      await this.refreshThreatData();
      
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Threat scan completed', 'success');
      }
    } catch (error) {
      console.error('Error running threat scan:', error);
      if (window.HARDNDashboard) {
        window.HARDNDashboard.showToast('Failed to complete threat scan', 'error');
      }
    }
  }
};

// Expose to window
window.HARDNThreats = HARDNThreats; 