// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;
import "forge-std/Test.sol";
import "../src/TestUSDC.sol";
import "../src/ZKTCampaignPool.sol";
import "../src/ZKTReceiptNFT.sol";

contract ZKTFlowTest is Test {
    TestUSDC usdc;
    ZKTCampaignPool pool;
    ZKTReceiptNFT nft;

    address admin = address(0xA11CE);
    address donor = address(0xBEEF);
    address ngoBank = address(0xCAFE);

    bytes32 CAMPAIGN = keccak256("RAMADAN-2025");
    bytes32 NGO = keccak256("TELAGA");

    function setUp() public {
        vm.deal(admin, 100 ether);
        vm.deal(donor, 100 ether);
        
        vm.startPrank(admin);

        usdc = new TestUSDC(1_000_000_000_000);
        
        // Deploy NFT with zero address (no minter yet)
        nft = new ZKTReceiptNFT(address(0));
        
        // Deploy pool with NFT address
        pool = new ZKTCampaignPool(admin, address(usdc), address(nft));
        
        // Set pool as the minter
        nft.setMinter(address(pool));
        
        usdc.transfer(donor, 1_000_000);

        vm.stopPrank();
    }

    function testFullDonationFlow() public {
        vm.prank(admin);
        pool.createCampaign(
            CAMPAIGN,
            block.timestamp,
            block.timestamp + 7 days
        );

        vm.prank(admin);
        pool.approveNGO(NGO, ngoBank);

        vm.prank(admin);
        pool.setAllocation(CAMPAIGN, NGO, 10_000);

        vm.prank(admin);
        pool.lockAllocation(CAMPAIGN);

        // Check NFT state before donation
        assertEq(nft.balanceOf(donor), 0);
        assertEq(nft.totalSupply(), 0);

        vm.startPrank(donor);
        usdc.approve(address(pool), 1_000_000);
        pool.donate(CAMPAIGN, 1_000_000);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), 1_000_000);
        
        // Check NFT was minted to donor
        assertEq(nft.balanceOf(donor), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(1), donor);
        
        // Check receipt metadata
        (bytes32 campaignId, uint256 amount, bool isImpact, string memory ipfsCID,) = nft.receipts(1);
        assertEq(campaignId, CAMPAIGN);
        assertEq(amount, 1_000_000);
        assertEq(isImpact, false);
        assertEq(bytes(ipfsCID).length, 0); // Empty initially

        vm.prank(admin);
        pool.disburse(
            CAMPAIGN,
            _singleBytes32(NGO)
        );

        assertEq(usdc.balanceOf(ngoBank), 1_000_000);
    }

    function testNFTMetadataUpdate() public {
        // Setup campaign
        vm.prank(admin);
        pool.createCampaign(
            CAMPAIGN,
            block.timestamp,
            block.timestamp + 7 days
        );

        vm.prank(admin);
        pool.approveNGO(NGO, ngoBank);

        vm.prank(admin);
        pool.setAllocation(CAMPAIGN, NGO, 10_000);

        vm.prank(admin);
        pool.lockAllocation(CAMPAIGN);

        // Donor donates
        vm.startPrank(donor);
        usdc.approve(address(pool), 500_000);
        pool.donate(CAMPAIGN, 500_000);
        vm.stopPrank();

        // NFT minted with empty CID
        uint256 tokenId = 1;
        (,,, string memory ipfsCID,) = nft.receipts(tokenId);
        assertEq(bytes(ipfsCID).length, 0);

        // Admin updates IPFS CID via pool contract
        string memory pinataFolder = "QmPinataFolderHashWithReportsAndImages123";
        
        vm.prank(admin);
        pool.updateReceiptMetadata(tokenId, pinataFolder);

        // Check updated metadata
        (,,, string memory updatedCID,) = nft.receipts(tokenId);
        assertEq(updatedCID, pinataFolder);
        
        // Check tokenURI
        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, string(abi.encodePacked("ipfs://", pinataFolder)));
    }

    function testBatchUpdateMetadata() public {
        // Setup campaign
        vm.prank(admin);
        pool.createCampaign(
            CAMPAIGN,
            block.timestamp,
            block.timestamp + 7 days
        );

        vm.prank(admin);
        pool.approveNGO(NGO, ngoBank);

        vm.prank(admin);
        pool.setAllocation(CAMPAIGN, NGO, 10_000);

        vm.prank(admin);
        pool.lockAllocation(CAMPAIGN);

        address donor2 = address(0xD00D);
        vm.prank(admin);
        usdc.transfer(donor2, 500_000);

        // Multiple donations
        vm.startPrank(donor);
        usdc.approve(address(pool), 1_000_000);
        pool.donate(CAMPAIGN, 300_000);
        pool.donate(CAMPAIGN, 200_000);
        vm.stopPrank();

        vm.startPrank(donor2);
        usdc.approve(address(pool), 500_000);
        pool.donate(CAMPAIGN, 150_000);
        vm.stopPrank();

        // Batch update all receipts with Pinata CID
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        
        string memory pinataCID = "QmRamadan2025CampaignReports";
        
        vm.prank(admin);
        pool.batchUpdateReceiptMetadata(tokenIds, pinataCID);

        // Verify all NFTs updated
        for (uint256 i = 0; i < 3; i++) {
            (,,, string memory cid,) = nft.receipts(i + 1);
            assertEq(cid, pinataCID);
        }
    }

    function testNFTIsSoulbound() public {
        // Setup and donate
        vm.prank(admin);
        pool.createCampaign(
            CAMPAIGN,
            block.timestamp,
            block.timestamp + 7 days
        );

        vm.prank(admin);
        pool.approveNGO(NGO, ngoBank);

        vm.prank(admin);
        pool.setAllocation(CAMPAIGN, NGO, 10_000);

        vm.prank(admin);
        pool.lockAllocation(CAMPAIGN);

        vm.startPrank(donor);
        usdc.approve(address(pool), 100_000);
        pool.donate(CAMPAIGN, 100_000);
        vm.stopPrank();

        uint256 tokenId = 1;
        address recipient = address(0x1234);

        // Try to transfer - should revert with "SOULBOUND"
        vm.prank(donor);
        vm.expectRevert("SOULBOUND");
        nft.transferFrom(donor, recipient, tokenId);
    }

    function testMultipleDonationsMultipleNFTs() public {
        // Setup
        vm.prank(admin);
        pool.createCampaign(
            CAMPAIGN,
            block.timestamp,
            block.timestamp + 7 days
        );

        vm.prank(admin);
        pool.approveNGO(NGO, ngoBank);

        vm.prank(admin);
        pool.setAllocation(CAMPAIGN, NGO, 10_000);

        vm.prank(admin);
        pool.lockAllocation(CAMPAIGN);

        address donor2 = address(0xD00D);
        vm.prank(admin);
        usdc.transfer(donor2, 500_000);

        // First donation
        vm.startPrank(donor);
        usdc.approve(address(pool), 1_000_000);
        pool.donate(CAMPAIGN, 300_000);
        vm.stopPrank();

        // Second donation from same donor
        vm.startPrank(donor);
        pool.donate(CAMPAIGN, 200_000);
        vm.stopPrank();

        // Third donation from different donor
        vm.startPrank(donor2);
        usdc.approve(address(pool), 500_000);
        pool.donate(CAMPAIGN, 150_000);
        vm.stopPrank();

        // Check NFT distribution
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.balanceOf(donor), 2); // donor has 2 NFTs
        assertEq(nft.balanceOf(donor2), 1); // donor2 has 1 NFT
        
        assertEq(nft.ownerOf(1), donor);
        assertEq(nft.ownerOf(2), donor);
        assertEq(nft.ownerOf(3), donor2);

        // Check amounts
        (,uint256 amount1,,, ) = nft.receipts(1);
        (,uint256 amount2,,, ) = nft.receipts(2);
        (,uint256 amount3,,, ) = nft.receipts(3);
        
        assertEq(amount1, 300_000);
        assertEq(amount2, 200_000);
        assertEq(amount3, 150_000);
    }

    function _singleBytes32(bytes32 x) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](1);
        arr[0] = x;
    }
}
