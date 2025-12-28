# 🌙 ZKT Campaign Pool - V1 (Mainnet Ready)

> A decentralized donation platform for managing charity campaigns with transparent fund allocation and NFT-based donation receipts.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Contracts](#contracts)
- [Installation](#installation)
- [Deployment](#deployment)
- [Complete Usage Flow](#complete-usage-flow)
- [NFT Receipt System](#nft-receipt-system)
- [Testing](#testing)
- [Security](#security)
- [API Reference](#api-reference)

---

## 🎯 Overview

ZKT V1 is a **production-ready smart contract system** for managing transparent charity campaigns on EVM blockchains. It enables:

- **Campaign Creation**: Admin creates time-bound fundraising campaigns
- **NGO Allocation**: Percentage-based fund distribution to approved NGOs
- **Transparent Donations**: Public, trackable USDC donations
- **Automatic NFT Receipts**: Soulbound NFTs minted on every donation
- **IPFS Reporting**: Post-campaign reports and photos via Pinata
- **Secure Disbursement**: One-time fund distribution to NGO wallets

### Use Cases

- 🌍 **Emergency Relief Campaigns** (e.g., Gaza, Palestine, natural disasters)
- 🕌 **Seasonal Charity Drives** (e.g., Ramadan, Zakat distribution)
- 🏥 **Medical Fundraising** (e.g., hospital equipment, treatments)
- 📚 **Educational Programs** (e.g., school supplies, scholarships)

---

## ✨ Features

### Core Functionality

✅ **Campaign Management**
- Time-bound campaigns with start/end dates
- Multiple campaigns running simultaneously
- Admin-controlled pause/unpause for emergencies

✅ **Multi-NGO Support**
- Approve trusted NGO partners
- Percentage-based allocation (Basis Points system)
- Must total exactly 100% before accepting donations

✅ **Donation System**
- ERC20 token donations (USDC, IDRX, etc.)
- Automatic NFT receipt minting per donation
- Time-window validation (only within campaign period)

✅ **NFT Receipts (Soulbound)**
- Immutable proof of donation
- Non-transferable (soul-bound)
- IPFS metadata with campaign reports/photos
- Admin-updatable metadata post-campaign

✅ **Transparent Disbursement**
- One-time distribution per campaign
- Automatic percentage calculation
- Event logs for full transparency

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ZKT Campaign System                      │
└─────────────────────────────────────────────────────────────┘

    [Admin/Multisig]
           │
           ├──────────────┐
           ▼              ▼
    ┌─────────────┐  ┌──────────────┐
    │   Create    │  │   Approve    │
    │  Campaign   │  │     NGOs     │
    └─────────────┘  └──────────────┘
           │              │
           └──────┬───────┘
                  ▼
         ┌─────────────────┐
         │ Set Allocation  │
         │  (NGO %, BPS)   │
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │ Lock Allocation │
         │   (Must = 100%) │
         └─────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
[Donor A]    [Donor B]    [Donor C]
    │             │             │
    └─────────────┼─────────────┘
                  ▼
         ┌─────────────────┐
         │  donate()       │
         │  • Transfer $   │
         │  • Mint NFT 🎫  │
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │   Campaign      │
         │   Completes     │
         └─────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
  [NGO 1]      [NGO 2]      [NGO 3]
   60%          25%          15%
    │             │             │
    └─────────────┼─────────────┘
                  ▼
         ┌─────────────────┐
         │   disburse()    │
         │ (Admin triggers)│
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │ Upload Reports  │
         │   to Pinata 📁  │
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  Update NFT     │
         │   Metadata 🏷️   │
         └─────────────────┘
```

---

## 📜 Contracts

### 1. ZKTCampaignPool.sol

**Main contract** managing campaigns, donations, and disbursements.

**Key Components:**
- Campaign creation with time windows
- NGO approval and allocation management
- Donation acceptance with NFT minting
- Fund disbursement to NGOs
- Admin controls (pause, transfer)

**State Variables:**
```solidity
address public admin;                     // Multisig admin address
IERC20 public immutable token;           // USDC or other stablecoin
IZKTReceiptNFT public immutable receiptNFT; // Receipt NFT contract
bool public paused;                      // Emergency pause
```

**Campaign Structure:**
```solidity
struct Campaign {
    bool exists;           // Campaign exists
    bool allocationLocked; // Allocation finalized (100%)
    bool disbursed;        // Funds distributed
    bool closed;           // Campaign manually closed
    uint256 totalRaised;   // Total donations
    uint256 startTime;     // Campaign start (Unix timestamp)
    uint256 endTime;       // Campaign end (Unix timestamp)
}
```

### 2. ZKTReceiptNFT.sol

**Soulbound NFT** contract for donation receipts.

**Key Features:**
- ERC721 standard with transfer blocking
- Stores donation metadata on-chain
- IPFS integration for reports/photos
- Admin-updatable metadata

**Receipt Metadata:**
```solidity
struct ReceiptData {
    bytes32 campaignId;  // Which campaign
    address donor;       // Who donated
    uint256 amount;      // How much
    uint256 timestamp;   // When
    string ipfsCID;      // Pinata folder CID
    bool isImpact;       // Donation vs Impact distribution
}
```

### 3. TestUSDC.sol

**Mock USDC** for testing purposes.

---

## 🚀 Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Setup

```bash
# Clone repository
git clone https://github.com/yourusername/zkt-sc.git
cd zkt-sc/v1

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test -vvv
# Run tests
forge test -vvv
```

---

## 🌐 Deployment

### 1. Configure Environment

Create `.env` file:

```bash
# Network RPC
RPC_URL=https://base-sepolia.blockpi.network/v1/rpc/public

# Deployer wallet
PRIVATE_KEY=your_private_key_here

# Admin (multisig recommended for production)
ADMIN_ADDRESS=0x1234...YourMultisigAddress

# USDC address (or use TestUSDC for testnets)
USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913  # Base mainnet
```

### 2. Run Deployment Script

```bash
# Deploy to testnet (Base Sepolia)
./deploy.sh

# Or manually:
forge script script/deployzkt.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### 3. Post-Deployment Setup

```bash
# Save deployed addresses
export POOL_ADDRESS=<ZKTCampaignPool address>
export NFT_ADDRESS=<ZKTReceiptNFT address>

# Set Pool as NFT minter
cast send $NFT_ADDRESS \
  "setMinter(address)" \
  $POOL_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 📖 Complete Usage Flow

### STEP 1: Create Campaign

```bash
# Generate campaign ID from name
CAMPAIGN_NAME="RAMADAN-2025"
CAMPAIGN_ID=$(cast keccak "$CAMPAIGN_NAME")

# Set time range (Unix timestamps)
START_TIME=$(date -d "2025-03-01 00:00:00 UTC" +%s)
END_TIME=$(date -d "2025-03-31 23:59:59 UTC" +%s)

# Create campaign
cast send $POOL_ADDRESS \
  "createCampaign(bytes32,uint256,uint256)" \
  $CAMPAIGN_ID \
  $START_TIME \
  $END_TIME \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### STEP 2: Approve NGOs

```bash
# Approve NGO 1
NGO1_ID=$(cast keccak "PALESTINE-RELIEF")
NGO1_WALLET="0x1234...NGO1Address"

cast send $POOL_ADDRESS \
  "approveNGO(bytes32,address)" \
  $NGO1_ID \
  $NGO1_WALLET \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Approve NGO 2
NGO2_ID=$(cast keccak "GAZA-EMERGENCY")
NGO2_WALLET="0x5678...NGO2Address"

cast send $POOL_ADDRESS \
  "approveNGO(bytes32,address)" \
  $NGO2_ID \
  $NGO2_WALLET \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### STEP 3: Set Allocation (Basis Points)

```bash
# Allocate 60% (6000 BPS) to NGO1
cast send $POOL_ADDRESS \
  "setAllocation(bytes32,bytes32,uint256)" \
  $CAMPAIGN_ID \
  $NGO1_ID \
  6000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Allocate 40% (4000 BPS) to NGO2
cast send $POOL_ADDRESS \
  "setAllocation(bytes32,bytes32,uint256)" \
  $CAMPAIGN_ID \
  $NGO2_ID \
  4000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Basis Points (BPS) Reference:**
- 100% = 10,000 BPS
- 60% = 6,000 BPS
- 25% = 2,500 BPS
- 1% = 100 BPS

### STEP 4: Lock Allocation

```bash
# Lock allocation (must total exactly 10,000 BPS)
cast send $POOL_ADDRESS \
  "lockAllocation(bytes32)" \
  $CAMPAIGN_ID \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

⚠️ **Warning**: This is irreversible! Ensure allocation is correct.

### STEP 5: Donors Donate (NFT Auto-Minted)

```bash
# Donor approves USDC
cast send $USDC_ADDRESS \
  "approve(address,uint256)" \
  $POOL_ADDRESS \
  1000000000 \
  --rpc-url $RPC_URL \
  --private-key $DONOR_PRIVATE_KEY

# Donor donates 1000 USDC (1000 * 10^6 for 6 decimals)
cast send $POOL_ADDRESS \
  "donate(bytes32,uint256)" \
  $CAMPAIGN_ID \
  1000000000 \
  --rpc-url $RPC_URL \
  --private-key $DONOR_PRIVATE_KEY
```

**What happens automatically:**
1. ✅ USDC transferred from donor to pool
2. ✅ `totalRaised` incremented
3. ✅ **NFT minted to donor** (soulbound, IPFS CID empty)
4. ✅ Event emitted with token ID

### STEP 6: Upload Reports to Pinata (Off-Chain)

After campaign ends, NGO uploads documentation:

**Folder structure:**
```
/ramadan-2025-report/
  ├── summary.pdf
  ├── financial_report.xlsx
  ├── photos/
  │   ├── distribution_1.jpg
  │   ├── distribution_2.jpg
  │   └── beneficiaries.jpg
  └── metadata.json
```

**Get Pinata CID:**
```
QmPinataFolderCIDWithReportsAndImages123abc
```

### STEP 7: Update NFT Metadata

```bash
# Single NFT update
cast send $POOL_ADDRESS \
  "updateReceiptMetadata(uint256,string)" \
  1 \
  "QmPinataFolderCIDWithReportsAndImages123abc" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Batch update (recommended)
cast send $POOL_ADDRESS \
  "batchUpdateReceiptMetadata(uint256[],string)" \
  "[1,2,3,4,5]" \
  "QmPinataFolderCIDWithReportsAndImages123abc" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

Or use the helper script:

```bash
export PINATA_CID="QmPinataFolderCIDWithReportsAndImages123abc"
forge script script/UpdateNFTMetadata.s.sol --rpc-url $RPC_URL --broadcast
```

### STEP 8: Disburse Funds to NGOs

```bash
# Disburse to all NGOs
cast send $POOL_ADDRESS \
  "disburse(bytes32,bytes32[])" \
  $CAMPAIGN_ID \
  "[$NGO1_ID,$NGO2_ID]" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Example** (10,000 USDC raised):
- NGO1 (60%): receives 6,000 USDC
- NGO2 (40%): receives 4,000 USDC

### STEP 9: Close Campaign (Optional)

```bash
cast send $POOL_ADDRESS \
  "closeCampaign(bytes32)" \
  $CAMPAIGN_ID \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 🎫 NFT Receipt System

### Design

- **Soulbound**: Cannot be transferred (proof of donation)
- **Auto-Minted**: One NFT per `donate()` call
- **Metadata**: Initially empty, updated post-campaign
- **IPFS Integration**: Links to Pinata folder with reports

### Token URI Structure

```json
{
  "name": "ZKT Donation Receipt #1",
  "description": "Proof of donation to RAMADAN-2025 campaign",
  "image": "ipfs://QmPinata.../thumbnail.jpg",
  "external_url": "https://ipfs.io/ipfs/QmPinata...",
  "attributes": [
    {
      "trait_type": "Campaign ID",
      "value": "0x1234...campaignId"
    },
    {
      "trait_type": "Amount",
      "value": "1000 USDC"
    },
    {
      "trait_type": "Timestamp",
      "value": 1709251200
    }
  ]
}
```

### Viewing NFTs

Donors can view their receipts on:
- OpenSea
- Rarible
- Any ERC721-compatible wallet

---

## 🧪 Testing

### Run All Tests

```bash
forge test -vvv
```

### Test Coverage

```bash
forge coverage
```

### Specific Test

```bash
forge test --match-test testDonateMintsNFT -vvv
```

### Test Scenarios Covered

✅ Campaign creation and validation  
✅ NGO approval and allocation  
✅ Allocation locking (must be 100%)  
✅ Donation with NFT minting  
✅ Metadata updates (single & batch)  
✅ Disbursement calculations  
✅ Pause/unpause functionality  
✅ Admin transfer  
✅ Error cases and edge conditions  

---

## 🔒 Security

### Access Control

- **Admin Only**: Campaign creation, NGO approval, allocation, disbursement
- **Public**: Donations (anyone can donate during campaign window)
- **Admin Transfer**: Can transfer admin to multisig

### Safety Features

1. **Reentrancy Protection**: Pull-over-push pattern
2. **Time Validation**: Strict timestamp checks
3. **Allocation Validation**: Must be exactly 100%
4. **One-Time Operations**: Lock allocation & disburse are irreversible
5. **Pause Mechanism**: Emergency stop for donations
6. **Soulbound NFTs**: Cannot be traded or scammed

### Recommendations for Production

✅ Use a **multisig wallet** for admin (e.g., Safe)  
✅ Deploy on **audited infrastructure** (Base, Arbitrum, Polygon)  
✅ Test extensively on **testnets** first  
✅ Consider **timelock** for admin actions  
✅ Set up **monitoring** for critical events  
✅ Have **emergency procedures** documented  

---

## 📚 API Reference

### Campaign Functions

#### `createCampaign(bytes32 campaignId, uint256 startTime, uint256 endTime)`
Create a new campaign.
- **Access**: Admin only
- **Params**: Campaign ID (keccak256 hash), start/end Unix timestamps
- **Events**: `CampaignCreated`

#### `closeCampaign(bytes32 campaignId)`
Manually close a campaign.
- **Access**: Admin only
- **Events**: `CampaignClosed`

### NGO Functions

#### `approveNGO(bytes32 ngoId, address wallet)`
Approve an NGO partner.
- **Access**: Admin only
- **Params**: NGO ID (keccak256 hash), wallet address

### Allocation Functions

#### `setAllocation(bytes32 campaignId, bytes32 ngoId, uint256 bps)`
Set percentage allocation for an NGO.
- **Access**: Admin only
- **Params**: Campaign ID, NGO ID, basis points (0-10000)
- **Validation**: Total ≤ 10,000 BPS

#### `lockAllocation(bytes32 campaignId)`
Lock allocation (must be exactly 100%).
- **Access**: Admin only
- **Validation**: `totalBps[campaignId] == 10,000`

### Donation Functions

#### `donate(bytes32 campaignId, uint256 amount)`
Donate to a campaign.
- **Access**: Public
- **Params**: Campaign ID, amount (in token decimals)
- **Requirements**: Campaign active, allocation locked
- **Side Effects**: Mints NFT receipt
- **Events**: `Donated(campaignId, donor, amount, tokenId)`

### Disbursement Functions

#### `disburse(bytes32 campaignId, bytes32[] calldata ngoIds)`
Distribute funds to NGOs.
- **Access**: Admin only
- **Params**: Campaign ID, array of NGO IDs
- **Validation**: Not already disbursed
- **Events**: `Disbursed(campaignId, ngoId, amount)` per NGO

### NFT Functions

#### `updateReceiptMetadata(uint256 tokenId, string calldata pinataCID)`
Update IPFS CID for a single NFT.
- **Access**: Admin only
- **Params**: Token ID, Pinata CID

#### `batchUpdateReceiptMetadata(uint256[] calldata tokenIds, string calldata pinataCID)`
Batch update IPFS CID for multiple NFTs.
- **Access**: Admin only
- **Params**: Array of token IDs, Pinata CID

### Admin Functions

#### `transferAdmin(address newAdmin)`
Transfer admin role.
- **Access**: Admin only
- **Events**: `AdminTransferred`

#### `pause()` / `unpause()`
Emergency pause/unpause donations and disbursements.
- **Access**: Admin only
- **Events**: `Paused` / `Unpaused`

### Query Functions (View)

```solidity
// Campaign data
campaigns(bytes32 campaignId) → Campaign

// NGO approval
approvedNGO(bytes32 ngoId) → bool
ngoWallet(bytes32 ngoId) → address

// Allocation
allocationBps(bytes32 campaignId, bytes32 ngoId) → uint256
totalBps(bytes32 campaignId) → uint256
```

---

## 🛠️ Helper Scripts

### Query Campaign Total

```bash
./get_campaign_total.sh "RAMADAN-2025"
```

### Update NFT Metadata

```bash
# Single update
forge script script/UpdateNFTMetadata.s.sol \
  --sig "updateSingle()" \
  --rpc-url $RPC_URL \
  --broadcast

# Batch update
forge script script/UpdateNFTMetadata.s.sol \
  --rpc-url $RPC_URL \
  --broadcast
```

---

## 🌟 Examples

### Complete Campaign Script

```bash
#!/bin/bash
# complete_campaign_flow.sh

# 1. CREATE CAMPAIGN
CAMPAIGN_ID=$(cast keccak "RAMADAN-2025")
cast send $POOL_ADDRESS "createCampaign(bytes32,uint256,uint256)" \
  $CAMPAIGN_ID 1709251200 1711929599 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# 2. APPROVE NGOs
NGO1_ID=$(cast keccak "PALESTINE-RELIEF")
NGO2_ID=$(cast keccak "GAZA-EMERGENCY")
cast send $POOL_ADDRESS "approveNGO(bytes32,address)" $NGO1_ID $NGO1_WALLET \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send $POOL_ADDRESS "approveNGO(bytes32,address)" $NGO2_ID $NGO2_WALLET \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# 3. SET ALLOCATION (60% + 40%)
cast send $POOL_ADDRESS "setAllocation(bytes32,bytes32,uint256)" \
  $CAMPAIGN_ID $NGO1_ID 6000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send $POOL_ADDRESS "setAllocation(bytes32,bytes32,uint256)" \
  $CAMPAIGN_ID $NGO2_ID 4000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# 4. LOCK ALLOCATION
cast send $POOL_ADDRESS "lockAllocation(bytes32)" $CAMPAIGN_ID \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Campaign is now ready for donations!
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 📞 Support

- **Documentation**: [ZKT_FLOW_DOCUMENTATION.md](../ZKT_FLOW_DOCUMENTATION.md)
- **NFT Flow**: [NFT_RECEIPT_FLOW.md](NFT_RECEIPT_FLOW.md)
- **Issues**: [GitHub Issues](https://github.com/yourusername/zkt-sc/issues)

---

## 🙏 Acknowledgments

Built with:
- [Foundry](https://getfoundry.sh/) - Smart contract development framework
- [OpenZeppelin](https://openzeppelin.com/) - Secure contract libraries
- [Pinata](https://pinata.cloud/) - IPFS infrastructure

---

**Made with ❤️ for transparent charity and humanitarian aid**
