// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/MockIDRX.sol";
import "../src/tokens/SBTToken.sol";
import "../src/DAO/CommunityDAO.sol";

/**
 * @title DeployDAO
 * @notice Deployment script for ZKT Community DAO system on Base Sepolia
 * @dev Run with: forge script script/DeployDAO.s.sol:DeployDAO --rpc-url base_sepolia --broadcast --verify
 */
contract DeployDAO is Script {
    // Deployment addresses (will be set after deployment)
    MockIDRX public idrxToken;
    SBTToken public sbtToken;
    CommunityDAO public dao;
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy MockIDRX token
        console.log("\n1. Deploying MockIDRX token...");
        idrxToken = new MockIDRX();
        console.log("MockIDRX deployed at:", address(idrxToken));
        
        // 2. Deploy SBTToken
        console.log("\n2. Deploying SBTToken...");
        sbtToken = new SBTToken();
        console.log("SBTToken deployed at:", address(sbtToken));
        
        // 3. Deploy CommunityDAO
        console.log("\n3. Deploying CommunityDAO...");
        dao = new CommunityDAO(address(idrxToken), address(sbtToken));
        console.log("CommunityDAO deployed at:", address(dao));
        
        // 4. Grant MINTER_ROLE to DAO contract in SBTToken
        console.log("\n4. Granting MINTER_ROLE to DAO...");
        sbtToken.grantRole(sbtToken.MINTER_ROLE(), address(dao));
        console.log("MINTER_ROLE granted to DAO");
        
        // 5. Setup initial roles for deployer (for testing)
        console.log("\n5. Setting up initial roles...");
        dao.grantRole(dao.ORGANIZER_ROLE(), deployer);
        dao.grantRole(dao.COMMUNITY_MEMBER_ROLE(), deployer);
        dao.grantRole(dao.SHARIA_COUNCIL_ROLE(), deployer);
        dao.grantRole(dao.KYC_ORACLE_ROLE(), deployer);
        console.log("Initial roles granted to deployer");
        
        // 6. Set initial community members count (for testing)
        console.log("\n6. Setting initial community members count...");
        dao.setTotalCommunityMembers(10); // Set to 10 for testing
        console.log("Total community members set to 10");
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("\n====== DEPLOYMENT SUMMARY ======");
        console.log("Network: Base Sepolia");
        console.log("Deployer:", deployer);
        console.log("\nContract Addresses:");
        console.log("MockIDRX:", address(idrxToken));
        console.log("SBTToken:", address(sbtToken));
        console.log("CommunityDAO:", address(dao));
        console.log("\nNext Steps:");
        console.log("1. Verify contracts on Basescan");
        console.log("2. Grant roles to actual organizers, community members, and Sharia council");
        console.log("3. Update totalCommunityMembers count as members are added");
        console.log("4. Test the faucet: cast send", address(idrxToken), "\"faucet()\" --rpc-url base_sepolia --private-key $PRIVATE_KEY");
        console.log("================================\n");
    }
}
