'use client';

import { useState } from 'react';

export default function Footer() {
  const [showModal, setShowModal] = useState(false);

  const showComingSoon = () => setShowModal(true);
  const closeModal = () => setShowModal(false);

  return (
    <>
      <footer className="bg-gray-900 border-t border-blue-400 py-16 text-center mt-20">
        <div className="max-w-4xl mx-auto px-6">
          <p className="text-xl text-gray-300 mb-6 font-semibold">
            HARDN-XDR - The Linux Security Project
          </p>
          
          <div className="flex flex-wrap justify-center gap-8 mb-8">
            <button 
              onClick={showComingSoon}
              className="text-blue-400 hover:text-blue-300 transition-colors duration-300 hover:underline"
            >
              Documentation
            </button>
            <button 
              onClick={showComingSoon}
              className="text-blue-400 hover:text-blue-300 transition-colors duration-300 hover:underline"
            >
              Download
            </button>
            <button 
              onClick={showComingSoon}
              className="text-blue-400 hover:text-blue-300 transition-colors duration-300 hover:underline"
            >
              Support
            </button>
            <a 
              href="https://github.com/Security-International-Group" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-blue-400 hover:text-blue-300 transition-colors duration-300 hover:underline"
            >
              GitHub
            </a>
            <button 
              onClick={showComingSoon}
              className="text-blue-400 hover:text-blue-300 transition-colors duration-300 hover:underline"
            >
              Contact
            </button>
          </div>
          
          <p className="text-gray-500 text-sm">
            Powered by{' '}
            <a 
              href="https://github.com/Security-International-Group" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-blue-400 hover:text-blue-300 transition-colors"
            >
              Security International Group
            </a>
          </p>
        </div>
      </footer>

      {/* Coming Soon Modal */}
      {showModal && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-50 p-4"
          onClick={closeModal}
        >
          <div 
            className="bg-gray-900 border border-blue-400 rounded-lg p-8 max-w-md mx-auto text-center cyber-glow-soft"
            onClick={(e) => e.stopPropagation()}
          >
            <button 
              onClick={closeModal}
              className="float-right text-red-400 hover:text-red-300 text-2xl font-bold leading-none"
            >
              ×
            </button>
            <h2 className="text-2xl font-bold text-blue-300 mb-4 font-['Orbitron']">
              Coming Soon!
            </h2>
            <p className="text-blue-400 mb-4">
              This feature is currently under development.
            </p>
            <p className="text-gray-400">
              Please visit our{' '}
              <a 
                href="https://github.com/Security-International-Group" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-blue-400 hover:text-blue-300 underline"
              >
                GitHub repository
              </a>{' '}
              for the latest updates.
            </p>
          </div>
        </div>
      )}
    </>
  );
}