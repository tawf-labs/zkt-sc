// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;
import "forge-std/Script.sol";
import "../src/ZKTCampaignPool.sol";

/// @notice Helper script for admin to update IPFS CIDs for receipt NFTs
/// @dev Run this after uploading campaign reports/images to Pinata
contract UpdateNFTMetadata is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get deployed pool contract address
        address poolAddress = vm.envAddress("POOL_ADDRESS");
        ZKTCampaignPool pool = ZKTCampaignPool(poolAddress);
        
        // Get Pinata CID from environment
        string memory pinataCID = vm.envString("PINATA_CID");
        
        // Example: Update multiple NFTs with the same Pinata folder CID
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Updating NFT metadata via pool contract...");
        console.log("Pool address:", poolAddress);
        console.log("Pinata CID:", pinataCID);
        console.log("Number of NFTs to update:", tokenIds.length);
        
        // Batch update all receipts
        pool.batchUpdateReceiptMetadata(tokenIds, pinataCID);
        
        vm.stopBroadcast();
        
        console.log("\n=== Update Complete ===");
        console.log("Total NFTs updated:", tokenIds.length);
        console.log("IPFS URL:", string(abi.encodePacked("ipfs://", pinataCID)));
        console.log("\nDonors can now view their receipt at:");
        console.log(string(abi.encodePacked("https://ipfs.io/ipfs/", pinataCID)));
    }
    
    /// @notice Alternative: Update a single NFT
    function updateSingle() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolAddress = vm.envAddress("POOL_ADDRESS");
        
        uint256 tokenId = vm.envUint("TOKEN_ID");
        string memory pinataCID = vm.envString("PINATA_CID");
        
        ZKTCampaignPool pool = ZKTCampaignPool(poolAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Updating NFT #", tokenId);
        pool.updateReceiptMetadata(tokenId, pinataCID);
        console.log("Updated successfully!");
        console.log("IPFS URL:", string(abi.encodePacked("ipfs://", pinataCID)));
        
        vm.stopBroadcast();
    }
}
