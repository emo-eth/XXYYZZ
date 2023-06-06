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
}
