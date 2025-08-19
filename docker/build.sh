#!/bin/bash
set -e

# HARDN-XDR Docker Build Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Building HARDN-XDR Docker images..."

# Build Debian Bookworm image
echo "Building Debian Bookworm image..."
cd "${PROJECT_ROOT}"
docker build -f docker/debian-bookworm/Dockerfile -t hardn-xdr:debian-bookworm .
docker tag hardn-xdr:debian-bookworm hardn-xdr:latest

echo "Build completed successfully!"
echo ""
echo "Available images:"
docker images | grep hardn-xdr

echo ""
echo "To run the container:"
echo "  docker run -it --rm hardn-xdr:debian-bookworm"
echo ""
echo "To run with docker-compose:"
echo "  cd docker/debian-bookworm && docker-compose up -d"
