// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";
import {XXYYZZCore} from "../src/XXYYZZCore.sol";
import {CommitReveal} from "../src/lib/CommitReveal.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Solarray} from "solarray/Solarray.sol";

contract XXYYZZFinalizeRerollTest is BaseTest {
    function testBatchRerollSpecific_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecific(new uint256[](maxBatchSize+1), new uint256[](maxBatchSize+1), bytes32(0));
    }

    function testBatchRerollSpecific() public {
        uint256[] memory ids = Solarray.uint256s(1, 2, 3);
        bytes32 salt = bytes32(0);
        _mintSpecific(ids, salt);
        assertEq(test.ownerOf(1), address(this));
        assertEq(test.ownerOf(2), address(this));
        assertEq(test.ownerOf(3), address(this));
        uint256[] memory newIds = Solarray.uint256s(4, 5, 6);
        _batchCommitAndWarp(newIds, salt);
        bool[] memory result = test.batchRerollSpecific{value: 3 * rerollSpecificPrice}(ids, newIds, salt);
        assertEq(result.length, 3);
        assertEq(result[0], true);
        assertEq(result[1], true);
        assertEq(result[2], true);
        assertEq(test.ownerOf(4), address(this));
        assertEq(test.ownerOf(5), address(this));
        assertEq(test.ownerOf(6), address(this));

        ids = Solarray.uint256s(4, 5);
        newIds = Solarray.uint256s(7, 6);
        uint256 prevBalance = address(this).balance;
        vm.expectCall(address(this), rerollSpecificPrice, "");
        _batchCommitAndWarp(newIds, salt);
        result = test.batchRerollSpecific{value: 2 * rerollSpecificPrice}(ids, newIds, salt);
        assertEq(result.length, 2);
        assertEq(result[0], true);
        assertEq(result[1], false);
        assertEq(test.ownerOf(6), address(this));
        assertEq(test.ownerOf(7), address(this));
        assertEq(address(this).balance, prevBalance - rerollSpecificPrice);
    }

    function testBatchRerollSpecificAndFinalize_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecificAndFinalize(new uint256[](maxBatchSize+1), new uint256[](maxBatchSize+1), bytes32(0));
    }
}
