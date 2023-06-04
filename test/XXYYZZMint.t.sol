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
import {Ownable} from "solady/auth/Ownable.sol";

contract XXYYZZMintTest is Test, TestPlus {
    error CannotReceiveEther();

    XXYYZZ test;
    uint256 mintPrice;
    uint256 rerollPrice;
    uint256 rerollSpecificPrice;
    uint256 finalizePrice;
    bool allowEther;

    function setUp() public {
        vm.warp(10_000 days);

        test = new XXYYZZ(address(this),5,false);
        mintPrice = test.MINT_PRICE();
        rerollPrice = test.REROLL_PRICE();
        rerollSpecificPrice = test.REROLL_PRICE();
        finalizePrice = test.FINALIZE_PRICE();
        allowEther = true;
    }

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

    function testBatchRerollSpecific() public {
        uint256[] memory ids = new uint256[](6);
        bytes32[] memory salts = new bytes32[](6);
        vm.expectRevert(CommitReveal.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecific(ids, ids, salts);

        vm.expectRevert(CommitReveal.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecific(ids, ids, bytes32(0));
    }

    function testBatchRerollSpecificAndFinalize() public {
        uint256[] memory ids = new uint256[](6);
        bytes32[] memory salts = new bytes32[](6);
        vm.expectRevert(CommitReveal.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecificAndFinalize(ids, ids, salts);

        vm.expectRevert(CommitReveal.MaxBatchSizeExceeded.selector);
        test.batchRerollSpecificAndFinalize(ids, ids, bytes32(0));
    }
}
