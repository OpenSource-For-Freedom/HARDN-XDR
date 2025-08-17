#!/bin/bash
# Quick test script for the new Next.js HARDN-XDR site

echo "🚀 Testing HARDN-XDR Next.js Site"
echo "================================="

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    exit 1
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Build the site
echo "🔨 Building production site..."
npm run build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📁 Static files generated in /docs folder"
    echo "🌐 Ready for GitHub Pages deployment"
    
    # Start a local server for testing
    echo ""
    echo "🔧 Starting local server on port 8080..."
    echo "   Visit: http://localhost:8080"
    echo "   Press Ctrl+C to stop"
    echo ""
    
    cd docs && python3 -m http.server 8080
else
    echo "❌ Build failed!"
    exit 1
fi