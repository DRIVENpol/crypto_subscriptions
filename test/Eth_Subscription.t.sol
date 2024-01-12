// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Eth_Subscription} from "../src/Eth_Subscription.sol";

contract Eth_SubscriptionTest is Test {
    // Global variables
    address public owner = address(1111111);
    address public feeReceiver = address(2222222);
    address public account = address(3333333);

    Eth_Subscription public ethSubscription;

    // Set up function
    function setUp() public {
        ethSubscription = new Eth_Subscription(
            1 ether,
            feeReceiver,
            owner
        );

        vm.deal(account, 10 ether);
    }

    // Test functions
    function testPaySubscription() public {
        bool _before = ethSubscription.activeSubscription(account);

        vm.startPrank(account);

        ethSubscription.createPayment{value: 1 ether}(1);

        bool _after = ethSubscription.activeSubscription(account);

        assertTrue(_before == false && _after == true, "Subscription not paid");
    }

    function testPaySubscriptionAndWait() public {
        bool _before = ethSubscription.activeSubscription(account);

        vm.startPrank(account);

        ethSubscription.createPayment{value: 1 ether}(1);
        vm.warp(block.timestamp + 15 days);

        bool _during = ethSubscription.activeSubscription(account);

        vm.warp(block.timestamp + 60 days);

        bool _after = ethSubscription.activeSubscription(account);

        assertTrue(_before == false && _during == true && _after == false);
    }

    function testProlongSubscription() public {
        vm.startPrank(account);

        ethSubscription.createPayment{value: 1 ether}(1);

        (,,uint256 endDateBeforeProlong) = ethSubscription.getPaymentDetails(account);
        // console2.log("endDateBeforeProlong: %s", endDateBeforeProlong);
        // console2.log("startDate: %s", _startDate);

        vm.warp(block.timestamp + 15 days);

        ethSubscription.createPayment{value: 2 ether}(2);

        (,,uint256 endDateAfterProlong) = ethSubscription.getPaymentDetails(account);
        // console2.log("endDateAfterProlong: %s", endDateAfterProlong);

        assert(endDateAfterProlong >= endDateBeforeProlong + 60 days);
    }

    function testPaySubscriptionBySendingEth() public {
        vm.startPrank(account);

        (bool success, ) = address(ethSubscription).call{value: 1 ether}("");

        bool _active = ethSubscription.activeSubscription(account);

        assert(success == true && _active == true);
    }

    // Fail if msg.value < ethFee
    function testPaySubscriptionBySendingEth_Err() public {
        vm.startPrank(account);

        (bool success, ) = address(ethSubscription).call{value: 0.9 ether}("");

        bool _active = ethSubscription.activeSubscription(account);

        assert(success == false && _active == false);
    }
}
