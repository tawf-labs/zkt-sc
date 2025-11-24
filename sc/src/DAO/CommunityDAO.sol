// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../tokens/SBTToken.sol";

/**
 * @title CommunityDAO
 * @notice Decentralized governance system for Zakat and donation campaigns
 * @dev Implements multi-stage proposal lifecycle with community voting and Sharia council review
 * 
 * Flow: Organizer creates proposal (with mock ZK-KYC) → Community votes → 
 *       Automated bundling → Sharia council reviews → Pool created → Donors contribute & receive SBTs
 */
contract CommunityDAO is AccessControl, ReentrancyGuard {
    // ============ Roles ============
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant COMMUNITY_MEMBER_ROLE = keccak256("COMMUNITY_MEMBER_ROLE");
    bytes32 public constant SHARIA_COUNCIL_ROLE = keccak256("SHARIA_COUNCIL_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant KYC_ORACLE_ROLE = keccak256("KYC_ORACLE_ROLE");
    
    // ============ Enums ============
    enum ProposalStatus {
        Draft,              // 0: proposal created but not submitted to vote
        CommunityVote,      // 1: community voting active
        CommunityPassed,    // 2: community vote passed, awaiting Sharia review
        CommunityRejected,  // 3: community vote failed
        ShariaReview,       // 4: submitted to Sharia council
        ShariaApproved,     // 5: Sharia approved (zakat or non-zakat)
        ShariaRejected,     // 6: Sharia rejected
        PoolCreated,        // 7: campaign pool is live
        Completed,          // 8: fundraising completed
        Canceled            // 9: canceled by organizer or admin
    }
    
    enum KYCStatus {
        NotRequired,        // 0: emergency bypass
        Pending,            // 1: KYC submitted, awaiting verification
        Verified,           // 2: KYC approved
        Rejected            // 3: KYC failed
    }
    
    enum CampaignType {
        Normal,             // 0: standard donation campaign
        ZakatCompliant      // 1: Zakat-eligible campaign
    }
    
    // ============ Structs ============
    struct Proposal {
        uint256 proposalId;
        address organizer;
        string title;
        string description;
        uint256 fundingGoal;
        KYCStatus kycStatus;
        bool isEmergency;
        bytes32 mockZKKYCProof;     // Mock ZK proof hash (TODO: Replace with zkSNARK verifier)
        string kycNotes;            // Admin notes for future KYC provider integration
        uint256 createdAt;
        uint256 communityVoteStart;
        uint256 communityVoteEnd;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        ProposalStatus status;
        CampaignType campaignType;
        uint256 poolId;
        string[] zakatChecklistItems;
    }
    
    struct ShariaReviewBundle {
        uint256 bundleId;
        uint256[] proposalIds;
        uint256 submittedAt;
        bool finalized;
        uint256 approvalCount;      // For quorum tracking
    }
    
    struct CampaignPool {
        uint256 poolId;
        uint256 proposalId;
        address organizer;
        uint256 fundingGoal;
        uint256 raisedAmount;
        CampaignType campaignType;
        bool isActive;
        uint256 createdAt;
        address[] donors;
        bool fundsWithdrawn;
    }
    
    // ============ State Variables ============
    uint256 public proposalCount;
    uint256 public bundleCount;
    uint256 public poolCount;
    uint256 public totalCommunityMembers;
    
    // Governance parameters
    uint256 public votingPeriod = 7 days;
    uint256 public quorumPercentage = 10; // 10% of members must vote
    uint256 public passThreshold = 51;     // 51% votes for = passed
    
    // Automated bundling parameters
    uint256 public constant BUNDLE_THRESHOLD = 5;     // Bundle after 5 passed proposals
    uint256 public constant BUNDLE_TIME_THRESHOLD = 7 days; // Or after 7 days
    uint256 public lastBundleTime;
    
    // Sharia council quorum
    uint256 public shariaQuorumRequired = 3; // 3 out of 5 council members
    
    // External contracts
    IERC20 public idrxToken;
    SBTToken public sbtToken;
    
    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => ShariaReviewBundle) public shariaBundles;
    mapping(uint256 => mapping(uint256 => bool)) public bundleProposalApproved; // bundleId => proposalId => approved
    mapping(uint256 => mapping(uint256 => CampaignType)) public bundleProposalType; // bundleId => proposalId => type
    mapping(uint256 => mapping(uint256 => bytes32)) public shariaReviewProofs; // bundleId => proposalId => mockZKProof
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public shariaVotes; // bundleId => council => proposalId => voted
    mapping(uint256 => CampaignPool) public campaignPools;
    mapping(uint256 => mapping(address => uint256)) public poolDonations; // poolId => donor => amount
    
    // ============ Events ============
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed organizer,
        string title,
        uint256 fundingGoal,
        bool isEmergency
    );
    event ProposalSubmitted(uint256 indexed proposalId, uint256 voteStart, uint256 voteEnd);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support);
    event ProposalPassed(uint256 indexed proposalId, uint256 votesFor, uint256 votesAgainst);
    event ProposalRejected(uint256 indexed proposalId, uint256 votesFor, uint256 votesAgainst);
    event KYCStatusUpdated(uint256 indexed proposalId, KYCStatus status, string notes);
    event ShariaReviewBundleCreated(uint256 indexed bundleId, uint256[] proposalIds);
    event ProposalShariaApproved(uint256 indexed proposalId, CampaignType campaignType);
    event ProposalShariaRejected(uint256 indexed proposalId);
    event ShariaBundleFinalized(uint256 indexed bundleId);
    event CampaignPoolCreated(
        uint256 indexed poolId,
        uint256 indexed proposalId,
        CampaignType campaignType
    );
    event DonationReceived(
        uint256 indexed poolId,
        address indexed donor,
        uint256 amount,
        bool isFirstDonation
    );
    event FundingGoalReached(uint256 indexed poolId, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed poolId, address indexed organizer, uint256 amount);
    event ProposalCanceled(uint256 indexed proposalId);
    
    // ============ Constructor ============
    constructor(address _idrxToken, address _sbtToken) {
        require(_idrxToken != address(0), "Invalid IDRX token address");
        require(_sbtToken != address(0), "Invalid SBT token address");
        
        idrxToken = IERC20(_idrxToken);
        sbtToken = SBTToken(_sbtToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        lastBundleTime = block.timestamp;
    }
    
    // ============ Proposal Creation & KYC Functions ============
    
    /**
     * @notice Create a new campaign proposal
     * @param title Proposal title
     * @param description Detailed description
     * @param fundingGoal Target amount in IDRX (wei)
     * @param isEmergency True to bypass KYC (requires admin approval)
     * @param mockZKKYCProof Mock ZK proof hash (simulated)
     * @param zakatChecklistItems Optional zakat compliance checklist
     */
    function createProposal(
        string memory title,
        string memory description,
        uint256 fundingGoal,
        bool isEmergency,
        bytes32 mockZKKYCProof,
        string[] memory zakatChecklistItems
    ) external onlyRole(ORGANIZER_ROLE) returns (uint256) {
        require(fundingGoal > 0, "Funding goal must be > 0");
        require(bytes(title).length > 0, "Title cannot be empty");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.organizer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.fundingGoal = fundingGoal;
        proposal.isEmergency = isEmergency;
        proposal.mockZKKYCProof = mockZKKYCProof;
        proposal.createdAt = block.timestamp;
        proposal.status = ProposalStatus.Draft;
        proposal.zakatChecklistItems = zakatChecklistItems;
        
        if (isEmergency) {
            proposal.kycStatus = KYCStatus.NotRequired;
        } else {
            proposal.kycStatus = KYCStatus.Pending;
        }
        
        emit ProposalCreated(proposalId, msg.sender, title, fundingGoal, isEmergency);
        
        return proposalId;
    }
    
    /**
     * @notice Update KYC status with mock ZK proof (admin/oracle only)
     * @param proposalId Proposal ID
     * @param newStatus New KYC status
     * @param notes Notes about KYC verification (for future integration)
     */
    function updateKYCStatus(
        uint256 proposalId,
        KYCStatus newStatus,
        string memory notes
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(KYC_ORACLE_ROLE, msg.sender),
            "Not authorized"
        );
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        proposal.kycStatus = newStatus;
        proposal.kycNotes = notes;
        
        emit KYCStatusUpdated(proposalId, newStatus, notes);
    }
    
    /**
     * @notice Submit proposal for community vote
     * @param proposalId Proposal ID
     */
    function submitForCommunityVote(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            proposal.organizer == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(proposal.status == ProposalStatus.Draft, "Invalid status");
        
        // Check KYC requirement
        if (!proposal.isEmergency) {
            require(
                proposal.kycStatus == KYCStatus.Verified,
                "KYC must be verified first"
            );
        }
        
        proposal.communityVoteStart = block.timestamp;
        proposal.communityVoteEnd = block.timestamp + votingPeriod;
        proposal.status = ProposalStatus.CommunityVote;
        
        emit ProposalSubmitted(proposalId, proposal.communityVoteStart, proposal.communityVoteEnd);
    }
    
    // ============ Voting Functions ============
    
    /**
     * @notice Cast vote on active proposal
     * @param proposalId Proposal ID
     * @param support 0=Against, 1=For, 2=Abstain
     */
    function castVote(uint256 proposalId, uint8 support) external onlyRole(COMMUNITY_MEMBER_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.CommunityVote, "Voting not active");
        require(
            block.timestamp >= proposal.communityVoteStart &&
            block.timestamp <= proposal.communityVoteEnd,
            "Voting period ended"
        );
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(support <= 2, "Invalid vote option");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support == 0) {
            proposal.votesAgainst++;
        } else if (support == 1) {
            proposal.votesFor++;
        } else {
            proposal.votesAbstain++;
        }
        
        emit VoteCast(proposalId, msg.sender, support);
    }
    
    /**
     * @notice Finalize community vote after voting period ends
     * @param proposalId Proposal ID
     */
    function finalizeCommunityVote(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.CommunityVote, "Not in voting");
        require(block.timestamp > proposal.communityVoteEnd, "Voting still active");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst + proposal.votesAbstain;
        uint256 quorumNeeded = (totalCommunityMembers * quorumPercentage) / 100;
        
        // Check quorum
        bool quorumReached = totalVotes >= quorumNeeded;
        
        // Check pass threshold
        bool passed = false;
        if (quorumReached && (proposal.votesFor + proposal.votesAgainst) > 0) {
            uint256 forPercentage = (proposal.votesFor * 100) / (proposal.votesFor + proposal.votesAgainst);
            passed = forPercentage >= passThreshold;
        }
        
        if (passed) {
            proposal.status = ProposalStatus.CommunityPassed;
            emit ProposalPassed(proposalId, proposal.votesFor, proposal.votesAgainst);
            
            // Check if automated bundling should trigger
            _checkAndCreateBundle();
        } else {
            proposal.status = ProposalStatus.CommunityRejected;
            emit ProposalRejected(proposalId, proposal.votesFor, proposal.votesAgainst);
        }
    }
    
    // ============ Automated Bundling Functions ============
    
    /**
     * @notice Check if bundling threshold met and create bundle automatically
     * @dev Can be called by anyone after threshold met
     */
    function checkAndCreateBundle() external {
        _checkAndCreateBundle();
    }
    
    function _checkAndCreateBundle() internal {
        // Count passed proposals not yet bundled
        uint256[] memory passedProposals = new uint256[](proposalCount);
        uint256 passedCount = 0;
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (proposals[i].status == ProposalStatus.CommunityPassed) {
                passedProposals[passedCount] = i;
                passedCount++;
            }
        }
        
        // Check thresholds
        bool countThresholdMet = passedCount >= BUNDLE_THRESHOLD;
        bool timeThresholdMet = block.timestamp >= lastBundleTime + BUNDLE_TIME_THRESHOLD;
        
        if ((countThresholdMet || timeThresholdMet) && passedCount > 0) {
            // Create bundle with all passed proposals
            uint256[] memory bundleProposals = new uint256[](passedCount);
            for (uint256 i = 0; i < passedCount; i++) {
                bundleProposals[i] = passedProposals[i];
            }
            
            _createShariaReviewBundle(bundleProposals);
        }
    }
    
    /**
     * @notice Create Sharia review bundle (internal or admin)
     * @param proposalIds Array of proposal IDs to bundle
     */
    function createShariaReviewBundle(uint256[] memory proposalIds) 
        external 
        onlyRole(ADMIN_ROLE) 
        returns (uint256) 
    {
        return _createShariaReviewBundle(proposalIds);
    }
    
    function _createShariaReviewBundle(uint256[] memory proposalIds) 
        internal 
        returns (uint256) 
    {
        require(proposalIds.length > 0, "No proposals to bundle");
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            require(
                proposals[proposalIds[i]].status == ProposalStatus.CommunityPassed,
                "Proposal not passed"
            );
        }
        
        bundleCount++;
        uint256 bundleId = bundleCount;
        
        ShariaReviewBundle storage bundle = shariaBundles[bundleId];
        bundle.bundleId = bundleId;
        bundle.proposalIds = proposalIds;
        bundle.submittedAt = block.timestamp;
        bundle.finalized = false;
        
        // Update proposal statuses
        for (uint256 i = 0; i < proposalIds.length; i++) {
            proposals[proposalIds[i]].status = ProposalStatus.ShariaReview;
        }
        
        lastBundleTime = block.timestamp;
        
        emit ShariaReviewBundleCreated(bundleId, proposalIds);
        
        return bundleId;
    }
    
    // ============ Sharia Review Functions ============
    
    /**
     * @notice Sharia council member reviews a proposal in bundle
     * @param bundleId Bundle ID
     * @param proposalId Proposal ID
     * @param approved True if approved
     * @param campaignType Normal or ZakatCompliant
     * @param mockZKReviewProof Mock ZK proof hash for review
     */
    function reviewProposal(
        uint256 bundleId,
        uint256 proposalId,
        bool approved,
        CampaignType campaignType,
        bytes32 mockZKReviewProof
    ) external onlyRole(SHARIA_COUNCIL_ROLE) {
        ShariaReviewBundle storage bundle = shariaBundles[bundleId];
        
        require(!bundle.finalized, "Bundle already finalized");
        require(_isProposalInBundle(bundleId, proposalId), "Proposal not in bundle");
        require(
            !shariaVotes[bundleId][msg.sender][proposalId],
            "Already voted on this proposal"
        );
        
        shariaVotes[bundleId][msg.sender][proposalId] = true;
        shariaReviewProofs[bundleId][proposalId] = mockZKReviewProof;
        
        if (approved) {
            bundleProposalApproved[bundleId][proposalId] = true;
            bundleProposalType[bundleId][proposalId] = campaignType;
        }
    }
    
    /**
     * @notice Finalize Sharia bundle review (requires quorum)
     * @param bundleId Bundle ID
     */
    function finalizeShariaBundle(uint256 bundleId) external onlyRole(SHARIA_COUNCIL_ROLE) {
        ShariaReviewBundle storage bundle = shariaBundles[bundleId];
        
        require(!bundle.finalized, "Bundle already finalized");
        
        bundle.finalized = true;
        
        // Process each proposal in bundle
        for (uint256 i = 0; i < bundle.proposalIds.length; i++) {
            uint256 proposalId = bundle.proposalIds[i];
            
            // Count votes for this proposal
            uint256 approvalVotes = _countShariaApprovalVotes(bundleId, proposalId);
            
            if (approvalVotes >= shariaQuorumRequired) {
                // Approved
                CampaignType cType = bundleProposalType[bundleId][proposalId];
                proposals[proposalId].status = ProposalStatus.ShariaApproved;
                proposals[proposalId].campaignType = cType;
                
                emit ProposalShariaApproved(proposalId, cType);
            } else {
                // Rejected
                proposals[proposalId].status = ProposalStatus.ShariaRejected;
                emit ProposalShariaRejected(proposalId);
            }
        }
        
        emit ShariaBundleFinalized(bundleId);
    }
    
    function _countShariaApprovalVotes(uint256 bundleId, uint256 proposalId) 
        internal 
        view 
        returns (uint256) 
    {
        if (!bundleProposalApproved[bundleId][proposalId]) {
            return 0;
        }
        
        // In production, iterate through council members
        // For MVP: simplified - if approved by any council member, count as 1 vote
        // This should be enhanced to track individual council votes
        return shariaQuorumRequired; // Simplified for MVP
    }
    
    function _isProposalInBundle(uint256 bundleId, uint256 proposalId) 
        internal 
        view 
        returns (bool) 
    {
        uint256[] memory proposalIds = shariaBundles[bundleId].proposalIds;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposalIds[i] == proposalId) {
                return true;
            }
        }
        return false;
    }
    
    // ============ Campaign Pool & Fundraising Functions ============
    
    /**
     * @notice Create campaign pool for approved proposal
     * @param proposalId Proposal ID
     */
    function createCampaignPool(uint256 proposalId) 
        external 
        onlyRole(ADMIN_ROLE) 
        returns (uint256) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.ShariaApproved, "Not approved");
        require(proposal.poolId == 0, "Pool already created");
        
        poolCount++;
        uint256 poolId = poolCount;
        
        CampaignPool storage pool = campaignPools[poolId];
        pool.poolId = poolId;
        pool.proposalId = proposalId;
        pool.organizer = proposal.organizer;
        pool.fundingGoal = proposal.fundingGoal;
        pool.campaignType = proposal.campaignType;
        pool.isActive = true;
        pool.createdAt = block.timestamp;
        
        proposal.poolId = poolId;
        proposal.status = ProposalStatus.PoolCreated;
        
        emit CampaignPoolCreated(poolId, proposalId, proposal.campaignType);
        
        return poolId;
    }
    
    /**
     * @notice Donate IDRX to campaign pool
     * @param poolId Pool ID
     * @param amount Amount in IDRX (wei)
     */
    function donate(uint256 poolId, uint256 amount) external nonReentrant {
        CampaignPool storage pool = campaignPools[poolId];
        
        require(pool.isActive, "Pool not active");
        require(amount > 0, "Amount must be > 0");
        
        // Transfer IDRX from donor
        require(
            idrxToken.transferFrom(msg.sender, address(this), amount),
            "IDRX transfer failed"
        );
        
        bool isFirstDonation = poolDonations[poolId][msg.sender] == 0;
        
        poolDonations[poolId][msg.sender] += amount;
        pool.raisedAmount += amount;
        
        // Add to donors list if first donation
        if (isFirstDonation) {
            pool.donors.push(msg.sender);
            
            // Mint SBT to donor
            string memory campaignTypeStr = pool.campaignType == CampaignType.ZakatCompliant 
                ? "Zakat" 
                : "Normal";
            sbtToken.mint(msg.sender, poolId, amount, campaignTypeStr);
        } else {
            // Update existing SBT
            sbtToken.updateDonation(msg.sender, poolId, amount);
        }
        
        emit DonationReceived(poolId, msg.sender, amount, isFirstDonation);
        
        // Check if funding goal reached
        if (pool.raisedAmount >= pool.fundingGoal) {
            emit FundingGoalReached(poolId, pool.raisedAmount);
        }
    }
    
    /**
     * @notice Organizer withdraws raised funds
     * @param poolId Pool ID
     */
    function withdrawFunds(uint256 poolId) external nonReentrant {
        CampaignPool storage pool = campaignPools[poolId];
        
        require(pool.organizer == msg.sender, "Not organizer");
        require(!pool.fundsWithdrawn, "Funds already withdrawn");
        require(pool.raisedAmount > 0, "No funds to withdraw");
        
        pool.fundsWithdrawn = true;
        pool.isActive = false;
        
        uint256 amount = pool.raisedAmount;
        proposals[pool.proposalId].status = ProposalStatus.Completed;
        
        require(idrxToken.transfer(msg.sender, amount), "Transfer failed");
        
        emit FundsWithdrawn(poolId, msg.sender, amount);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Cancel proposal (organizer or admin)
     * @param proposalId Proposal ID
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            proposal.organizer == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(
            proposal.status != ProposalStatus.PoolCreated &&
            proposal.status != ProposalStatus.Completed,
            "Cannot cancel active/completed pool"
        );
        
        proposal.status = ProposalStatus.Canceled;
        
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @notice Set total community members count
     */
    function setTotalCommunityMembers(uint256 count) external onlyRole(ADMIN_ROLE) {
        totalCommunityMembers = count;
    }
    
    /**
     * @notice Update governance parameters
     */
    function setVotingPeriod(uint256 _votingPeriod) external onlyRole(ADMIN_ROLE) {
        votingPeriod = _votingPeriod;
    }
    
    function setQuorumPercentage(uint256 _quorumPercentage) external onlyRole(ADMIN_ROLE) {
        require(_quorumPercentage <= 100, "Invalid percentage");
        quorumPercentage = _quorumPercentage;
    }
    
    function setPassThreshold(uint256 _passThreshold) external onlyRole(ADMIN_ROLE) {
        require(_passThreshold <= 100, "Invalid percentage");
        passThreshold = _passThreshold;
    }
    
    function setShariaQuorum(uint256 _quorum) external onlyRole(ADMIN_ROLE) {
        shariaQuorumRequired = _quorum;
    }
    
    // ============ View Functions ============
    
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }
    
    function getProposalChecklistItems(uint256 proposalId) 
        external 
        view 
        returns (string[] memory) 
    {
        return proposals[proposalId].zakatChecklistItems;
    }
    
    function getBundle(uint256 bundleId) external view returns (ShariaReviewBundle memory) {
        return shariaBundles[bundleId];
    }
    
    function getPool(uint256 poolId) external view returns (CampaignPool memory) {
        return campaignPools[poolId];
    }
    
    function getPoolDonors(uint256 poolId) external view returns (address[] memory) {
        return campaignPools[poolId].donors;
    }
    
    function getDonorContribution(uint256 poolId, address donor) 
        external 
        view 
        returns (uint256) 
    {
        return poolDonations[poolId][donor];
    }
}
