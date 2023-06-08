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

    /**
     * @notice deal with via-ir block.timestamp issue
     */
    function _timestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function testCommitReveal() public {
        bytes32 commitment = keccak256(abi.encode("test"));
        uint256 originalTimestamp = this._timestamp();
        emit log_named_uint("originalTimestamp", originalTimestamp);
        test.commit(commitment);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitment);
        uint256 revealTimestamp = originalTimestamp + test.COMMITMENT_DELAY();
        emit log_named_uint("warping to revealTimestamp", revealTimestamp);
        vm.warp(revealTimestamp);
        emit log_named_uint("block.timestamp after warp", block.timestamp);
        test.assertCommittedReveal(commitment);

        uint256 outOfLifespanTimestamp = originalTimestamp + test.COMMITMENT_LIFESPAN() + 1;
        emit log_named_uint("warping to outOfLifespanTimestamp", outOfLifespanTimestamp);
        vm.warp(outOfLifespanTimestamp);
        emit log_named_uint("block.timestamp after warp", block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, originalTimestamp));
        test.assertCommittedReveal(commitment);
    }
}
