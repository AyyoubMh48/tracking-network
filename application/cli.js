'use strict';

const { Gateway, Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const path = require('path');
const fs = require('fs');

// Connection profile path
const ccpPath = path.resolve(__dirname, '..', 'network', 'connection-org1.json');
const walletPath = path.join(__dirname, 'wallet');

function printUsage() {
    console.log(`
Postal Tracking Network CLI
===========================

Commands:
  create-user <username> [role]     Create a new postal employee (role: client|employee)
  create-parcel <id> <destination>  Create a new parcel
  transport <id> <new-address>      Move parcel to a new address
  change-status <id> <status>       Change parcel status (GOOD|DAMAGED|DESTROYED)
  query <id>                        Query parcel information

Examples:
  node cli.js create-user john employee
  node cli.js create-parcel PKG001 "123 Main St, Atlanta"
  node cli.js transport PKG001 "456 Oak Ave, Nairobi"
  node cli.js change-status PKG001 DAMAGED
  node cli.js query PKG001
`);
}

async function createUser(userId, userRole = 'client') {
    try {
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
        const caURL = ccp.certificateAuthorities['ca.org1.postal.com'].url;
        const ca = new FabricCAServices(caURL);
        
        const wallet = await Wallets.newFileSystemWallet(walletPath);

        // Check if user already exists
        const userIdentity = await wallet.get(userId);
        if (userIdentity) {
            console.log(`User "${userId}" already exists in the wallet`);
            return;
        }

        // Get admin identity
        const adminIdentity = await wallet.get('admin');
        if (!adminIdentity) {
            console.log('Admin identity not found. Run "node enrollAdmin.js" first.');
            return;
        }

        const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
        const adminUser = await provider.getUserContext(adminIdentity, 'admin');

        // Register the user
        const secret = await ca.register({
            affiliation: 'org1.department1',
            enrollmentID: userId,
            role: 'client',
            attrs: [
                { name: 'role', value: userRole, ecert: true },
                { name: 'postalEmployee', value: (userRole === 'employee').toString(), ecert: true }
            ]
        }, adminUser);

        // Enroll the user
        const enrollment = await ca.enroll({
            enrollmentID: userId,
            enrollmentSecret: secret
        });

        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: 'Org1MSP',
            type: 'X.509',
        };

        await wallet.put(userId, x509Identity);
        console.log(`Successfully created user "${userId}" with role "${userRole}"`);

    } catch (error) {
        console.error(`Failed to create user: ${error}`);
    }
}

async function connectToNetwork(userId = 'postalWorker') {
    // Check connection profile
    if (!fs.existsSync(ccpPath)) {
        throw new Error(`Connection profile not found at ${ccpPath}. Make sure the network is running.`);
    }

    const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    // Check if user exists
    const identity = await wallet.get(userId);
    if (!identity) {
        throw new Error(`User "${userId}" not found. Run "node cli.js create-user ${userId} employee" first.`);
    }

    const gateway = new Gateway();
    await gateway.connect(ccp, {
        wallet,
        identity: userId,
        discovery: { enabled: false }
    });

    const network = await gateway.getNetwork('postalservices');
    const contract = network.getContract('postal');

    return { gateway, contract, network };
}

async function createParcel(parcelId, destination) {
    let gateway;
    try {
        const connection = await connectToNetwork();
        gateway = connection.gateway;
        
        const result = await connection.contract.submitTransaction('createParcel', parcelId, destination);
        console.log('Parcel created successfully:');
        console.log(JSON.parse(result.toString()));
    } catch (error) {
        console.error(`Failed to create parcel: ${error.message}`);
    } finally {
        if (gateway) gateway.disconnect();
    }
}

async function transportParcel(parcelId, newAddress) {
    let gateway;
    try {
        const connection = await connectToNetwork();
        gateway = connection.gateway;

        // Listen for Distribution event
        await connection.contract.addContractListener(async (event) => {
            if (event.eventName === 'Distribution') {
                const eventData = JSON.parse(event.payload.toString());
                console.log('\n*** DISTRIBUTION EVENT ***');
                console.log(`Parcel ${eventData.id}: ${eventData.msg}`);
            }
        });

        const result = await connection.contract.submitTransaction('transport', parcelId, newAddress);
        console.log('Parcel transported successfully:');
        console.log(JSON.parse(result.toString()));
    } catch (error) {
        console.error(`Failed to transport parcel: ${error.message}`);
    } finally {
        if (gateway) gateway.disconnect();
    }
}

async function changeStatus(parcelId, newStatus) {
    let gateway;
    try {
        // Validate status
        const validStatuses = ['GOOD', 'DAMAGED', 'DESTROYED'];
        if (!validStatuses.includes(newStatus.toUpperCase())) {
            console.error(`Invalid status. Must be one of: ${validStatuses.join(', ')}`);
            return;
        }

        const connection = await connectToNetwork();
        gateway = connection.gateway;
        
        const result = await connection.contract.submitTransaction('changeStatus', parcelId, newStatus.toUpperCase());
        console.log('Status changed successfully:');
        console.log(JSON.parse(result.toString()));
    } catch (error) {
        console.error(`Failed to change status: ${error.message}`);
    } finally {
        if (gateway) gateway.disconnect();
    }
}

async function queryParcel(parcelId) {
    let gateway;
    try {
        const connection = await connectToNetwork();
        gateway = connection.gateway;
        
        const result = await connection.contract.evaluateTransaction('queryParcel', parcelId);
        console.log('Parcel information:');
        console.log(JSON.parse(result.toString()));
    } catch (error) {
        console.error(`Failed to query parcel: ${error.message}`);
    } finally {
        if (gateway) gateway.disconnect();
    }
}

async function main() {
    const args = process.argv.slice(2);
    const command = args[0];

    if (!command) {
        printUsage();
        return;
    }

    switch (command) {
        case 'create-user':
            if (!args[1]) {
                console.error('Usage: node cli.js create-user <username> [role]');
                return;
            }
            await createUser(args[1], args[2] || 'employee');
            break;

        case 'create-parcel':
            if (!args[1] || !args[2]) {
                console.error('Usage: node cli.js create-parcel <id> <destination>');
                return;
            }
            await createParcel(args[1], args[2]);
            break;

        case 'transport':
            if (!args[1] || !args[2]) {
                console.error('Usage: node cli.js transport <id> <new-address>');
                return;
            }
            await transportParcel(args[1], args[2]);
            break;

        case 'change-status':
            if (!args[1] || !args[2]) {
                console.error('Usage: node cli.js change-status <id> <status>');
                console.error('Valid statuses: GOOD, DAMAGED, DESTROYED');
                return;
            }
            await changeStatus(args[1], args[2]);
            break;

        case 'query':
            if (!args[1]) {
                console.error('Usage: node cli.js query <id>');
                return;
            }
            await queryParcel(args[1]);
            break;

        default:
            console.error(`Unknown command: ${command}`);
            printUsage();
    }
}

main();