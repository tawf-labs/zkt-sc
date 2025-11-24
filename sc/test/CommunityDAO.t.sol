// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/tokens/MockIDRX.sol";
import "../src/tokens/SBTToken.sol";
import "../src/DAO/CommunityDAO.sol";

contract CommunityDAOTest is Test {
    MockIDRX public idrxToken;
    SBTToken public sbtToken;
    CommunityDAO public dao;
    
    address public deployer = address(this);
    address public organizer = address(0x1);
    address public member1 = address(0x2);
    address public member2 = address(0x3);
    address public member3 = address(0x4);
    address public shariaCouncil1 = address(0x5);
    address public shariaCouncil2 = address(0x6);
    address public shariaCouncil3 = address(0x7);
    address public donor1 = address(0x8);
    address public donor2 = address(0x9);
    
    function setUp() public {
        // Deploy contracts
        idrxToken = new MockIDRX();
        sbtToken = new SBTToken();
        dao = new CommunityDAO(address(idrxToken), address(sbtToken));
        
        // Grant MINTER_ROLE to DAO
        sbtToken.grantRole(sbtToken.MINTER_ROLE(), address(dao));
        
        // Setup roles
        dao.grantRole(dao.ORGANIZER_ROLE(), organizer);
        dao.grantRole(dao.COMMUNITY_MEMBER_ROLE(), member1);
        dao.grantRole(dao.COMMUNITY_MEMBER_ROLE(), member2);
        dao.grantRole(dao.COMMUNITY_MEMBER_ROLE(), member3);
        dao.grantRole(dao.SHARIA_COUNCIL_ROLE(), shariaCouncil1);
        dao.grantRole(dao.SHARIA_COUNCIL_ROLE(), shariaCouncil2);
        dao.grantRole(dao.SHARIA_COUNCIL_ROLE(), shariaCouncil3);
        
        // Set total community members
        dao.setTotalCommunityMembers(3);
        
        // Give IDRX to donors
        idrxToken.adminMint(donor1, 10000 * 10**18);
        idrxToken.adminMint(donor2, 10000 * 10**18);
    }
    
    function testCreateProposal() public {
        vm.startPrank(organizer);
        
        string[] memory checklist = new string[](2);
        checklist[0] = "Funds go to eligible recipients";
        checklist[1] = "No personal benefit for organizer";
        
        uint256 proposalId = dao.createProposal(
            "Build School in Village",
            "Detailed description of school project",
            1000 * 10**18,
            false,
            keccak256("mock_kyc_proof"),
            checklist
        );
        
        vm.stopPrank();
        
        assertEq(proposalId, 1);
        assertEq(dao.proposalCount(), 1);
        
        CommunityDAO.Proposal memory proposal = dao.getProposal(1);
        assertEq(proposal.organizer, organizer);
        assertEq(proposal.title, "Build School in Village");
        assertEq(proposal.fundingGoal, 1000 * 10**18);
        assertEq(uint8(proposal.status), uint8(CommunityDAO.ProposalStatus.Draft));
        assertEq(uint8(proposal.kycStatus), uint8(CommunityDAO.KYCStatus.Pending));
    }
    
    function testEmergencyProposal() public {
        vm.startPrank(organizer);
        
        uint256 proposalId = dao.createProposal(
            "Emergency Flood Relief",
            "Urgent flood relief needed",
            500 * 10**18,
            true, // emergency
            bytes32(0),
            new string[](0)
        );
        
        vm.stopPrank();
        
        CommunityDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertTrue(proposal.isEmergency);
        assertEq(uint8(proposal.kycStatus), uint8(CommunityDAO.KYCStatus.NotRequired));
    }
    
    function testKYCUpdate() public {
        vm.prank(organizer);
        uint256 proposalId = dao.createProposal(
            "Test Proposal",
            "Description",
            1000 * 10**18,
            false,
            keccak256("kyc_hash"),
            new string[](0)
        );
        
        // Update KYC status
        dao.updateKYCStatus(
            proposalId,
            CommunityDAO.KYCStatus.Verified,
            "KYC verified via mock ZK proof"
        );
        
        CommunityDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertEq(uint8(proposal.kycStatus), uint8(CommunityDAO.KYCStatus.Verified));
    }
    
    function testCommunityVoteFlow() public {
        // Create and verify proposal
        vm.prank(organizer);
        uint256 proposalId = dao.createProposal(
            "Test Campaign",
            "Description",
            1000 * 10**18,
            false,
            keccak256("kyc"),
            new string[](0)
        );
        
        dao.updateKYCStatus(proposalId, CommunityDAO.KYCStatus.Verified, "Verified");
        
        // Submit for vote
        vm.prank(organizer);
        dao.submitForCommunityVote(proposalId);
        
        CommunityDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertEq(uint8(proposal.status), uint8(CommunityDAO.ProposalStatus.CommunityVote));
        
        // Cast votes
        vm.prank(member1);
        dao.castVote(proposalId, 1); // For
        
        vm.prank(member2);
        dao.castVote(proposalId, 1); // For
        
        vm.prank(member3);
        dao.castVote(proposalId, 0); // Against
        
        // Fast forward time
        vm.warp(block.timestamp + 8 days);
        
        // Finalize vote
        dao.finalizeCommunityVote(proposalId);
        
        proposal = dao.getProposal(proposalId);
        assertEq(uint8(proposal.status), uint8(CommunityDAO.ProposalStatus.CommunityPassed));
        assertEq(proposal.votesFor, 2);
        assertEq(proposal.votesAgainst, 1);
    }
    
    function testShariaReviewFlow() public {
        // Create passed proposal
        vm.prank(organizer);
        uint256 proposalId = dao.createProposal(
            "Test Campaign",
            "Description",
            1000 * 10**18,
            true, // emergency
            bytes32(0),
            new string[](0)
        );
        
        vm.prank(organizer);
        dao.submitForCommunityVote(proposalId);
        
        vm.prank(member1);
        dao.castVote(proposalId, 1);
        vm.prank(member2);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + 8 days);
        dao.finalizeCommunityVote(proposalId);
        
        // Create bundle
        uint256[] memory proposals = new uint256[](1);
        proposals[0] = proposalId;
        uint256 bundleId = dao.createShariaReviewBundle(proposals);
        
        assertEq(bundleId, 1);
        
        // Sharia council reviews
        vm.prank(shariaCouncil1);
        dao.reviewProposal(
            bundleId,
            proposalId,
            true,
            CommunityDAO.CampaignType.ZakatCompliant,
            keccak256("sharia_proof_1")
        );
        
        vm.prank(shariaCouncil2);
        dao.reviewProposal(
            bundleId,
            proposalId,
            true,
            CommunityDAO.CampaignType.ZakatCompliant,
            keccak256("sharia_proof_2")
        );
        
        vm.prank(shariaCouncil3);
        dao.reviewProposal(
            bundleId,
            proposalId,
            true,
            CommunityDAO.CampaignType.ZakatCompliant,
            keccak256("sharia_proof_3")
        );
        
        // Finalize bundle
        vm.prank(shariaCouncil1);
        dao.finalizeShariaBundle(bundleId);
        
        CommunityDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertEq(uint8(proposal.status), uint8(CommunityDAO.ProposalStatus.ShariaApproved));
        assertEq(uint8(proposal.campaignType), uint8(CommunityDAO.CampaignType.ZakatCompliant));
    }
    
    function testFullDonationFlow() public {
        // Setup approved proposal
        vm.prank(organizer);
        uint256 proposalId = dao.createProposal(
            "Test Campaign",
            "Description",
            1000 * 10**18,
            true,
            bytes32(0),
            new string[](0)
        );
        
        vm.prank(organizer);
        dao.submitForCommunityVote(proposalId);
        
        vm.prank(member1);
        dao.castVote(proposalId, 1);
        vm.prank(member2);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + 8 days);
        dao.finalizeCommunityVote(proposalId);
        
        uint256[] memory proposals = new uint256[](1);
        proposals[0] = proposalId;
        uint256 bundleId = dao.createShariaReviewBundle(proposals);
        
        vm.prank(shariaCouncil1);
        dao.reviewProposal(bundleId, proposalId, true, CommunityDAO.CampaignType.ZakatCompliant, bytes32(0));
        
        vm.prank(shariaCouncil1);
        dao.finalizeShariaBundle(bundleId);
        
        // Create pool
        uint256 poolId = dao.createCampaignPool(proposalId);
        assertEq(poolId, 1);
        
        // Donor1 donates
        vm.startPrank(donor1);
        idrxToken.approve(address(dao), 500 * 10**18);
        dao.donate(poolId, 500 * 10**18);
        vm.stopPrank();
        
        // Check SBT minted
        uint256 tokenId = sbtToken.getTokenIdForDonorAndPool(donor1, poolId);
        assertEq(tokenId, 1);
        assertEq(sbtToken.ownerOf(tokenId), donor1);
        
        // Donor2 donates
        vm.startPrank(donor2);
        idrxToken.approve(address(dao), 600 * 10**18);
        dao.donate(poolId, 600 * 10**18);
        vm.stopPrank();
        
        // Check pool status
        CommunityDAO.CampaignPool memory pool = dao.getPool(poolId);
        assertEq(pool.raisedAmount, 1100 * 10**18);
        assertTrue(pool.raisedAmount >= pool.fundingGoal);
        
        // Organizer withdraws
        uint256 organizerBalanceBefore = idrxToken.balanceOf(organizer);
        vm.prank(organizer);
        dao.withdrawFunds(poolId);
        
        assertEq(idrxToken.balanceOf(organizer), organizerBalanceBefore + 1100 * 10**18);
    }
    
    function testFaucet() public {
        vm.startPrank(donor1);
        
        uint256 balanceBefore = idrxToken.balanceOf(donor1);
        idrxToken.faucet();
        uint256 balanceAfter = idrxToken.balanceOf(donor1);
        
        assertEq(balanceAfter - balanceBefore, 1000 * 10**18);
        
        // Try to claim again immediately (should fail)
        vm.expectRevert("MockIDRX: Faucet cooldown not expired");
        idrxToken.faucet();
        
        // Fast forward 24 hours
        vm.warp(block.timestamp + 24 hours + 1);
        
        // Should work now
        idrxToken.faucet();
        assertEq(idrxToken.balanceOf(donor1), balanceAfter + 1000 * 10**18);
        
        vm.stopPrank();
    }
    
    function testSBTNonTransferable() public {
        // Setup and create donation to mint SBT
        vm.prank(organizer);
        uint256 proposalId = dao.createProposal(
            "Test",
            "Desc",
            1000 * 10**18,
            true,
            bytes32(0),
            new string[](0)
        );
        
        vm.prank(organizer);
        dao.submitForCommunityVote(proposalId);
        vm.prank(member1);
        dao.castVote(proposalId, 1);
        vm.prank(member2);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + 8 days);
        dao.finalizeCommunityVote(proposalId);
        
        uint256[] memory proposals = new uint256[](1);
        proposals[0] = proposalId;
        uint256 bundleId = dao.createShariaReviewBundle(proposals);
        vm.prank(shariaCouncil1);
        dao.reviewProposal(bundleId, proposalId, true, CommunityDAO.CampaignType.Normal, bytes32(0));
        vm.prank(shariaCouncil1);
        dao.finalizeShariaBundle(bundleId);
        
        uint256 poolId = dao.createCampaignPool(proposalId);
        
        vm.startPrank(donor1);
        idrxToken.approve(address(dao), 100 * 10**18);
        dao.donate(poolId, 100 * 10**18);
        vm.stopPrank();
        
        uint256 tokenId = sbtToken.getTokenIdForDonorAndPool(donor1, poolId);
        
        // Try to transfer SBT (should fail)
        vm.prank(donor1);
        vm.expectRevert("SBT: Token is non-transferable (soulbound)");
        sbtToken.transferFrom(donor1, donor2, tokenId);
    }
}
