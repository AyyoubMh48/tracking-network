#!/bin/bash

set -e

echo "=========================================="
echo "  Postal Tracking Network - Startup Script"
echo "=========================================="

# Navigate to network directory
cd "$(dirname "$0")"

# Clean up previous runs
echo "[1/7] Cleaning up previous network..."
docker-compose down -v 2>/dev/null || true
rm -rf crypto-config channel-artifacts
mkdir -p channel-artifacts

# Generate crypto materials
echo "[2/7] Generating crypto materials..."
cryptogen generate --config=./crypto-config.yaml --output=crypto-config

if [ ! -d "crypto-config" ]; then
    echo "ERROR: Failed to generate crypto materials"
    exit 1
fi

# Generate genesis block
echo "[3/7] Generating genesis block..."
configtxgen -profile PostalOrdererGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

# Generate channel configuration transaction
echo "[4/7] Generating channel configuration..."
configtxgen -profile PostalServicesChannel -outputCreateChannelTx ./channel-artifacts/postalservices.tx -channelID postalservices

# Generate anchor peer updates
echo "[5/7] Generating anchor peer updates..."
configtxgen -profile PostalServicesChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID postalservices -asOrg Org1MSP
configtxgen -profile PostalServicesChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID postalservices -asOrg Org2MSP

# Start the network
echo "[6/7] Starting Docker containers..."
docker-compose up -d

# Wait for containers to start
echo "Waiting for containers to initialize..."
sleep 10

# Create and join channel
echo "[7/7] Creating and joining channel..."

# Create channel
docker exec cli peer channel create -o orderer.postal.com:7050 \
    -c postalservices \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/postalservices.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem

# Join Nairobi peer (Org1)
docker exec cli peer channel join -b postalservices.block

# Join Atlanta peer (Org1)
docker exec -e CORE_PEER_ADDRESS=peer-atlanta.org1.postal.com:8051 \
    -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-atlanta.org1.postal.com/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-atlanta.org1.postal.com/tls/server.key \
    cli peer channel join -b postalservices.block

# Join Singapore peer (Org2)
docker exec -e CORE_PEER_ADDRESS=peer-singapore.org2.postal.com:9051 \
    -e CORE_PEER_LOCALMSPID=Org2MSP \
    -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/users/Admin@org2.postal.com/msp \
    cli peer channel join -b postalservices.block

# Update anchor peers
docker exec cli peer channel update -o orderer.postal.com:7050 \
    -c postalservices \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/Org1MSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem

docker exec -e CORE_PEER_ADDRESS=peer-singapore.org2.postal.com:9051 \
    -e CORE_PEER_LOCALMSPID=Org2MSP \
    -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/users/Admin@org2.postal.com/msp \
    cli peer channel update -o orderer.postal.com:7050 \
    -c postalservices \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/Org2MSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem

echo ""
echo "=========================================="
echo "  Network started successfully!"
echo "=========================================="
echo ""
echo "Channel: postalservices"
echo "Peers:"
echo "  - peer-nairobi.org1.postal.com:7051 (Org1)"
echo "  - peer-atlanta.org1.postal.com:8051 (Org1)"
echo "  - peer-singapore.org2.postal.com:9051 (Org2)"
echo ""
echo "Next: Run ./deployChaincode.sh to deploy the chaincode"
