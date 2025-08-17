'use client';

import { useState, useRef } from 'react';

interface DemoScript {
  [key: string]: string[];
}

const demoScripts: DemoScript = {
  scan: [
    'root@hardn-xdr:~# hardn-xdr --scan --verbose',
    'Initializing HARDN-XDR security scan...',
    'Loading 41 security modules...',
    '[✓] DISA STIG compliance check',
    '[✓] CIS Controls validation', 
    '[✓] FIPS 140-2 cryptographic validation',
    '[✓] File integrity monitoring (AIDE)',
    '[✓] Malware detection (YARA, ClamAV)',
    '[✓] Network security assessment',
    '[✓] System hardening verification',
    'Scan completed: 98% compliance achieved',
    'Recommendations: 3 items require attention'
  ],
  monitor: [
    'root@hardn-xdr:~# hardn-xdr --monitor --dashboard',
    'Starting real-time security monitoring...',
    'Launching Matrix-themed compliance dashboard...',
    'Port 8021: Dashboard server started',
    '[MONITOR] Audit logging: ACTIVE',
    '[MONITOR] Intrusion detection: ACTIVE', 
    '[MONITOR] File integrity: ACTIVE',
    '[MONITOR] Network monitoring: ACTIVE',
    'Dashboard available at: http://localhost:8021/hardn-compliance.html',
    'Real-time metrics streaming...'
  ],
  analysis: [
    'root@hardn-xdr:~# hardn-xdr --analyze --compliance',
    'Performing deep compliance analysis...',
    'Analyzing STIG controls: 254 items',
    'Validating CIS benchmarks: 187 controls',
    'Checking FIPS compliance: 23 modules',
    '[ANALYSIS] Critical: 0 findings',
    '[ANALYSIS] High: 2 findings',
    '[ANALYSIS] Medium: 5 findings',
    '[ANALYSIS] Low: 12 findings',
    'Generating compliance report...',
    'Analysis complete: Overall score 94.2%'
  ]
};

export default function TerminalDemo() {
  const [demoRunning, setDemoRunning] = useState(false);
  const terminalRef = useRef<HTMLDivElement>(null);

  const typeText = (text: string, delay: number = 50): Promise<void> => {
    return new Promise((resolve) => {
      let i = 0;
      const div = document.createElement('div');
      div.className = 'text-blue-200';
      terminalRef.current?.appendChild(div);

      const type = () => {
        if (i < text.length) {
          div.textContent += text.charAt(i);
          i++;
          setTimeout(type, delay);
        } else {
          resolve();
        }
      };
      type();
    });
  };

  const runDemo = async (type: string) => {
    if (demoRunning) return;
    setDemoRunning(true);

    const script = demoScripts[type];
    for (const line of script) {
      await typeText(line, 30);
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    await typeText('', 100);
    await typeText('root@hardn-xdr:~# ', 50);

    setDemoRunning(false);
  };

  const clearTerminal = () => {
    if (terminalRef.current) {
      terminalRef.current.innerHTML = `
        <div class="text-blue-200">root@hardn-xdr:~# clear</div>
        <div class="text-blue-200">root@hardn-xdr:~# <span class="cursor">█</span></div>
      `;
    }
  };

  return (
    <section className="py-16">
      <div className="max-w-7xl mx-auto px-6">
        <h2 className="text-4xl font-bold text-center mb-4 font-['Orbitron'] text-blue-300">
          LIVE DEMONSTRATION
        </h2>
        <p className="text-center text-gray-400 mb-12 text-lg">
          Experience HARDN-XDR&apos;s capabilities in action
        </p>

        <div className="bg-gray-900 border border-gray-600 rounded-lg overflow-hidden shadow-lg cyber-glow-soft max-w-5xl mx-auto">
          <div className="terminal-header flex items-center justify-between p-4">
            <div className="flex gap-2">
              <div className="w-3 h-3 bg-red-500 rounded-full"></div>
              <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div className="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <div className="text-blue-300 font-bold tracking-wider text-sm">
              HARDN-XDR Security Demonstration
            </div>
            <div></div>
          </div>

          <div className="terminal-content p-6 min-h-[400px] font-mono text-sm leading-relaxed">
            <div ref={terminalRef} className="text-blue-200">
              <div>root@hardn-xdr:~# hardn-xdr --version</div>
              <div>HARDN-XDR v2.0.0 - Linux Security Hardening Platform</div>
              <div>Architecture: Multi-platform (AMD64/ARM64)</div>
              <div>Compliance: DISA STIG | CIS Controls | FIPS 140-2</div>
              <div>Status: Ready for demonstration</div>
              <div><br /></div>
              <div>root@hardn-xdr:~# <span className="cursor">█</span></div>
            </div>
          </div>
        </div>

        <div className="flex flex-wrap justify-center gap-4 mt-8">
          <button
            className="cyber-button px-6 py-3 rounded font-semibold tracking-wide"
            onClick={() => runDemo('scan')}
            disabled={demoRunning}
          >
            Run Scan Demo
          </button>
          <button
            className="cyber-button px-6 py-3 rounded font-semibold tracking-wide"
            onClick={() => runDemo('monitor')}
            disabled={demoRunning}
          >
            Monitor Demo
          </button>
          <button
            className="cyber-button px-6 py-3 rounded font-semibold tracking-wide"
            onClick={() => runDemo('analysis')}
            disabled={demoRunning}
          >
            Analysis Demo
          </button>
          <button
            className="cyber-button px-6 py-3 rounded font-semibold tracking-wide border-red-500 text-red-400 hover:border-red-400 hover:text-red-300"
            onClick={clearTerminal}
          >
            Clear
          </button>
        </div>
      </div>
    </section>
  );
}