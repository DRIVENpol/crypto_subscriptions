// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Eth_Subscription {

    // Slot 0
    uint64 private ethFee;
    address private feeCollector;

    // Slot 1
    address private owner;
    address private pendingOwner;

    // keccak256(bytes("PaymentReceived(address,uint64,uint256)"))
    bytes32 public constant PAYMENT_RECEIVED_SIG = 0xef313d75e17f2cc62ca74eb3526393a82cde1ccf1fbfded3a56d8b3a4e00eb33;

    // bytes4(keccak256(bytes("FailedPayment()")))
    bytes4 public constant ERROR_FAILED_PAYMENT = 0x9d5c8847;

    // Payment struct
    struct EthPayment {
        address user; // Slot 0
        uint64 paymentMoment; // Slot 0
        uint256 paymentExpire; // Slot 1
    }

    // Address => Payment
    mapping(address => EthPayment) public payments;

    // Events
    event PaymentReceived(address indexed user, uint64 indexed paymentMoment, uint256 indexed paymentExpire);

    // Errors
    error FailedPayment();

    // Constructor
    constructor(uint64 _ethFee, address _feeCollector, address _owner) {
        ethFee = _ethFee;
        feeCollector = _feeCollector;
        owner = _owner;
    }

    // Modifier
    modifier onlyOwner() {
        assembly {
            if iszero(eq(caller(), sload(owner.slot))) {
                revert(0, 0)
            }
        }

        _;
    }

    // Receive function
    receive() external payable {
        // How many months the value can cover
        // Users SHOULD send only exact value otherwise they will lose the decimal part
        uint256 _months = msg.value / ethFee;

        createPayment(uint64(_months));
    }

    function createPayment(uint64 _months) public payable {
        assembly {
            // Store the error signature in memory at slot 0
            mstore(0x00, ERROR_FAILED_PAYMENT)

            // Read the subscription fee
            let fee := and(sload(ethFee.slot), 0xffffffffffffffff)

            // If msg.value != fee * _months revert
            if iszero(eq(callvalue(), mul(fee, _months))) {
                revert(0x00, 0x04)
            }

            // If _months == 0 revert
            if eq(_months, 0) {
                revert(0x00, 0x04)
            }

            mstore(0x00, caller()) // Store the msg.sender
            mstore(0x20, payments.slot) // Store the 'payments' slot
            mstore(0x40, keccak256(0x00, 0x40)) // Compute the location of 'payments[msg.sender]'

            let _startDate := timestamp() // Start date = block.timestamp
            let _endDate:= add(timestamp(), mul(_months, 2629743)) // End date = block.timestamp + _months * 2629743 (seconds in a month)
            
            sstore(mload(0x40), or(caller(), shl(mul(20, 8), _startDate)))

            let _oldPaymentExpire := sload(add(mload(0x40), 1))

            // If the user never paid before
            // Store the new end date
            if eq(_oldPaymentExpire, 0) {
                sstore(add(mload(0x40), 1), _endDate)
            }

            // If user already paid in the past
            if iszero(eq(_oldPaymentExpire, 0)) {
                // If the subscription is not active
                // Store the new end date
                if lt(_oldPaymentExpire, timestamp()) {
                   sstore(add(mload(0x40), 1), _endDate)
                }

                // If the subscription is active
                // Extend the subscription
                if gt(_oldPaymentExpire, timestamp()) {
                    sstore(add(mload(0x40), 1), add(_oldPaymentExpire, mul(_months, 2629743)))
                }
            }

            // Emit the PaymentReceived event
            log4(0, 0, PAYMENT_RECEIVED_SIG, caller(), _startDate, _endDate)
        }
    }

    function changeFee(uint64 _newFee) external payable onlyOwner {
        assembly {
            if eq(_newFee, 0) {
                revert(0, 0)
            }

            // 0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2 1bc16d674ec80000 <- Slot 0
            sstore(ethFee.slot, or(mload(ethFee.slot), _newFee))
        }
    }

    function changeFeeCollector(address _newFeeCollector) external payable onlyOwner {
        assembly {
            if eq(_newFeeCollector, 0x00) {
                revert(0, 0)
            }

            if eq(_newFeeCollector, 0xdead) {
                revert(0, 0)
            }

            // 0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2 1bc16d674ec80000 <- Slot 0
            sstore(feeCollector.slot, or(mload(feeCollector.slot), shl(mul(8, 8), _newFeeCollector)))
        }
    }

    function changeOwner(address _newOwner) external payable onlyOwner {
        assembly {
            if eq(_newOwner, 0x00) {
                revert(0,0)
            }

            if eq(_newOwner, 0xdead) {
                revert(0,0)
            }

            sstore(pendingOwner.slot, _newOwner)
        }
    }

    function acceptOwnership() external payable {
        assembly {
            if iszero(eq(caller(), sload(pendingOwner.slot))) {
                revert(0,0)
            }

            sstore(owner.slot, caller())
            sstore(pendingOwner.slot, 0x00)
        }
    }

    function withdrawFees() external payable onlyOwner {
        assembly {
            if iszero(call(gas(), shr(64, sload(feeCollector.slot)), selfbalance(), 0x00, 0x00, 0x00, 0x00)) {
                revert(0, 0)
            }
        }
    }

    function activeSubscription(address user) external view returns (bool _res) {
        assembly {
            mstore(0x00, user)
            mstore(0x20, payments.slot)

            let _location := add(keccak256(0x00, 0x40), 1)
            let _paymentExpire := sload(_location)

            switch eq(_paymentExpire, 0)
            case 1 {
                _res := 0
            }
            default {
                if gt(_paymentExpire, timestamp()) {
                    _res := 1 
                }
                if lt(_paymentExpire, timestamp()) {

                    _res := 0
                }
            }
        }
    }

    function getPaymentDetails(address user) public view returns(address, uint256, uint256) {
        EthPayment storage payment = payments[user];

        return (payment.user, payment.paymentMoment, payment.paymentExpire);
    }

    function getEthFee() public view returns(uint64) {
        return ethFee;
    }

    function getFeeCollector() public view returns(address) {
        return feeCollector;
    }

    function getOwner() public view returns(address) {
        return owner;
    }

    function getPendingOwner() public view returns(address) {
        return pendingOwner;
    }
}
