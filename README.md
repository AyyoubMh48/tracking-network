# Postal Parcel Tracking Network

A Hyperledger Fabric blockchain network for tracking postal parcels across multiple cities and organizations.

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PostalServices Channel                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      Organization 1                          │   │
│  │  ┌──────────────────┐    ┌──────────────────┐               │   │
│  │  │   Peer Nairobi   │    │   Peer Atlanta   │               │   │
│  │  │   (Port 7051)    │    │   (Port 8051)    │               │   │
│  │  └──────────────────┘    └──────────────────┘               │   │
│  │                    CA Org1 (Port 7054)                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      Organization 2                          │   │
│  │  ┌──────────────────┐                                        │   │
│  │  │  Peer Singapore  │                                        │   │
│  │  │   (Port 9051)    │                                        │   │
│  │  └──────────────────┘                                        │   │
│  │                    CA Org2 (Port 8054)                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────┐                                              │
│  │  Orderer Node    │                                              │
│  │   (Port 7050)    │                                              │
│  └──────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

### Network
- **Channel**: `postalservices`
- **Peers**: 
  - `peer-nairobi.org1.postal.com` (Org1 - City: Nairobi)
  - `peer-atlanta.org1.postal.com` (Org1 - City: Atlanta)
  - `peer-singapore.org2.postal.com` (Org2 - City: Singapore)
- **Orderer**: `orderer.postal.com` (Raft consensus)
- **Certificate Authorities**: 2 CAs (one per organization)

### Smart Contract (Chaincode)
The `postal` chaincode defines:

#### Assets
- **Parcel**: Contains `id`, `destination`, `currentAddress`, `status`, `owner`

#### Transactions
- `createParcel(id, destination)` - Create a new parcel
- `transport(id, newAddress)` - Move parcel to new address (emits "Distribution" event when delivered)
- `changeStatus(id, status)` - Change parcel status (GOOD → DAMAGED → DESTROYED, one-way only)
- `queryParcel(id)` - Query parcel information

## Prerequisites

- Docker and Docker Compose
- Node.js >= 12.x
- npm
- curl

## Quick Start (Complete Setup)

### Step 1: Install Hyperledger Fabric Binaries

```bash
# Download Fabric binaries and Docker images
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.0 1.5.2 -s

# Add binaries to PATH
export PATH=$PATH:$(pwd)/bin
```

### Step 2: Start the Network

```bash
cd network
chmod +x *.sh
./start.sh
```

**Expected Output:**
```
==========================================
  Network started successfully!
==========================================

Channel: postalservices
Peers:
  - peer-nairobi.org1.postal.com:7051 (Org1)
  - peer-atlanta.org1.postal.com:8051 (Org1)
  - peer-singapore.org2.postal.com:9051 (Org2)
```

### Step 3: Deploy Chaincode

```bash
./deployChaincode.sh
```

**Expected Output:**
```
==========================================
  Chaincode deployed successfully!
==========================================

Chaincode: postal
Version: 1.0
Channel: postalservices
```

### Step 4: Generate Connection Profile

```bash
./generateCCP.sh
```

### Step 5: Setup Application

```bash
cd ../application
npm install
```

### Step 6: Enroll Admin and Create User

```bash
# Enroll the CA admin
node enrollAdmin.js

# Create a postal employee user
node cli.js create-user postalWorker employee
```

**Expected Output:**
```
Successfully enrolled admin user "admin" and imported it into the wallet
Successfully created user "postalWorker" with role "employee"
```

## CLI Commands

All commands below use the CLI container to interact with the blockchain.

### Create User
Create a postal employee that can manage parcels:
```bash
node cli.js create-user <username> [role]

# Example:
node cli.js create-user john employee
```

### Create Parcel
```bash
docker exec cli peer chaincode invoke \
  -o orderer.postal.com:7050 --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem \
  -C postalservices -n postal \
  --peerAddresses peer-nairobi.org1.postal.com:7051 \
  --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-nairobi.org1.postal.com/tls/ca.crt \
  --peerAddresses peer-singapore.org2.postal.com:9051 \
  --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
  -c '{"function":"createParcel","Args":["PKG001","123 Main Street, Atlanta"]}'
```

**Expected Output:**
```
Chaincode invoke successful. result: status:200 payload:"{\"docType\":\"parcel\",\"id\":\"PKG001\",\"destination\":\"123 Main Street, Atlanta\",\"currentAddress\":\"Sorting Center\",\"status\":\"GOOD\"...}"
```

### Transport Parcel (Change Address)
```bash
docker exec cli peer chaincode invoke \
  -o orderer.postal.com:7050 --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem \
  -C postalservices -n postal \
  --peerAddresses peer-nairobi.org1.postal.com:7051 \
  --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-nairobi.org1.postal.com/tls/ca.crt \
  --peerAddresses peer-singapore.org2.postal.com:9051 \
  --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
  -c '{"function":"transport","Args":["PKG001","456 Oak Avenue, Singapore"]}'
```

### Change Status
```bash
docker exec cli peer chaincode invoke \
  -o orderer.postal.com:7050 --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem \
  -C postalservices -n postal \
  --peerAddresses peer-nairobi.org1.postal.com:7051 \
  --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-nairobi.org1.postal.com/tls/ca.crt \
  --peerAddresses peer-singapore.org2.postal.com:9051 \
  --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
  -c '{"function":"changeStatus","Args":["PKG001","DAMAGED"]}'
```

**Valid Statuses:** `GOOD`, `DAMAGED`, `DESTROYED`

**Status Rules (One-Way Transitions):**
| From | To | Allowed |
|------|-----|---------|
| GOOD | DAMAGED | ✅ |
| GOOD | DESTROYED | ✅ |
| DAMAGED | DESTROYED | ✅ |
| DAMAGED | GOOD | ❌ |
| DESTROYED | Any | ❌ |

### Query Parcel
```bash
docker exec cli peer chaincode query \
  -C postalservices -n postal \
  -c '{"function":"queryParcel","Args":["PKG001"]}'
```

**Expected Output:**
```json
{
  "docType": "parcel",
  "id": "PKG001",
  "destination": "123 Main Street, Atlanta",
  "currentAddress": "456 Oak Avenue, Singapore",
  "status": "DAMAGED"
}
```

## Helper Scripts

For convenience, you can create aliases or use these helper commands:

```bash
# Create parcel helper function
create_parcel() {
  docker exec cli peer chaincode invoke -o orderer.postal.com:7050 --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/postal.com/orderers/orderer.postal.com/msp/tlscacerts/tlsca.postal.com-cert.pem \
    -C postalservices -n postal \
    --peerAddresses peer-nairobi.org1.postal.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.postal.com/peers/peer-nairobi.org1.postal.com/tls/ca.crt \
    --peerAddresses peer-singapore.org2.postal.com:9051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.postal.com/peers/peer-singapore.org2.postal.com/tls/ca.crt \
    -c "{\"function\":\"createParcel\",\"Args\":[\"$1\",\"$2\"]}"
}

# Usage: create_parcel PKG001 "123 Main St"
```

## Verify Network is Running

```bash
# Check all containers are up
docker ps --format "table {{.Names}}\t{{.Status}}"

# Expected containers:
# - cli
# - peer-nairobi.org1.postal.com
# - peer-atlanta.org1.postal.com  
# - peer-singapore.org2.postal.com
# - orderer.postal.com
# - ca_org1
# - ca_org2
```

## Stop Network

```bash
cd network
./stop.sh
```

## Troubleshooting

### Error: cryptogen command not found
```bash
# Make sure Fabric binaries are in PATH
export PATH=$PATH:$(pwd)/bin
```

### Error: Docker socket permission denied
```bash
# For rootless Docker, ensure XDG_RUNTIME_DIR is set
export XDG_RUNTIME_DIR=/run/user/$(id -u)
```

### Error: Channel already exists
```bash
# Stop and clean the network first
./stop.sh
./start.sh
```

### View Chaincode Logs
```bash
docker logs dev-peer-nairobi.org1.postal.com-postal_1.0-<hash> -f
```

## Project Structure

```
tracking-network/
├── .gitignore
├── README.md
├── application/
│   ├── cli.js                  # Command line interface
│   ├── enrollAdmin.js          # Enroll CA admin
│   ├── registerUser.js         # Register new users
│   ├── package.json
│   └── wallet/                 # User credentials (gitignored)
├── chaincode/
│   ├── index.js
│   ├── package.json
│   └── lib/
│       └── postalContract.js   # Smart contract
├── bin/                        # Fabric binaries (gitignored)
├── config/                     # Fabric config (gitignored)
└── network/
    ├── configtx.yaml           # Channel configuration
    ├── crypto-config.yaml      # Crypto material config
    ├── docker-compose.yaml     # Container definitions
    ├── connection-org1.json    # Connection profile
    ├── generateCCP.sh          # Generate connection profile
    ├── start.sh                # Network startup script
    ├── stop.sh                 # Network shutdown script
    ├── deployChaincode.sh      # Chaincode deployment
    ├── crypto-config/          # Generated crypto (gitignored)
    └── channel-artifacts/      # Generated artifacts (gitignored)
```

## Events

The chaincode emits the following events:

- **Distribution**: Emitted when a parcel reaches its final destination
  ```json
  {
    "id": "PKG001",
    "msg": "Delivered"
  }
  ```

