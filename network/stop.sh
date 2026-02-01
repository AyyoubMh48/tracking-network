#!/bin/bash

echo "=========================================="
echo "  Stopping Postal Tracking Network"
echo "=========================================="

cd "$(dirname "$0")"

# Stop containers
docker-compose down -v

# Remove chaincode containers
docker rm -f $(docker ps -aq --filter "name=dev-peer") 2>/dev/null || true

# Remove chaincode images
docker rmi -f $(docker images -q "dev-peer*") 2>/dev/null || true

# Clean up
rm -rf crypto-config channel-artifacts

echo ""
echo "Network stopped and cleaned up."
