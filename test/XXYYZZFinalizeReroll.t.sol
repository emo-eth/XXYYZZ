// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TestPlus} from "solady-test/utils/TestPlus.sol";
import {Test} from "forge-std/Test.sol";
// import {XXYYZZCore as XXYYZZ} from "../src/XXYYZZCore.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";
import {XXYYZZCore} from "../src/XXYYZZCore.sol";
import {CommitReveal} from "../src/lib/CommitReveal.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Solarray} from "solarray/Solarray.sol";

contract XXYYZZFinalizeRerollTest is Test, TestPlus {
    error CannotReceiveEther();

    XXYYZZ test;
    uint256 mintPrice;
    uint256 rerollPrice;
    uint256 rerollSpecificPrice;
    uint256 finalizePrice;
    uint256 maxBatchSize;
    bool allowEther;

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

    receive() external payable {
        if (!allowEther) {
            revert CannotReceiveEther();
        }
    }

    function testRerollSpecificUnprotected() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        test.rerollSpecificUnprotected{value: rerollSpecificPrice}(1, 2);
        assertEq(test.ownerOf(2), address(this));
        assertEq(test.numMinted(), 1);
    }

    function testRerollSpecificUnprotected_Unavailable() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        vm.expectRevert(XXYYZZCore.Unavailable.selector);
        test.rerollSpecificUnprotected{value: rerollSpecificPrice}(1, 1);
    }

    function testBatchRerollSpecific_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecific(new uint256[](maxBatchSize+1), new uint256[](maxBatchSize+1), bytes32(0));
    }

    function testBatchRerollSpecificUnprotected() public {
        uint256[] memory ids = Solarray.uint256s(1, 2, 3);
        test.batchMintSpecificUnprotected{value: 3 * mintPrice}(ids);
        assertEq(test.ownerOf(1), address(this));
        assertEq(test.ownerOf(2), address(this));
        assertEq(test.ownerOf(3), address(this));
        uint256[] memory newIds = Solarray.uint256s(4, 5, 6);
        bool[] memory result = test.batchRerollSpecificUnprotected{value: 3 * rerollSpecificPrice}(ids, newIds);
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
        result = test.batchRerollSpecificUnprotected{value: 2 * rerollSpecificPrice}(ids, newIds);
        assertEq(result.length, 2);
        assertEq(result[0], true);
        assertEq(result[1], false);
        assertEq(test.ownerOf(6), address(this));
        assertEq(test.ownerOf(7), address(this));
        assertEq(address(this).balance, prevBalance - rerollSpecificPrice);
    }

    function testBatchRerollSpecificUnprotected_ArrayLengthMismatch() public {
        vm.expectRevert(XXYYZZCore.ArrayLengthMismatch.selector);
        test.batchRerollSpecificUnprotected{value: 3 * rerollSpecificPrice}(
            new uint256[](maxBatchSize +1), new uint256[](maxBatchSize )
        );
    }

    function testBatchRerollSpecificUnprotected_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecificUnprotected{value: 3 * rerollSpecificPrice}(
            new uint256[](maxBatchSize +1), new uint256[](maxBatchSize +1)
        );
    }

    function testBatchRerollSpecificUnprotected_NoneAvailable() public {
        uint256[] memory ids = Solarray.uint256s(1, 2, 3);
        test.batchMintSpecificUnprotected{value: 3 * mintPrice}(ids);
        vm.expectRevert(XXYYZZCore.NoneAvailable.selector);
        test.batchRerollSpecificUnprotected{value: 3 * rerollSpecificPrice}(ids, ids);
    }

    function testRerollSpecificAndFinalizeUnprotected() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        test.rerollSpecificAndFinalizeUnprotected{value: rerollSpecificPrice + finalizePrice}(1, 2);
        assertEq(test.ownerOf(2), address(this));
        assertTrue(test.isFinalized(2));
        assertEq(test.numMinted(), 1);
    }

    function testRerollSpecificAndFinalizeUnprotected_InvalidPayment() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.rerollSpecificAndFinalizeUnprotected{value: rerollSpecificPrice + finalizePrice - 1}(1, 2);
    }

    function testRerollSpecificAndFinalizeUnprotected_Unavailable() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        vm.expectRevert(XXYYZZCore.Unavailable.selector);
        test.rerollSpecificAndFinalizeUnprotected{value: rerollSpecificPrice + finalizePrice}(1, 1);
    }

    function testBatchRerollSpecificAndFinalize_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecificAndFinalize(new uint256[](maxBatchSize+1), new uint256[](maxBatchSize+1), bytes32(0));
    }

    function testBatchRerollSpecificAndFinalizeUnprotected() public {
        uint256[] memory ids = Solarray.uint256s(1, 2, 3);
        test.batchMintSpecificUnprotected{value: 3 * mintPrice}(ids);

        uint256[] memory newIds = Solarray.uint256s(4, 5, 6);
        bool[] memory result = test.batchRerollSpecificAndFinalizeUnprotected{
            value: 3 * (rerollSpecificPrice + finalizePrice)
        }(ids, newIds);
        assertEq(result.length, 3);
        assertEq(result[0], true);
        assertEq(result[1], true);
        assertEq(result[2], true);
        assertEq(test.ownerOf(4), address(this));
        assertEq(test.ownerOf(5), address(this));
        assertEq(test.ownerOf(6), address(this));
        assertTrue(test.isFinalized(4));
        assertTrue(test.isFinalized(5));
        assertTrue(test.isFinalized(6));
        assertEq(address(test).balance, (mintPrice + rerollSpecificPrice + finalizePrice) * 3);
        ids = Solarray.uint256s(7, 8);
        newIds = Solarray.uint256s(8, 9);
        test.batchMintSpecificUnprotected{value: 2 * mintPrice}(ids);

        uint256 prevBalance = address(this).balance;
        vm.expectCall(address(this), rerollSpecificPrice + finalizePrice, "");
        result = test.batchRerollSpecificAndFinalizeUnprotected{value: 2 * (rerollSpecificPrice + finalizePrice)}(
            ids, newIds
        );
        assertEq(result.length, 2);
        assertEq(result[0], false);
        assertEq(result[1], true);
        assertEq(test.ownerOf(7), address(this));
        assertEq(test.ownerOf(9), address(this));
        assertEq(address(this).balance, prevBalance - (rerollSpecificPrice + finalizePrice));
    }

    function testBatchRerollSpecificAndFinalizeUnprotected_NoneAvailable() public {
        uint256[] memory ids = Solarray.uint256s(1, 2, 3);
        test.batchMintSpecificUnprotected{value: 3 * mintPrice}(ids);
        vm.expectRevert(XXYYZZCore.NoneAvailable.selector);
        test.batchRerollSpecificAndFinalizeUnprotected{value: 3 * (rerollSpecificPrice + finalizePrice)}(ids, ids);
    }

    function testBatchRerollSpecificAndFinalizeUnprotected_ArrayLengthMismatch() public {
        uint256[] memory ids = Solarray.uint256s(1, 2, 3);
        uint256[] memory newIds = Solarray.uint256s(4, 5);
        test.batchMintSpecificUnprotected{value: 3 * mintPrice}(ids);
        vm.expectRevert(XXYYZZCore.ArrayLengthMismatch.selector);
        test.batchRerollSpecificAndFinalizeUnprotected{value: 3 * (rerollSpecificPrice + finalizePrice)}(ids, newIds);
    }

    function testBatchRerollSpecificAndFinalizeUnprotected_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecificAndFinalizeUnprotected{value: 3 * (rerollSpecificPrice + finalizePrice)}(
            new uint256[](maxBatchSize +1), new uint256[](maxBatchSize +1)
        );
    }
}
