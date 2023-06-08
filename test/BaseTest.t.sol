// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";
import {TestPlus} from "solady-test/utils/TestPlus.sol";

contract BaseTest is Test, TestPlus {
    error CannotReceiveEther();

    XXYYZZ test;
    uint256 mintPrice;
    uint256 rerollPrice;
    uint256 rerollSpecificPrice;
    uint256 finalizePrice;
    uint256 maxBatchSize;
    bool allowEther;

    receive() external payable {
        if (!allowEther) {
            revert CannotReceiveEther();
        }
    }

    function setUp() public {
        vm.warp(10_000 days);

        test = new XXYYZZ(address(this),5,false);
        mintPrice = test.MINT_PRICE();
        rerollPrice = test.REROLL_PRICE();
        rerollSpecificPrice = test.REROLL_PRICE();
        finalizePrice = test.FINALIZE_PRICE();
        maxBatchSize = test.MAX_BATCH_SIZE();
        allowEther = true;
    }

    function _batchCommitAndWarp(uint256[] memory ids, bytes32 salt) internal {
        bytes32 computedCommitment = test.computeBatchCommitment(address(this), ids, salt);
        test.commit(computedCommitment);
        vm.warp(block.timestamp + 2 minutes);
    }
}
