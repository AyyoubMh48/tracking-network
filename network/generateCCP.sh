#!/bin/bash

# This script generates the connection profile with embedded certificates

NETWORK_DIR="$(dirname "$0")"
CRYPTO_DIR="$NETWORK_DIR/crypto-config"

# Read certificates
TLS_CA_CERT=$(cat "$CRYPTO_DIR/peerOrganizations/org1.postal.com/tlsca/tlsca.org1.postal.com-cert.pem" | sed ':a;N;$!ba;s/\n/\\n/g')
TLS_CA_CERT_ORG2=$(cat "$CRYPTO_DIR/peerOrganizations/org2.postal.com/tlsca/tlsca.org2.postal.com-cert.pem" | sed ':a;N;$!ba;s/\n/\\n/g')
CA_CERT=$(cat "$CRYPTO_DIR/peerOrganizations/org1.postal.com/ca/ca.org1.postal.com-cert.pem" | sed ':a;N;$!ba;s/\n/\\n/g')
CA_CERT_ORG2=$(cat "$CRYPTO_DIR/peerOrganizations/org2.postal.com/ca/ca.org2.postal.com-cert.pem" | sed ':a;N;$!ba;s/\n/\\n/g')

# Generate connection profile
cat > "$NETWORK_DIR/connection-org1.json" << EOF
{
    "name": "postal-network",
    "version": "1.0.0",
    "client": {
        "organization": "Org1",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "Org1": {
            "mspid": "Org1MSP",
            "peers": [
                "peer-nairobi.org1.postal.com",
                "peer-atlanta.org1.postal.com"
            ],
            "certificateAuthorities": [
                "ca.org1.postal.com"
            ]
        },
        "Org2": {
            "mspid": "Org2MSP",
            "peers": [
                "peer-singapore.org2.postal.com"
            ],
            "certificateAuthorities": [
                "ca.org2.postal.com"
            ]
        }
    },
    "peers": {
        "peer-nairobi.org1.postal.com": {
            "url": "grpcs://localhost:7051",
            "tlsCACerts": {
                "pem": "$TLS_CA_CERT"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer-nairobi.org1.postal.com",
                "hostnameOverride": "peer-nairobi.org1.postal.com"
            }
        },
        "peer-atlanta.org1.postal.com": {
            "url": "grpcs://localhost:8051",
            "tlsCACerts": {
                "pem": "$TLS_CA_CERT"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer-atlanta.org1.postal.com",
                "hostnameOverride": "peer-atlanta.org1.postal.com"
            }
        },
        "peer-singapore.org2.postal.com": {
            "url": "grpcs://localhost:9051",
            "tlsCACerts": {
                "pem": "$TLS_CA_CERT_ORG2"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer-singapore.org2.postal.com",
                "hostnameOverride": "peer-singapore.org2.postal.com"
            }
        }
    },
    "certificateAuthorities": {
        "ca.org1.postal.com": {
            "url": "https://localhost:7054",
            "caName": "ca-org1",
            "tlsCACerts": {
                "pem": ["$CA_CERT"]
            },
            "httpOptions": {
                "verify": false
            }
        },
        "ca.org2.postal.com": {
            "url": "https://localhost:8054",
            "caName": "ca-org2",
            "tlsCACerts": {
                "pem": ["$CA_CERT_ORG2"]
            },
            "httpOptions": {
                "verify": false
            }
        }
    }
}
EOF

echo "Connection profile generated successfully!"
