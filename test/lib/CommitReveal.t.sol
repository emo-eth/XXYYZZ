// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {TestCommitReveal} from "../helpers/TestCommitReveal.sol";
import {CommitReveal} from "../../src/lib/CommitReveal.sol";

contract CommitRevealTest is Test {
    TestCommitReveal test;

    function setUp() public virtual {
        test = new TestCommitReveal();
    }

    function testCommitReveal() public {
        bytes32 commitment = keccak256(abi.encode("test"));
        uint256 originalTimestamp = block.timestamp;
        test.commit(commitment);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitment);
        vm.warp(originalTimestamp + test.COMMITMENT_DELAY());
        test.assertCommittedReveal(commitment);
        vm.warp(originalTimestamp + test.COMMITMENT_LIFESPAN() + 1);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitment);
    }

    function testBatchCommitReveal() public {
        bytes32[] memory commitments = new bytes32[](3);
        commitments[0] = keccak256(abi.encode("test1"));
        commitments[1] = keccak256(abi.encode("test2"));
        commitments[2] = keccak256(abi.encode("test3"));
        uint256 originalTimestamp = block.timestamp;
        test.batchCommit(commitments);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitments[0]);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitments[1]);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitments[2]);

        vm.warp(originalTimestamp + test.COMMITMENT_DELAY());
        test.assertCommittedReveal(commitments[0]);
        test.assertCommittedReveal(commitments[1]);
        test.assertCommittedReveal(commitments[2]);

        uint256 maxBatchSize = test.MAX_BATCH_SIZE();

        vm.expectRevert(CommitReveal.MaxBatchSizeExceeded.selector);
        test.batchCommit(new bytes32[](maxBatchSize + 1));
    }
}
