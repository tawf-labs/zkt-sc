# ZKT Receipt NFT Flow - Pinata Integration

## Overview
Every donation automatically mints a **soulbound (non-transferable) NFT receipt** to the donor. The NFT initially has an empty IPFS CID, which the admin can update later via Pinata with reports, images, and documentation.

## Donation → NFT Minting Flow

```
1. Donor calls donate(campaignId, amount)
2. Contract transfers USDC from donor to pool
3. Contract mints Receipt NFT to donor with:
   - campaignId
   - amount
   - Empty IPFS CID (initially "")
   - isImpact = false (donation)
4. NFT tokenId is emitted in Donated event
```

## Admin Updates IPFS Metadata (via Pinata)

### Step 1: Upload to Pinata
NGO/Admin uploads campaign materials to Pinata:
- **Folder structure** on Pinata:
  ```
  /campaign-folder/
    ├── report.pdf
    ├── images/
    │   ├── photo1.jpg
    │   ├── photo2.jpg
    │   └── photo3.jpg
    └── metadata.json
  ```

### Step 2: Get Pinata Folder CID
After uploading, Pinata provides a folder CID like:
```
QmPinataFolderHashWithReportsAndImages123
```

### Step 3: Update NFT Metadata On-Chain
Admin calls the pool contract (which is the NFT minter):
```solidity
// From the pool contract (admin role)
receiptNFT.updateIPFSCID(tokenId, "QmPinataFolderHashWithReportsAndImages123");
```

### Step 4: Users View Receipt
Donors can now view their receipt at:
```
ipfs://QmPinataFolderHashWithReportsAndImages123
```

This IPFS URL contains:
- Campaign reports
- Photos/images from the campaign
- Full metadata about the donation impact

## Smart Contract Functions

### For Donors
```solidity
// Donate and receive NFT
pool.donate(campaignId, amount);
```

### For Admin (Pool Contract)
```solidity
// Update IPFS CID after uploading to Pinata
receiptNFT.updateIPFSCID(tokenId, "QmPinataFolderCID");
```

### NFT Properties
- ✅ **Soulbound**: Cannot be transferred (prove authentic donation)
- ✅ **IPFS-backed**: Points to Pinata folder with reports/images
- ✅ **Updateable**: Admin can update CID as campaign progresses
- ✅ **ERC721 compatible**: Works with wallets/explorers

## Events

### Donation with NFT Minting
```solidity
event Donated(
    bytes32 indexed campaignId,
    address indexed donor,
    uint256 amount,
    uint256 indexed tokenId  // NFT token ID
);
```

### IPFS CID Update
```solidity
event IPFSCIDUpdated(
    uint256 indexed tokenId,
    string oldCID,
    string newCID
);
```

## Example Workflow

1. **Ramadan 2025 Campaign Created**
   - Campaign starts, allocation locked

2. **Alice donates 1000 USDC**
   - NFT #1 minted to Alice
   - IPFS CID: "" (empty)

3. **Bob donates 500 USDC**
   - NFT #2 minted to Bob
   - IPFS CID: "" (empty)

4. **NGO distributes aid & uploads documentation to Pinata**
   - Photos of food distribution
   - Receipt reports
   - Impact measurements
   - Get Pinata CID: `QmXYZ123...`

5. **Admin updates all NFT metadata**
   ```solidity
   receiptNFT.updateIPFSCID(1, "QmXYZ123...");
   receiptNFT.updateIPFSCID(2, "QmXYZ123...");
   ```

6. **Donors can now view proof**
   - Alice opens her NFT → sees campaign reports & photos
   - Bob opens his NFT → sees campaign reports & photos
   - Both have verifiable proof of donation impact

## Security Features

1. **Only Pool Contract can mint**: Prevents fake receipts
2. **Only Pool Contract (admin) can update CID**: Prevents tampering
3. **Soulbound tokens**: Cannot be transferred/sold (proof of authentic donation)
4. **On-chain amount tracking**: Donation amount stored immutably

## Deployment Order

```bash
1. Deploy ZKTReceiptNFT(address(0))  # No minter yet
2. Deploy ZKTCampaignPool(admin, usdc, nft)
3. Call nft.setMinter(poolAddress)
4. Continue with campaign setup
```

## Testing

Run the comprehensive test suite:
```bash
forge test -vv
```

Tests cover:
- ✅ NFT minting on donation
- ✅ Metadata updates via updateIPFSCID
- ✅ Soulbound enforcement (transfer reverts)
- ✅ Multiple donations → multiple NFTs
- ✅ TokenURI returns correct IPFS link
