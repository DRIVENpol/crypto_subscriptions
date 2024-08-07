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
        vm.deal(owner, 1 ether);
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

    function testWithdrawFees() public {
        vm.startPrank(account);

        ethSubscription.createPayment{value: 1 ether}(1);

        vm.stopPrank();

        vm.startPrank(owner);

        uint256 _before = feeReceiver.balance;
        // console2.log("feeReceiver.balance: %s", _before);

        ethSubscription.withdrawFees();

        uint256 _after = feeReceiver.balance;
        // console2.log("feeReceiver.balance: %s", _after);

        assert(_before < _after && _after == 1 ether);
    }

    function testChangeFee() public {
        vm.startPrank(owner);

        uint256 _feeBefore = ethSubscription.getEthFee();

        ethSubscription.changeFee(2 ether);

        uint256 _feeAfter = ethSubscription.getEthFee();

        assert(_feeBefore != _feeAfter && _feeAfter == 2 ether);
    }

    function testChangeFeeCollector() public {
        vm.startPrank(owner);

        address _feeCollectorBefore = ethSubscription.getFeeCollector();

        ethSubscription.changeFeeCollector(account);

        address _feeCollectorAfter = ethSubscription.getFeeCollector();

        assert(_feeCollectorBefore != _feeCollectorAfter && _feeCollectorAfter == account);
    }

    function testChangeOwner() public {
        // No YUL: changeOwner      | 3525 gas
        // YUL: changeOwner         | 3363 gas
        vm.startPrank(owner);

        address _ownerBefore = ethSubscription.getOwner();

        ethSubscription.changeOwner(account);

        vm.stopPrank();

        vm.startPrank(account);

        address _pendingBefore = ethSubscription.getPendingOwner();

        ethSubscription.acceptOwnership();

        address _pendingAfter = ethSubscription.getPendingOwner();

        address _ownerAfter = ethSubscription.getOwner();

        assert(_ownerBefore != _ownerAfter && _ownerAfter == account && _pendingBefore == account && _pendingAfter == address(0));
    }

    function testChangeOwnerFuzz(address _newOwner) public {
        vm.assume(_newOwner != address(0) && _newOwner != address(0xdead));
        // No YUL: changeOwner      | 3525 gas
        // YUL: changeOwner         | 3363 gas
        vm.startPrank(owner);

        address _ownerBefore = ethSubscription.getOwner();

        ethSubscription.changeOwner(_newOwner);

        address _pendingBefore = ethSubscription.getPendingOwner();

        vm.stopPrank();
        vm.startPrank(_newOwner);

        ethSubscription.acceptOwnership();

        address _pendingAfter = ethSubscription.getPendingOwner();

        address _ownerAfter = ethSubscription.getOwner();

        assert(_ownerBefore != _ownerAfter && _ownerAfter == _newOwner && _pendingBefore == _newOwner && _pendingAfter == address(0));
    }
}
