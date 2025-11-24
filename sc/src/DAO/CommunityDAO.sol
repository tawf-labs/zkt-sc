// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./core/ProposalManager.sol";
import "./core/VotingManager.sol";
import "./core/ShariaReviewManager.sol";
import "./core/PoolManager.sol";
import "../tokens/MockIDRX.sol";
import "../tokens/DonationReceiptNFT.sol";
import "../tokens/VotingToken.sol";

/**
 * @title CommunityDAO
 * @notice Orchestrator contract for the modular ZKT DAO system
 * @dev Deploys and coordinates: ProposalManager, VotingManager, ShariaReviewManager, PoolManager
 * Uses VotingToken (non-transferable ERC20) for community voting power
 */
contract CommunityDAO is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    ProposalManager public proposalManager;
    VotingManager public votingManager;
    ShariaReviewManager public shariaReviewManager;
    PoolManager public poolManager;
    
    MockIDRX public idrxToken;
    DonationReceiptNFT public receiptNFT;
    VotingToken public votingToken;
    
    constructor(address _idrxToken, address _receiptNFT, address _votingToken) {
        require(_idrxToken != address(0), "Invalid IDRX token");
        require(_receiptNFT != address(0), "Invalid receipt NFT");
        require(_votingToken != address(0), "Invalid Voting token");
        
        idrxToken = MockIDRX(_idrxToken);
        receiptNFT = DonationReceiptNFT(_receiptNFT);
        votingToken = VotingToken(_votingToken);
        
        // Deploy core modules
        proposalManager = new ProposalManager();
        votingManager = new VotingManager(address(proposalManager), _votingToken);
        shariaReviewManager = new ShariaReviewManager(address(proposalManager));
        poolManager = new PoolManager(address(proposalManager), _idrxToken, _receiptNFT);
        
        // Grant cross-module permissions
        proposalManager.grantRole(proposalManager.VOTING_MANAGER_ROLE(), address(votingManager));
        proposalManager.grantRole(proposalManager.VOTING_MANAGER_ROLE(), address(shariaReviewManager));
        proposalManager.grantRole(proposalManager.VOTING_MANAGER_ROLE(), address(poolManager));
        
        // Setup admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    // ============ Role Management Helpers ============
    
    function grantOrganizerRole(address account) external onlyRole(ADMIN_ROLE) {
        proposalManager.grantRole(proposalManager.ORGANIZER_ROLE(), account);
    }
    
    function grantVotingPower(address account, uint256 amount) external onlyRole(ADMIN_ROLE) {
        votingToken.mint(account, amount, "Admin granted voting power");
    }
    
    function revokeVotingPower(address account, uint256 amount) external onlyRole(ADMIN_ROLE) {
        votingToken.burn(account, amount, "Admin revoked voting power");
    }
    
    function grantShariaCouncilRole(address account) external onlyRole(ADMIN_ROLE) {
        shariaReviewManager.grantRole(shariaReviewManager.SHARIA_COUNCIL_ROLE(), account);
    }
    
    function grantKYCOracleRole(address account) external onlyRole(ADMIN_ROLE) {
        proposalManager.grantRole(proposalManager.KYC_ORACLE_ROLE(), account);
    }
    
    // ============ Re-export Core Constants for Compatibility ============
    
    function ORGANIZER_ROLE() external view returns (bytes32) {
        return proposalManager.ORGANIZER_ROLE();
    }
    
    function SHARIA_COUNCIL_ROLE() external view returns (bytes32) {
        return shariaReviewManager.SHARIA_COUNCIL_ROLE();
    }
    
    function KYC_ORACLE_ROLE() external view returns (bytes32) {
        return proposalManager.KYC_ORACLE_ROLE();
    }
    
    // ============ Re-export Core Functions for Ease of Use ============
    
    // Proposal functions
    function createProposal(
        string memory title,
        string memory description,
        uint256 fundingGoal,
        bool isEmergency,
        bytes32 mockZKKYCProof,
        string[] memory zakatChecklistItems
    ) external returns (uint256) {
        return proposalManager.createProposal(
            title,
            description,
            fundingGoal,
            isEmergency,
            mockZKKYCProof,
            zakatChecklistItems
        );
    }
    
    function updateKYCStatus(
        uint256 proposalId,
        IProposalManager.KYCStatus newStatus,
        string memory notes
    ) external {
        proposalManager.updateKYCStatus(proposalId, newStatus, notes);
    }
    
    function submitForCommunityVote(uint256 proposalId) external {
        proposalManager.submitForCommunityVote(proposalId);
    }
    
    function cancelProposal(uint256 proposalId) external {
        proposalManager.cancelProposal(proposalId);
    }
    
    // Voting functions
    function castVote(uint256 proposalId, uint8 support) external {
        votingManager.castVote(proposalId, support);
    }
    
    function finalizeCommunityVote(uint256 proposalId) external {
        bool passed = votingManager.finalizeCommunityVote(proposalId);
        if (passed) {
            shariaReviewManager.checkAndCreateBundle();
        }
    }
    
    // Sharia review functions
    function checkAndCreateBundle() external {
        shariaReviewManager.checkAndCreateBundle();
    }
    
    function createShariaReviewBundle(uint256[] memory proposalIds) external returns (uint256) {
        return shariaReviewManager.createShariaReviewBundle(proposalIds);
    }
    
    function reviewProposal(
        uint256 bundleId,
        uint256 proposalId,
        bool approved,
        IProposalManager.CampaignType campaignType,
        bytes32 mockZKReviewProof
    ) external {
        shariaReviewManager.reviewProposal(bundleId, proposalId, approved, campaignType, mockZKReviewProof);
    }
    
    function finalizeShariaBundle(uint256 bundleId) external {
        shariaReviewManager.finalizeShariaBundle(bundleId);
    }
    
    // Pool functions
    function createCampaignPool(uint256 proposalId) external returns (uint256) {
        return poolManager.createCampaignPool(proposalId);
    }
    
    function donate(uint256 poolId, uint256 amount) external {
        poolManager.donate(poolId, amount);
    }
    
    function withdrawFunds(uint256 poolId) external {
        poolManager.withdrawFunds(poolId);
    }
    
    // ============ View Functions ============
    
    function proposalCount() external view returns (uint256) {
        return proposalManager.proposalCount();
    }
    
    function getProposal(uint256 proposalId) external view returns (IProposalManager.Proposal memory) {
        return proposalManager.getProposal(proposalId);
    }
    
    function getProposalChecklistItems(uint256 proposalId) external view returns (string[] memory) {
        return proposalManager.getProposalChecklistItems(proposalId);
    }
    
    function getBundle(uint256 bundleId) external view returns (ShariaReviewManager.ShariaReviewBundle memory) {
        return shariaReviewManager.getBundle(bundleId);
    }
    
    function getPool(uint256 poolId) external view returns (PoolManager.CampaignPool memory) {
        return poolManager.getPool(poolId);
    }
    
    function getPoolDonors(uint256 poolId) external view returns (address[] memory) {
        return poolManager.getPoolDonors(poolId);
    }
    
    function getDonorContribution(uint256 poolId, address donor) external view returns (uint256) {
        return poolManager.getDonorContribution(poolId, donor);
    }
    
    // ============ Admin Functions ============
    
    function setVotingPeriod(uint256 _votingPeriod) external onlyRole(ADMIN_ROLE) {
        proposalManager.setVotingPeriod(_votingPeriod);
    }
    
    function setQuorumPercentage(uint256 _quorumPercentage) external onlyRole(ADMIN_ROLE) {
        votingManager.setQuorumPercentage(_quorumPercentage);
    }
    
    function setPassThreshold(uint256 _passThreshold) external onlyRole(ADMIN_ROLE) {
        votingManager.setPassThreshold(_passThreshold);
    }
    
    function setShariaQuorum(uint256 _quorum) external onlyRole(ADMIN_ROLE) {
        shariaReviewManager.setShariaQuorum(_quorum);
    }
    
    // ============ Module Access (for advanced users) ============
    
    function getProposalManagerAddress() external view returns (address) {
        return address(proposalManager);
    }
    
    function getVotingManagerAddress() external view returns (address) {
        return address(votingManager);
    }
    
    function getShariaReviewManagerAddress() external view returns (address) {
        return address(shariaReviewManager);
    }
    
    function getPoolManagerAddress() external view returns (address) {
        return address(poolManager);
    }
}
