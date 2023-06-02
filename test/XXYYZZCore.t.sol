// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TestPlus} from "solady-test/utils/TestPlus.sol";
import {Test} from "forge-std/Test.sol";
import {XXYYZZCore as XXYYZZ} from "../src/XXYYZZCore.sol";
import {XXYYZZCoreImpl} from "./helpers/XXYYZZCoreImpl.sol";
import {CommitReveal} from "emocore/CommitReveal.sol";
import {ERC721} from "solady/tokens/ERC721.sol";

contract XXYYZZCoreTest is Test, TestPlus {
    error CannotReceiveEther();

    XXYYZZ test;
    uint256 mintPrice;
    uint256 rerollPrice;
    uint256 rerollSpecificPrice;
    uint256 finalizePrice;
    bool allowEther;

    function setUp() public {
        test = new XXYYZZCoreImpl(address(this));
        mintPrice = test.MINT_PRICE();
        rerollPrice = test.REROLL_PRICE();
        rerollSpecificPrice = test.REROLL_SPECIFIC_PRICE();
        finalizePrice = test.FINALIZE_PRICE();
        vm.warp(10_000 days);
        allowEther = true;
    }

    function testName() public {
        assertEq(test.name(), "XXYYZZ");
    }

    function testSymbol() public {
        assertEq(test.symbol(), "XXYYZZ");
    }

    function testComputeCommitment(uint24 xxyyzz, bytes32 salt) public {
        uint256 concated;
        assembly {
            concated := or(shl(96, address()), xxyyzz)
        }
        assertEq(
            test.computeCommitment(address(this), uint24(xxyyzz), salt), keccak256(abi.encodePacked(concated, salt))
        );
    }

    function testMint() public {
        test.mint{value: mintPrice}();
        assertEq(test.balanceOf(address(this)), 1);
    }

    function testMintSpecific() public {
        bytes32 commitmentHash = test.computeCommitment(address(this), 0x123456, bytes32("1234"));
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: mintPrice}(0x123456, bytes32("1234"));
        assertEq(test.balanceOf(address(this)), 1);
    }

    function testMint_RandomCutoff() public {
        uint256 max = test.RANDOM_MINT_CUTOFF();
        for (uint256 i = 0; i < max; i++) {
            test.mint{value: mintPrice}();
        }
        assertEq(test.balanceOf(address(this)), max);

        vm.expectRevert(XXYYZZ.RandomMintingEnded.selector);
        test.mint{value: mintPrice}();
    }

    function testMint_MaxSupply() public {
        uint256 max = test.MAX_SUPPLY();
        for (uint256 i = 0; i < max; i++) {
            _mintSpecific(i, bytes32(0));
        }
        assertEq(test.balanceOf(address(this)), max);

        vm.expectRevert(XXYYZZ.MaximumSupplyExceeded.selector);
        test.mint{value: mintPrice}();
    }

    function testMint_InvalidPayment() public {
        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.mint{value: mintPrice - 1}();

        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.mint{value: mintPrice + 1}();
    }

    function testMint_RoundRobin() public {
        _mintSpecific(3188073, bytes32(0));
        test.mint{value: mintPrice}();
        assertEq(test.ownerOf(3188074), address(this));
    }

    function testMintSpecific(uint24 xxyyzz, bytes32 salt) public {
        bytes32 commitmentHash = test.computeCommitment(address(this), xxyyzz, salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: mintPrice}(xxyyzz, salt);
        assertEq(test.balanceOf(address(this)), 1);
    }

    function testMintSpecific_InvalidHex() public {
        vm.expectRevert(XXYYZZ.InvalidHex.selector);
        test.mintSpecific{value: mintPrice}(0x1000000000000000, bytes32(0));
    }

    function testMintSpecific_Invalidhex(uint256 id) public {
        id = bound(id, uint256(type(uint24).max) + 1, type(uint256).max);
        vm.expectRevert(XXYYZZ.InvalidHex.selector);
        test.mintSpecific{value: mintPrice}(id, bytes32(0));
    }

    function testMintSpecific_InvalidCommitment() public {
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, 0));
        test.mintSpecific{value: mintPrice}(0, bytes32(0));
    }

    function testMintSpecific_Duplicate() public {
        _mintSpecific(0, bytes32(0));

        bytes32 commitmentHash = test.computeCommitment(address(this), 0, bytes32(0));
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);
        vm.expectRevert(ERC721.TokenAlreadyExists.selector);
        test.mintSpecific{value: mintPrice}(0, bytes32(0));
    }

    function testMintSpecific_MaxSupply() public {
        uint256 max = test.MAX_SUPPLY();
        for (uint256 i = 0; i < max; i++) {
            _mintSpecific(i, bytes32(0));
        }
        assertEq(test.balanceOf(address(this)), max);

        vm.expectRevert(XXYYZZ.MaximumSupplyExceeded.selector);
        test.mintSpecific{value: mintPrice}(0, bytes32(0));
    }

    function testMintSpecific_InvalidPayment() public {
        bytes32 commitmentHash = test.computeCommitment(address(this), 0, bytes32(0));
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.mintSpecific{value: mintPrice - 1}(0, bytes32(0));

        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.mintSpecific{value: mintPrice + 1}(0, bytes32(0));
    }

    function testFinalize_InvalidPayment() public {
        _mintSpecific(0, bytes32(0));
        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.finalize{value: finalizePrice - 1}(0);

        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.finalize{value: finalizePrice + 1}(0);
    }

    function testFinalize_onlyTokenOwner() public {
        _mintSpecific(0, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(XXYYZZ.OnlyTokenOwner.selector);
        test.finalize{value: finalizePrice}(0);
    }

    function testFinalize() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);
        assertTrue(test.isFinalized(0));
        assertEq(test.finalizers(0), address(this));
    }

    function testFinalize_alreadyFinalized() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);

        vm.expectRevert(XXYYZZ.AlreadyFinalized.selector);
        test.finalize{value: finalizePrice}(0);
    }

    function testIsFinalized_tokenDoesNotExist() public {
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.isFinalized(0);
    }

    function testRerollSpecific_InvalidPayment() public {
        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.rerollSpecific{value: rerollSpecificPrice - 1}(0, 0, bytes32(0));
        vm.expectRevert(XXYYZZ.InvalidPayment.selector);
        test.rerollSpecific{value: rerollSpecificPrice + 1}(0, 0, bytes32(0));
    }

    function testRerollSpecific_TokenDoesNotExist() public {
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.rerollSpecific{value: rerollSpecificPrice}(0, 0, bytes32(0));
    }

    function testRerollSpecific_notOwner() public {
        _mintSpecific(0, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(XXYYZZ.OnlyTokenOwner.selector);
        test.rerollSpecific{value: rerollSpecificPrice}(0, 0, bytes32(0));
    }

    function testRerollSpecific_AlreadyFinalized() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);

        vm.expectRevert(XXYYZZ.AlreadyFinalized.selector);
        test.rerollSpecific{value: rerollSpecificPrice}(0, 0, bytes32(0));
    }

    function testRerollSpecific() public {
        _mintSpecific(0, bytes32(0));
        _rerollSpecific(0, 1, bytes32(0));
        assertEq(test.ownerOf(1), address(this));
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function testRerollSpecificAndFinalize() public {
        _mintSpecific(0, bytes32(0));
        bytes32 commitmentHash = test.computeCommitment(address(this), 1, bytes32(0));
        test.commit(commitmentHash);
        vm.warp(block.timestamp + 2 minutes);
        test.rerollSpecificAndFinalize{value: rerollSpecificPrice + finalizePrice}(0, 1, bytes32(0));
    }

    function testReroll() public {
        _mintSpecific(0, bytes32(0));
        test.reroll{value: rerollPrice}(0);
        assertEq(test.ownerOf(10854013), address(this));
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function _mintSpecific(uint256 id, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), uint24(id), salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: mintPrice}(id, salt);
    }

    function testWithdraw() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);

        uint256 balance = address(this).balance;
        test.withdraw();
        assertEq(address(this).balance, balance + finalizePrice + mintPrice);
    }

    function testWithdrawRevert() public {
        allowEther = false;
        vm.expectRevert(CannotReceiveEther.selector);
        test.withdraw();
    }

    function testBurn() public {
        _mintSpecific(0, bytes32(0));
        test.burn(0);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function testBurn_approved() public {
        _mintSpecific(0, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        startHoax(makeAddr("not owner"), 1 ether);

        test.burn(0);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function testBurn_onlyApproved() public {
        _mintSpecific(0, bytes32(0));
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        test.burn(0);
    }

    function testBulkBurn() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        test.bulkBurn(ids);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(1);
    }

    function testTotalSupplyNumMintedNumBurned(uint256 numMint, uint256 numBurn) public {
        numMint = bound(numMint, 0, 100);
        numBurn = bound(numBurn, 0, numMint);
        for (uint256 i = 0; i < numMint; i++) {
            _mintSpecific(i, bytes32(0));
        }
        for (uint256 i = 0; i < numBurn; i++) {
            test.burn(i);
        }
        assertEq(test.totalSupply(), numMint - numBurn);
        assertEq(test.numMinted(), numMint);
        assertEq(test.numBurned(), numBurn);
    }

    function testBulkBurn_NoIds() public {
        vm.expectRevert(XXYYZZ.NoIdsProvided.selector);
        test.bulkBurn(new uint256[](0));
    }

    function testBulkBurn_OwnerMismatch() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        test.transferFrom(address(this), makeAddr("not owner"), 0);
        test.setApprovalForAll(makeAddr("not owner"), true);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(XXYYZZ.OwnerMismatch.selector);
        test.bulkBurn(ids);
    }

    function _rerollSpecific(uint256 oldId, uint256 newId, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), uint24(newId), salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.rerollSpecific{value: rerollSpecificPrice}(oldId, newId, salt);
    }

    receive() external payable {
        if (!allowEther) {
            revert CannotReceiveEther();
        }
    }
}
