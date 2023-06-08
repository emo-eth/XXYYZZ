// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";
import {XXYYZZCore} from "../src/XXYYZZCore.sol";
import {CommitReveal} from "../src/lib/CommitReveal.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Solarray} from "solarray/Solarray.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract XXYYZZMintTest is BaseTest {
    function testSetMintCloseTimestamp() public {
        vm.warp(20_000 days);
        test.setMintCloseTimestamp(1);
        assertEq(test.mintCloseTimestamp(), 1);
        vm.expectRevert(XXYYZZCore.InvalidTimestamp.selector);
        test.setMintCloseTimestamp(block.timestamp);
    }

    function testSetMintCloseTimestamp_onlyOwner() public {
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert(Ownable.Unauthorized.selector);
        test.setMintCloseTimestamp(1);
    }

    function testMintSpecificUnprotected() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        assertEq(test.ownerOf(1), address(this));
        assertEq(test.numMinted(), 1);
    }

    function testMintSpecificUnprotected_Unavailable() public {
        test.mintSpecificUnprotected{value: mintPrice}(1);
        vm.expectRevert(XXYYZZCore.Unavailable.selector);
        test.mintSpecificUnprotected{value: mintPrice}(1);
        assertEq(test.numMinted(), 1);
    }

    function testMintSpecificUnprotected_InvalidPayment() public {
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.mintSpecificUnprotected{value: mintPrice - 1}(1);
    }

    function testBatchMintSpecific_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchMintSpecific(new uint256[](maxBatchSize + 1), bytes32(0));
    }

    function testBatchMintSpecificUnprotected() public {
        uint256[] memory ids = Solarray.uint256s(1, 2);
        bool[] memory result = test.batchMintSpecificUnprotected{value: mintPrice * 2}(ids);
        assertEq(result.length, 2);
        assertEq(result[0], true);
        assertEq(result[1], true);
        assertEq(test.ownerOf(1), address(this));
        assertEq(test.ownerOf(2), address(this));
        assertEq(test.numMinted(), 2);
        assertEq(address(test).balance, mintPrice * 2);

        ids = Solarray.uint256s(2, 3);
        uint256 beforeBalance = address(this).balance;
        result = test.batchMintSpecificUnprotected{value: mintPrice * 2}(ids);
        assertEq(result.length, 2);
        assertEq(result[0], false);
        assertEq(result[1], true);
        assertEq(test.ownerOf(3), address(this));
        assertEq(address(this).balance + mintPrice, beforeBalance);

        ids = Solarray.uint256s(4, 4);
        test.batchMintSpecificUnprotected{value: mintPrice * 2}(ids);
        assertEq(test.ownerOf(4), address(this));
        assertEq(test.numMinted(), 4);
        assertEq(address(this).balance + mintPrice * 2, beforeBalance);
    }

    function testBatchMintSpecificUnprotected_NoneAvailable() public {
        uint256[] memory ids = Solarray.uint256s(1, 2);
        test.batchMintSpecificUnprotected{value: mintPrice * 2}(ids);
        vm.expectRevert(XXYYZZCore.NoneAvailable.selector);
        test.batchMintSpecificUnprotected{value: mintPrice * 2}(ids);
        assertEq(test.numMinted(), 2);
    }

    function testBatchMintSpecificUnprotected_MaxBatchSizeExceeded() public {
        vm.expectRevert(XXYYZZCore.MaxBatchSizeExceeded.selector);
        test.batchMintSpecificUnprotected(new uint256[](maxBatchSize + 1));
    }

    function testBatchMintSpecificUnprotected_InvalidPayment() public {
        uint256[] memory ids = Solarray.uint256s(1, 2);
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.batchMintSpecificUnprotected{value: mintPrice * 2 - 1}(ids);
    }

    function testBatchMintSpecific() public {
        uint256[] memory ids = Solarray.uint256s(1, 2);
        bytes32 salt = bytes32(0);
        _batchCommitAndWarp(ids, salt);
        bool[] memory result = test.batchMintSpecific{value: mintPrice * 2}(ids, salt);
        assertEq(result.length, 2);
        assertEq(result[0], true);
        assertEq(result[1], true);
        assertEq(test.ownerOf(1), address(this));
        assertEq(test.ownerOf(2), address(this));
        assertEq(test.numMinted(), 2);
        assertEq(address(test).balance, mintPrice * 2);

        ids = Solarray.uint256s(2, 3);
        uint256 beforeBalance = address(this).balance;
        _batchCommitAndWarp(ids, salt);
        result = test.batchMintSpecific{value: mintPrice * 2}(ids, salt);
        assertEq(result.length, 2);
        assertEq(result[0], false);
        assertEq(result[1], true);
        assertEq(test.ownerOf(3), address(this));
        assertEq(address(this).balance + mintPrice, beforeBalance);

        ids = Solarray.uint256s(4, 4);
        _batchCommitAndWarp(ids, salt);
        result = test.batchMintSpecific{value: mintPrice * 2}(ids, salt);
        assertEq(test.ownerOf(4), address(this));
        assertEq(test.numMinted(), 4);
        assertEq(address(this).balance + mintPrice * 2, beforeBalance);
    }
}
