#!/bin/bash

set -e

echo "=========================================="
echo "  Deploying Postal Chaincode"
echo "=========================================="

cd "$(dirname "$0")"

CHANNEL_NAME="postalservices"
CC_NAME="postal"
CC_VERSION="1.0"
CC_SEQUENCE="1"
CC_SRC_PATH="/opt/gopath/src/github.com/chaincode"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem"

# Package chaincode
echo "[1/6] Packaging chaincode..."
docker exec cli peer lifecycle chaincode package postal.tar.gz \
    --path ${CC_SRC_PATH} \
    --lang node \
    --label postal_${CC_VERSION}

# Install on Nairobi (Org1)
echo "[2/6] Installing chaincode on peer-nairobi (Org1)..."
docker exec cli peer lifecycle chaincode install postal.tar.gz

# Install on Atlanta (Org1)
echo "[3/6] Installing chaincode on peer-atlanta (Org1)..."
docker exec -e CORE_PEER_ADDRESS=peer-atlanta.org1.postal.com:8051 \
    -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-atlanta.org1.postal.com/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-atlanta.org1.postal.com/tls/server.key \
    cli peer lifecycle chaincode install postal.tar.gz

# Install on Singapore (Org2)
echo "[4/6] Installing chaincode on peer-singapore (Org2)..."
docker exec -e CORE_PEER_ADDRESS=peer-singapore.org2.postal.com:9051 \
    -e CORE_PEER_LOCALMSPID=Org2MSP \
    -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/users/Admin@org2.postal.com/msp \
    cli peer lifecycle chaincode install postal.tar.gz

# Get package ID
echo "[5/6] Getting package ID and approving chaincode..."
PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "postal_${CC_VERSION}" | sed -n 's/.*Package ID: \(.*\), Label.*/\1/p')
echo "Package ID: ${PACKAGE_ID}"

# Approve for Org1
docker exec cli peer lifecycle chaincode approveformyorg \
    -o orderer.postal.com:7050 \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --tls --cafile ${ORDERER_CA}

# Approve for Org2
docker exec -e CORE_PEER_ADDRESS=peer-singapore.org2.postal.com:9051 \
    -e CORE_PEER_LOCALMSPID=Org2MSP \
    -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/users/Admin@org2.postal.com/msp \
    cli peer lifecycle chaincode approveformyorg \
    -o orderer.postal.com:7050 \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --tls --cafile ${ORDERER_CA}

# Commit chaincode
echo "[6/6] Committing chaincode definition..."
docker exec cli peer lifecycle chaincode commit \
    -o orderer.postal.com:7050 \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --tls --cafile ${ORDERER_CA} \
    --peerAddresses peer-nairobi.org1.postal.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-nairobi.org1.postal.com/tls/ca.crt \
    --peerAddresses peer-singapore.org2.postal.com:9051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt

echo ""
echo "=========================================="
echo "  Chaincode deployed successfully!"
echo "=========================================="
echo ""
echo "Chaincode: ${CC_NAME}"
echo "Version: ${CC_VERSION}"
echo "Channel: ${CHANNEL_NAME}"
echo ""
echo "Next: Run the application CLI commands"
