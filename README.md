# Commodities Trading Smart Contract

A comprehensive Clarity smart contract for decentralized physical commodities trading on the Stacks blockchain. This contract enables secure peer-to-peer trading of physical commodities with built-in inventory management, dispute resolution, and delivery confirmation systems.

## Features

### Core Trading Functions
- **Create Trade Listings**: Sellers can list commodities with detailed specifications
- **Accept Trades**: Buyers can accept listings with automatic fund transfers
- **Cancel Trades**: Sellers can cancel active listings
- **Delivery Confirmation**: Buyers confirm receipt of goods
- **Dispute Resolution**: Authorized inspectors can resolve trade disputes

### Financial Management
- **User Balances**: Deposit and withdraw funds securely
- **Platform Fees**: Configurable transaction fees (default 0.25%)
- **Automatic Transfers**: Secure fund transfers between parties
- **Fee Collection**: Platform fees automatically collected on trades

### Inventory Tracking
- **Real-time Inventory**: Track commodity quantities for each user
- **Automatic Updates**: Inventory updated on trade creation/completion
- **Overselling Prevention**: Balance checks prevent invalid trades

### Security & Governance
- **Owner Controls**: Admin functions for contract management
- **Inspector Authorization**: Qualified inspectors for dispute resolution
- **Input Validation**: Comprehensive validation of all user inputs
- **Status Management**: Contract can be paused/resumed by owner

## Contract Structure

### Data Maps
- `trades`: Store trade details and status
- `user-balances`: Track user fund balances
- `commodity-inventory`: Track commodity quantities per user
- `authorized-inspectors`: Manage dispute resolution authorities

### Trade Statuses
- `ACTIVE`: Trade is available for acceptance
- `PENDING_DELIVERY`: Trade accepted, awaiting delivery
- `DELIVERED`: Trade completed successfully
- `CANCELLED`: Trade cancelled by seller
- `DISPUTED`: Trade under dispute resolution

## Usage Examples

### Creating a Trade
```clarity
(contract-call? .commodities-trading create-trade
  "WHEAT"           ;; commodity
  u1000            ;; quantity (1000 units)
  u50              ;; price per unit (50 tokens)
  u100000          ;; expires at block height
  "GRADE_A"        ;; quality grade
  "Chicago, IL"    ;; delivery location
)
```

### Accepting a Trade
```clarity
(contract-call? .commodities-trading accept-trade u1)
```

### Confirming Delivery
```clarity
(contract-call? .commodities-trading confirm-delivery u1)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `err-owner-only` | Operation requires contract owner |
| u101 | `err-not-found` | Trade or resource not found |
| u102 | `err-unauthorized` | Unauthorized access attempt |
| u103 | `err-invalid-amount` | Invalid amount or quantity |
| u104 | `err-insufficient-balance` | Insufficient funds or inventory |
| u105 | `err-trade-not-active` | Trade is not in active status |
| u106 | `err-already-exists` | Resource already exists |
| u107 | `err-invalid-status` | Invalid status transition |
| u108 | `err-delivery-failed` | Delivery confirmation failed |
| u109 | `err-invalid-input` | Input validation failed |

## Admin Functions

### Set Platform Fee
```clarity
(contract-call? .commodities-trading set-platform-fee u30) ;; 0.30%
```

### Authorize Inspector
```clarity
(contract-call? .commodities-trading authorize-inspector 'SP1ABC...)
```

### Pause/Resume Contract
```clarity
(contract-call? .commodities-trading set-contract-status false) ;; pause
(contract-call? .commodities-trading set-contract-status true)  ;; resume
```

## Read-Only Functions

### Get Trade Details
```clarity
(contract-call? .commodities-trading get-trade u1)
```

### Check User Balance
```clarity
(contract-call? .commodities-trading get-user-balance 'SP1ABC...)
```

### Check Inventory
```clarity
(contract-call? .commodities-trading get-inventory 'SP1ABC... "WHEAT")
```

### Contract Statistics
```clarity
(contract-call? .commodities-trading get-contract-stats)
```

## Security Features

- **Input Validation**: All user inputs are thoroughly validated
- **Access Control**: Role-based permissions for sensitive operations
- **Balance Checks**: Prevents overdrafts and overselling
- **Status Validation**: Ensures proper trade state transitions
- **Principal Verification**: Prevents unauthorized access to trades

## Deployment Notes

1. Deploy the contract to Stacks testnet/mainnet
2. The deploying principal becomes the contract owner
3. Set initial platform fee if different from default (0.25%)
4. Authorize inspectors for dispute resolution
5. Contract starts in active state by default

## Gas Optimization

The contract is optimized for gas efficiency:
- Minimal storage reads/writes
- Efficient data structures
- Consolidated operations where possible
- Under 300 lines for optimal deployment cost
