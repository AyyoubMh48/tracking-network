'use strict';

const { Contract } = require('fabric-contract-api');

class PostalContract extends Contract {

    async initLedger(ctx) {
        // Optional: Init with dummy data if needed
    }

    async createParcel(ctx, parcelId, destination) {
        const parcel = {
            docType: 'parcel',
            id: parcelId,
            destination: destination,
            currentAddress: 'Sorting Center',
            status: 'GOOD',
            owner: ctx.clientIdentity.getID()
        };
        await ctx.stub.putState(parcelId, Buffer.from(JSON.stringify(parcel)));
        return JSON.stringify(parcel);
    }

    async transport(ctx, parcelId, newAddress) {
        const parcelBytes = await ctx.stub.getState(parcelId);
        if (!parcelBytes || parcelBytes.length === 0) {
            throw new Error(`${parcelId} does not exist`);
        }
        
        const parcel = JSON.parse(parcelBytes.toString());
        parcel.currentAddress = newAddress;

        if (newAddress === parcel.destination) {
            ctx.stub.setEvent('Distribution', Buffer.from(JSON.stringify({
                id: parcelId,
                msg: 'Delivered'
            })));
        }

        await ctx.stub.putState(parcelId, Buffer.from(JSON.stringify(parcel)));
        return JSON.stringify(parcel);
    }

    async changeStatus(ctx, parcelId, newStatus) {
        const parcelBytes = await ctx.stub.getState(parcelId);
        if (!parcelBytes || parcelBytes.length === 0) {
            throw new Error(`${parcelId} does not exist`);
        }
        
        const parcel = JSON.parse(parcelBytes.toString());
        
        // Validation: Logic cannot be reversed
        if (parcel.status === 'DESTROYED') throw new Error('Parcel is DESTROYED');
        if (parcel.status === 'DAMAGED' && newStatus === 'GOOD') throw new Error('Cannot repair DAMAGED parcel');

        parcel.status = newStatus;
        await ctx.stub.putState(parcelId, Buffer.from(JSON.stringify(parcel)));
        return JSON.stringify(parcel);
    }
    
    async queryParcel(ctx, parcelId) {
        const parcelBytes = await ctx.stub.getState(parcelId);
        if (!parcelBytes || parcelBytes.length === 0) {
            throw new Error(`${parcelId} does not exist`);
        }
        return parcelBytes.toString();
    }
}

module.exports = PostalContract;