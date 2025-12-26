// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TestUSDC.sol";
import "../src/ZKTCampaignPool.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address adminMultisig = vm.envAddress("ADMIN_MULTISIG");

        vm.startBroadcast();

        // 1. Deploy test USDC
        TestUSDC usdc = new TestUSDC(1_000_000_000_000);
        console.log("USDC:", address(usdc));

        // 2. Deploy campaign pool (escrow) - deployer is initial admin
        ZKTCampaignPool pool = new ZKTCampaignPool(
            deployer,
            address(usdc)
        );
        console.log("Pool:", address(pool));

        // 3. Create test campaign
        bytes32 testCampaign = keccak256("RAMADAN-2025-TEST");
        pool.createCampaign(
            testCampaign,
            block.timestamp,
            block.timestamp + 30 days
        );
        console.log("Campaign created: RAMADAN-2025-TEST");

        // 4. Approve test NGO
        bytes32 testNGO = keccak256("TELAGA-TEST");
        address testNGOWallet = 0x2ca80Cc5e254C45E99281F670d694B22E6a90FC4; // Replace with your test wallet
        pool.approveNGO(testNGO, testNGOWallet);
        console.log("NGO approved: TELAGA-TEST");
        console.log("NGO wallet:", testNGOWallet);

        // 5. Set allocation (100% to test NGO)
        pool.setAllocation(testCampaign, testNGO, 10_000);
        pool.lockAllocation(testCampaign);
        console.log("Allocation locked: 100% to TELAGA-TEST");

        // 6. Transfer admin rights to multisig
        pool.transferAdmin(adminMultisig);
        console.log("Admin transferred to:", adminMultisig);

        vm.stopBroadcast();
    }
}
