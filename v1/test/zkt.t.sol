// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/TestUSDC.sol";
import "../src/ZKTCampaignPool.sol";

contract ZKTFlowTest is Test {
    TestUSDC usdc;
    ZKTCampaignPool pool;

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
        pool = new ZKTCampaignPool(admin, address(usdc));
        
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

        vm.startPrank(donor);
        usdc.approve(address(pool), 1_000_000);
        pool.donate(CAMPAIGN, 1_000_000);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), 1_000_000);

        vm.prank(admin);
        pool.disburse(
            CAMPAIGN,
            _singleBytes32(NGO)
        );

        assertEq(usdc.balanceOf(ngoBank), 1_000_000);
    }

    function _singleBytes32(bytes32 x) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](1);
        arr[0] = x;
    }
}
