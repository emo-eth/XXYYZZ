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

        test = new XXYYZZ(address(this),address(this),5,new uint24[](0),address(0));
        mintPrice = test.MINT_PRICE();
        rerollPrice = test.REROLL_PRICE();
        rerollSpecificPrice = test.REROLL_PRICE();
        finalizePrice = test.FINALIZE_PRICE();
        maxBatchSize = test.MAX_SPECIFIC_BATCH_SIZE();
        allowEther = true;
    }

    function _batchCommitAndWarp(uint256[] memory ids, bytes32 salt) internal {
        bytes32 computedCommitment = test.computeBatchCommitment(address(this), ids, salt);
        test.commit(computedCommitment);
        vm.warp(block.timestamp + 2 minutes);
    }

    /**
     * @notice when using vm.warp, retrieve block.timestamp in a way that
     *         via-ir cannot optimize away, since it assumes expressions using
     *         block.timestamp are constant
     */
    function _timestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function _mintSpecific(uint256[] memory ids, bytes32 salt) internal {
        bytes32 computedCommitment = test.computeBatchCommitment(address(this), ids, salt);
        test.commit(computedCommitment);

        vm.warp(this._timestamp() + 2 minutes);

        test.batchMintSpecific{value: ids.length * mintPrice}(ids, salt);
    }

    function _mintSpecific(uint256 id, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), uint24(id), salt);
        test.commit(commitmentHash);

        vm.warp(this._timestamp() + 2 minutes);

        test.mintSpecific{value: mintPrice}(id, salt);
    }
}
