# TradeTrek Marketplace

A decentralized marketplace contract that enables peer-to-peer trading in niche markets with built-in escrow and dispute resolution.

## Features
- Secure escrow system for trades
- Seller reputation tracking
- Listing management
- Purchase history tracking
- Dispute resolution mechanism
- Delivery confirmation system
- Protected buyer and seller funds

## Escrow System
The marketplace now includes a robust escrow system that:
- Holds buyer funds securely during transactions
- Releases funds to seller after delivery confirmation
- Supports dispute resolution with mediation
- Allows refunds through administrator intervention
- Implements time-locked dispute window (24 hours)

## Getting Started
1. Clone the repository
2. Install Clarinet
3. Run tests using `clarinet test`

## Smart Contract Functions
- `create-listing`: Create a new item listing
- `purchase-item`: Purchase an item (funds go to escrow)
- `confirm-delivery`: Confirm receipt and release funds
- `open-dispute`: Open a dispute within time window
- `resolve-dispute`: Resolve dispute (admin only)
- `rate-seller`: Rate a seller's performance

## Safety Features
- Protected escrow accounts
- Time-locked dispute window
- Admin-controlled dispute resolution
- Automatic fee handling
- Secure fund transfers
