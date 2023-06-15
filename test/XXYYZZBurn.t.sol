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

contract XXYYZZBurnTest is Test, TestPlus {
    error CannotReceiveEther();

    XXYYZZ test;
    uint256 mintPrice;
    uint256 rerollPrice;
    uint256 rerollSpecificPrice;
    uint256 finalizePrice;
    bool allowEther;

    function setUp() public {
        vm.warp(10_000 days);

        test = new XXYYZZ(address(this),5,new uint24[](0),address(0));
        mintPrice = test.MINT_PRICE();
        rerollPrice = test.REROLL_PRICE();
        rerollSpecificPrice = test.REROLL_PRICE();
        finalizePrice = test.FINALIZE_PRICE();
        allowEther = true;
    }

    function testBurn_onlyFinalized() public {
        _mintSpecific(0, bytes32(0));
        vm.expectRevert(XXYYZZCore.OnlyFinalized.selector);
        test.burn(0, true);

        test.finalize{value: finalizePrice}(0);
        test.burn(0, true);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
        assertTrue(test.isFinalized(0));
    }

    function testBatchBurn_onlyFinalized() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        uint256[] memory ids = Solarray.uint256s(0, 1);
        vm.expectRevert(XXYYZZCore.OnlyFinalized.selector);
        test.batchBurn(ids, true);
        test.finalize{value: finalizePrice}(0);
        vm.expectRevert(XXYYZZCore.OnlyFinalized.selector);
        test.batchBurn(ids, true);

        test.finalize{value: finalizePrice}(1);
        test.batchBurn(ids, true);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(1);

        assertTrue(test.isFinalized(0));
        assertTrue(test.isFinalized(1));

        // now finalize the second one but not the first
        _mintSpecific(2, bytes32(0));
        _mintSpecific(3, bytes32(0));

        ids = Solarray.uint256s(2, 3);
        test.finalize{value: finalizePrice}(3);
        vm.expectRevert(XXYYZZCore.OnlyFinalized.selector);
        test.batchBurn(ids, true);
    }

    function _mintSpecific(uint256 id, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), uint24(id), salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: mintPrice}(id, salt);
    }
}
