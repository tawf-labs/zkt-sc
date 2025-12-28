# ZKT Smart Contract - Complete Flow Documentation

## 📋 Contract Addresses (Base Sepolia - Chain ID: 84532)

```
MockIDRX (Token):          0xbc00d53Fd6208abf820529A9e1a971a01D41ef43
DonationReceiptNFT:        0x2c1e3b27A8Cf82C34d7F81c035f0f0A6Ef01462D
VotingToken:               0xf88d560836AD8193c33c534FF997388489C9dc08
ZKTCore (Main Entry):      0xabb2dF0EB530C8317845f6dcD54A3B2fCA9cD6A9

ProposalManager:           0x19dee77af736bbee95f8bcb028a87df102faed25
VotingManager:             0xffdaee55f3904e11a9bddd95d2e9c0716551bcc1
ShariaReviewManager:       0x19725c1dee1fe40352da4a5590efe84b7033a6a9
PoolManager:               0x23e44ecb31e71acc10633da7af6e73e5092d22e0
```

---

## 🔄 Complete Campaign Flow

### Step 1: Organizer Creates Proposal

**Function:** `createProposal()`  
**Who:** Organizer with `ORGANIZER_ROLE`

```solidity
ZKTCore.createProposal(
    "Build School in Village",           // title
    "Detailed description...",            // description
    1000 * 10**18,                       // fundingGoal (1000 IDRX)
    false,                               // isEmergency (false = KYC required)
    mockZKKYCProof,                      // zkProof (ZK proof for privacy-preserving KYC)
    ["Item 1", "Item 2"]                 // shariaChecklist
)

// Returns: proposalId (starts from 1)
```

**Requirements:**
- Caller must have `ORGANIZER_ROLE`
- Title cannot be empty
- Funding goal must be > 0

**KYC Status Assignment:**
- If `isEmergency = false` → KYC Status = `Pending` (must verify before Sharia review)
- If `isEmergency = true` → KYC Status = `NotRequired` (skip KYC)

**Status After:** `Draft`

---

### Step 2: KYC Verification (if required)

**Function:** `updateKYCStatus()`  
**Who:** Address with `KYC_ORACLE_ROLE`

```solidity
ZKTCore.updateKYCStatus(
    proposalId,
    KYCStatus.Verified,  // 0=NotRequired, 1=Pending, 2=Verified, 3=Rejected
    "KYC verification notes"
)
```

**Requirements:**
- Called by address with `KYC_ORACLE_ROLE`
- Organizer provides `mockZKKYCProof` (ZK-proof for privacy)
- KYC must be `Verified` before Sharia council can finalize bundle

**KYC Status Enum:**
```solidity
enum KYCStatus {
    NotRequired,  // 0
    Pending,      // 1
    Verified,     // 2
    Rejected      // 3
}
```

---

### Step 3: Submit for Community Voting

**Function:** `submitForCommunityVote()`  
**Who:** Proposal organizer only

```solidity
ZKTCore.submitForCommunityVote(proposalId)
```

**Requirements:**
- Only the proposal's organizer can submit
- Proposal must be in `Draft` status

**Status After:** `CommunityVoting`

---

### Step 4: Community Members Vote

**Function:** `castVote()`  
**Who:** Anyone with voting tokens (vZKT)

```solidity
ZKTCore.castVote(
    proposalId,
    1    // 1 = For, 2 = Against, 3 = Abstain
)
```

**Requirements:**
- Voter must have vZKT tokens (voting power)
- Proposal must be in `CommunityVoting` status
- Cannot vote twice on same proposal
- Voting is active (within time window)

**Vote Calculation:**
- Vote power = vZKT balance
- Quorum: Minimum 10% of total vZKT supply
- Approval threshold: 66% approval

**Vote Types:**
```solidity
enum VoteType {
    For,      // 1
    Against,  // 2
    Abstain   // 3
}
```

---

### Step 5: Finalize Community Vote

**Function:** `finalizeCommunityVote()`  
**Who:** Anyone (after voting period ends)

```solidity
ZKTCore.finalizeCommunityVote(proposalId)
```

**Requirements:**
- Voting period must be over (7 days)
- Quorum must be met (10%)

**If Approved:**
- Status → `Pending` (waiting for Sharia review)
- Auto-creates Sharia bundle
- **If Rejected:** Status → `Rejected`

---

### Step 6: Sharia Council Reviews Proposal

**Function:** `reviewProposal()`  
**Who:** Members with `SHARIA_COUNCIL_ROLE`

```solidity
ZKTCore.reviewProposal(
    bundleId,        // Auto-created bundle when community vote passes
    proposalId,
    true,            // approved (true/false)
    CampaignType.ZakatCompliant,  // 0=Normal, 1=ZakatCompliant
    zkProof          // Optional ZK proof
)
```

**Requirements:**
- Caller must have `SHARIA_COUNCIL_ROLE`
- Proposal must be in bundle
- KYC verified (if required)
- Each council member can only vote once per proposal

**Campaign Type Enum:**
```solidity
enum CampaignType {
    Normal,           // 0
    ZakatCompliant    // 1
}
```

**What Happens Internally:**
```solidity
// Store council member's vote
hasVoted[bundleId][proposalId][msg.sender] = true;

// Record vote type
if (approved) {
    approvalVotes[bundleId][proposalId][msg.sender] = true;
}

// Set campaign type
setCampaignType(proposalId, campaignType);
```

**Multi-Signature Voting:**
- Needs **2/3 quorum** (minimum 2 council members)
- **Simple majority** for approval
- Example: If 3 council members exist, need at least 2 reviews

---

### Step 7: Finalize Sharia Bundle

**Function:** `finalizeShariaBundle()`  
**Who:** Any Sharia Council member (after quorum reached)

```solidity
ZKTCore.finalizeShariaBundle(bundleId)
```

**Quorum Logic:**
```solidity
uint256 councilSize = getRoleMemberCount(SHARIA_COUNCIL_ROLE);
uint256 quorum = (councilSize * 2) / 3; // 2/3 quorum

require(reviewedCount >= quorum, "Quorum not met");

// Count approval votes
uint256 approvals = 0;
for each council member who voted {
    if (approved) approvals++;
}

// Simple majority
if (approvals > reviewedCount / 2) {
    status = ShariaApproved;
} else {
    status = ShariaRejected;
}
```

**If Approved:**
- Status → `ShariaApproved`
- Campaign type set (Zakat/Normal)

**If Rejected:**
- Status → `Rejected`

**Example Voting Scenario:**
```solidity
// Council member 1 reviews and approves
vm.prank(shariaCouncil1);
dao.reviewProposal(bundleId, proposalId, true, CampaignType.ZakatCompliant, zkProof);

// Council member 2 reviews and approves
vm.prank(shariaCouncil2);
dao.reviewProposal(bundleId, proposalId, true, CampaignType.ZakatCompliant, zkProof);

// Now 2/3 reached, can finalize
vm.prank(shariaCouncil1);
dao.finalizeShariaBundle(bundleId);
// ✅ Status → ShariaApproved
```

---

### Step 8: Organizer Creates Campaign Pool

**Function:** `createCampaignPool()`  
**Who:** Original proposal organizer only

```solidity
ZKTCore.createCampaignPool(proposalId)

// Returns: poolId (starts from 1)
```

**Requirements:**
- Only proposal organizer can create pool
- Proposal must be `ShariaApproved`
- Pool not already created

**Status After:** `PoolCreated`

---

### Step 9: Donors Donate to Pool & Receive NFT Receipts

**Function:** `donate()`  
**Who:** Anyone with IDRX tokens

```solidity
// 1. First, approve IDRX token spending
IDRX.approve(PoolManagerAddress, amount)

// 2. Then donate
ZKTCore.donate(poolId, amount)
```

**What Happens:**
1. IDRX transferred from donor to PoolManager
2. Donation amount tracked for the pool
3. **NFT Receipt automatically minted** (Soulbound Token - SBT)

**NFT Receipt Details:**
- **Non-transferable** (Soulbound Token)
- One receipt per donation (not per pool)
- Multiple donations from same donor = multiple NFTs

**NFT Metadata Structure:**
```solidity
struct SBTMetadata {
    uint256 poolId;            // Which pool donated to
    address donor;             // Donor address
    uint256 donationAmount;    // Amount donated (in IDRX)
    uint256 donatedAt;         // Timestamp
    string campaignTitle;      // e.g., "Build School in Village"
    string campaignType;       // "Zakat Compliant" or "Normal"
    bool isActive;             // Can be deactivated if needed
}
```

**Internal Donation Logic:**
```solidity
function donate(uint256 poolId, uint256 amount) external {
    // 1. Transfer IDRX to PoolManager
    IERC20(idrxToken).transferFrom(msg.sender, address(this), amount);
    
    // 2. Update pool state
    pool.raisedAmount += amount;
    
    // 3. MINT NFT RECEIPT 🎫
    receiptNFT.mint(
        msg.sender,           // Recipient
        poolId,               // Pool ID
        amount,               // Donation amount
        proposal.title,       // Campaign title
        campaignTypeString    // "Zakat Compliant" or "Normal"
    );
}
```

**Soulbound (Non-Transferable) Enforcement:**
```solidity
function transferFrom(address, address, uint256) 
    public 
    virtual 
    override 
{
    revert("DonationReceiptNFT: Non-transferable receipt");
}

function safeTransferFrom(address, address, uint256) 
    public 
    virtual 
    override 
{
    revert("DonationReceiptNFT: Non-transferable receipt");
}
```

**Example:**
```solidity
// Donor1 first donation to pool #1
dao.donate(1, 500 * 10**18);
// → NFT #1 minted to donor1

// Donor1 second donation to SAME pool #1
dao.donate(1, 300 * 10**18);
// → NFT #2 minted to donor1 (separate receipt!)

uint256[] memory receipts = receiptNFT.getDonorReceipts(donor1);
// receipts.length = 2 (two separate NFTs)
```

---

### Step 10: Organizer Withdraws Funds

**Function:** `withdrawFunds()`  
**Who:** Campaign organizer

```solidity
ZKTCore.withdrawFunds(poolId)
```

**Requirements:**
- Only campaign organizer
- Pool must be active
- Funds not already withdrawn

**What Happens:**
- All raised funds sent to organizer's address
- Pool marked as withdrawn
- Cannot withdraw again (one-time only)

---

## 📊 Query Functions

### Get Proposal Details
```solidity
ZKTCore.getProposal(proposalId)
// Returns full proposal data structure
```

### Get Pool Information
```solidity
ZKTCore.getPoolInfo(poolId)
// Returns: poolId, proposalId, organizer, fundingGoal, 
//          raisedAmount, campaignType, status, etc.
```

### Check Donation Amount
```solidity
ZKTCore.getDonationAmount(poolId, donorAddress)
// Returns total amount donated by specific address to pool
```

### Get Donor's NFT Receipts
```solidity
DonationReceiptNFT.getDonorReceipts(donorAddress)
// Returns array of tokenIds owned by donor
```

### Get NFT Metadata
```solidity
SBTMetadata memory metadata = receiptNFT.tokenMetadata(tokenId);

console.log("Donated to:", metadata.campaignTitle);
console.log("Amount:", metadata.donationAmount);
console.log("Type:", metadata.campaignType);
console.log("Pool ID:", metadata.poolId);
console.log("Timestamp:", metadata.donatedAt);
```

---

## 🎭 Roles & Permissions

| Role | Address Type | Permissions |
|------|-------------|-------------|
| **ORGANIZER_ROLE** | Campaign creators | Create proposals, submit for voting, create pools, withdraw funds |
| **SHARIA_COUNCIL_ROLE** | Islamic scholars | Review proposals, finalize bundles, set campaign types |
| **KYC_ORACLE_ROLE** | Verification service | Verify/reject organizer KYC status |
| **vZKT Token Holders** | Community voters | Vote on proposals during community voting phase |
| **Anyone** | Public | Donate to active pools, view proposals/pools |

---

## 🏗️ System Architecture

### Pool-Based Fundraising Model

This is a **POOL-BASED** system where:

1. **Proposals** are created first (campaign ideas)
2. After dual approval (community + Sharia), **Pools** are created
3. Each approved proposal gets its own isolated fundraising pool
4. Donors contribute to specific pools (by poolId)
5. NFT receipts track poolId and donation details

**Flow Diagram:**
```
Proposal → Community Vote → Sharia Review → Pool Creation → Donations → Withdrawal
```

### Contract Interactions

```
User/Frontend
    ↓
ZKTCore (Main Entry Point)
    ↓
    ├── ProposalManager (Proposal creation & tracking)
    ├── VotingManager (Community voting logic)
    ├── ShariaReviewManager (Sharia council reviews)
    └── PoolManager (Fundraising pools)
            ↓
            ├── MockIDRX (Payment token)
            └── DonationReceiptNFT (SBT minting)
```

---

## 🔐 Privacy & Security Features

### 1. Privacy-Preserving KYC
- Uses **ZK-proofs** (`mockZKKYCProof`) for identity verification
- Organizer privacy maintained while proving compliance
- KYC oracle verifies without exposing sensitive data

### 2. Multi-Signature Governance
- **2/3 quorum** required for Sharia decisions
- Prevents single-point-of-failure
- Transparent on-chain voting

### 3. Soulbound NFT Receipts
- **Non-transferable** proof of donation
- Permanent on-chain record
- Cannot be sold or traded
- Tax-deductible proof for donors

### 4. Campaign Type Classification
- **Normal Campaigns**: General fundraising
- **Zakat-Compliant Campaigns**: Islamic charitable giving
- Set by Sharia Council during review

---

## 📋 Proposal Status Flow

```
Draft
  ↓ (submitForCommunityVote)
CommunityVoting
  ↓ (finalizeCommunityVote)
  ├─ Approved → Pending (auto-create Sharia bundle)
  └─ Rejected → Rejected (END)
      ↓
  (KYC verification if needed)
      ↓
  (Sharia Council reviews)
      ↓ (finalizeShariaBundle)
      ├─ ShariaApproved
      └─ ShariaRejected (END)
          ↓ (createCampaignPool)
      PoolCreated
          ↓ (donors donate)
      Fundraising Active
          ↓ (withdrawFunds)
      Completed
```

**Status Enum:**
```solidity
enum ProposalStatus {
    Draft,              // 0 - Initial creation
    CommunityVoting,    // 1 - Community voting in progress
    Pending,            // 2 - Waiting for Sharia review
    ShariaApproved,     // 3 - Approved by Sharia Council
    ShariaRejected,     // 4 - Rejected by Sharia Council
    PoolCreated,        // 5 - Fundraising pool created
    Rejected            // 6 - Rejected by community vote
}
```

---

## 🎯 Key Features Summary

### 1. Dual Governance Model
- **Community voting** (vZKT token holders) - 10% quorum, 66% approval
- **Sharia Council review** (Islamic scholars) - 2/3 quorum, simple majority

### 2. Privacy-Preserving Compliance
- ZK-proofs for KYC verification
- Organizer privacy maintained

### 3. Transparent Fundraising
- On-chain pool tracking
- Real-time donation visibility
- Immutable records

### 4. Soulbound NFT Receipts
- Non-transferable proof of donation
- Each donation gets unique NFT
- Contains: amount, campaign, type, timestamp

### 5. Islamic Finance Compliance
- Sharia Council oversight
- Campaign type classification (Zakat/Normal)
- Halal fundraising mechanisms

### 6. Role-Based Access Control
- Granular permissions
- Organizer, Council, Oracle roles
- Community participation via tokens

---

## 📝 Example Complete Workflow

```solidity
// 1. Organizer creates proposal
uint256 proposalId = dao.createProposal(
    "Build School in Village",
    "We need funds to build a school...",
    1000 * 10**18,
    false,  // isEmergency = false (requires KYC)
    mockZKKYCProof,
    ["Sharia item 1", "Sharia item 2"]
);

// 2. KYC Oracle verifies organizer
dao.updateKYCStatus(proposalId, KYCStatus.Verified, "Verified via ZK proof");

// 3. Organizer submits for community vote
dao.submitForCommunityVote(proposalId);

// 4. Community members vote (7 days)
dao.castVote(proposalId, VoteType.For);

// 5. After 7 days, finalize vote (creates Sharia bundle)
dao.finalizeCommunityVote(proposalId);

// 6. Sharia Council reviews (need 2/3)
dao.reviewProposal(bundleId, proposalId, true, CampaignType.ZakatCompliant, zkProof);

// 7. Finalize Sharia bundle
dao.finalizeShariaBundle(bundleId);

// 8. Organizer creates fundraising pool
uint256 poolId = dao.createCampaignPool(proposalId);

// 9. Donors donate and receive NFT receipts
IDRX.approve(poolManagerAddress, 100 * 10**18);
dao.donate(poolId, 100 * 10**18);
// → NFT receipt #1 minted to donor

// 10. Organizer withdraws funds
dao.withdrawFunds(poolId);
```

---

## 🚀 Getting Started

### For Organizers
1. Obtain `ORGANIZER_ROLE` from admin
2. Create proposal with `createProposal()`
3. Submit for community vote
4. Wait for KYC verification
5. Wait for Sharia approval
6. Create fundraising pool
7. Withdraw funds when ready

### For Donors
1. Acquire IDRX tokens
2. Approve IDRX spending
3. Donate to active pools
4. Receive non-transferable NFT receipt
5. Track donations via NFT metadata

### For Sharia Council
1. Obtain `SHARIA_COUNCIL_ROLE` from admin
2. Review proposals in bundles
3. Approve/reject with campaign type
4. Finalize bundles after quorum

### For Community Members
1. Acquire vZKT voting tokens
2. Vote on proposals during voting period
3. Participate in governance

---

## 📞 Contract Interaction Examples

### Check Proposal Status
```javascript
const proposal = await ZKTCore.getProposal(proposalId);
console.log("Status:", proposal.status);
console.log("Title:", proposal.title);
console.log("Funding Goal:", proposal.fundingGoal);
```

### Check Pool Progress
```javascript
const pool = await ZKTCore.getPoolInfo(poolId);
console.log("Raised:", pool.raisedAmount);
console.log("Goal:", pool.fundingGoal);
console.log("Progress:", (pool.raisedAmount / pool.fundingGoal) * 100 + "%");
```

### View Donor's Receipts
```javascript
const tokenIds = await DonationReceiptNFT.getDonorReceipts(donorAddress);

for (let tokenId of tokenIds) {
    const metadata = await DonationReceiptNFT.tokenMetadata(tokenId);
    console.log(`NFT #${tokenId}:`);
    console.log(`  - Campaign: ${metadata.campaignTitle}`);
    console.log(`  - Amount: ${metadata.donationAmount}`);
    console.log(`  - Type: ${metadata.campaignType}`);
    console.log(`  - Date: ${new Date(metadata.donatedAt * 1000)}`);
}
```

---

## 🔗 Smart Contract Addresses Reference

### Main Contracts
- **ZKTCore**: `0xabb2dF0EB530C8317845f6dcD54A3B2fCA9cD6A9`
- **MockIDRX**: `0xbc00d53Fd6208abf820529A9e1a971a01D41ef43`
- **DonationReceiptNFT**: `0x2c1e3b27A8Cf82C34d7F81c035f0f0A6Ef01462D`
- **VotingToken**: `0xf88d560836AD8193c33c534FF997388489C9dc08`

### Module Contracts
- **ProposalManager**: `0x19dee77af736bbee95f8bcb028a87df102faed25`
- **VotingManager**: `0xffdaee55f3904e11a9bddd95d2e9c0716551bcc1`
- **ShariaReviewManager**: `0x19725c1dee1fe40352da4a5590efe84b7033a6a9`
- **PoolManager**: `0x23e44ecb31e71acc10633da7af6e73e5092d22e0`

### Network
- **Chain**: Base Sepolia Testnet
- **Chain ID**: 84532

---

## 📚 Additional Resources

- Source Code: `/home/zidan/Documents/Github/zkt-sc/sc/`
- Test Files: `/home/zidan/Documents/Github/zkt-sc/sc/test/`
- Deployment Scripts: `/home/zidan/Documents/Github/zkt-sc/sc/script/`

---

*Documentation generated on December 26, 2025*
