// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";
import {XXYYZZCore} from "../src/XXYYZZCore.sol";
import {CommitReveal} from "../src/lib/CommitReveal.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Solarray} from "solarray/Solarray.sol";

contract XXYYZZCoreTest is BaseTest {
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

    function testMintMany() public {
        test.mint{value: mintPrice * 3}(3);
        assertEq(test.balanceOf(address(this)), 3);
    }

    function testMint() public {
        test.mint{value: mintPrice}();
        assertEq(test.balanceOf(address(this)), 1);
    }

    function testBatchMintSpecific2() public {
        bytes32 salt = bytes32("1234");
        uint256[] memory ids = Solarray.uint256s(0, 1, 2);
        bytes32 commitmentHash = test.computeBatchCommitment(address(this), ids, salt);
        test.commit(commitmentHash);
        vm.warp(this._timestamp() + 2 minutes);
        test.batchMintSpecific{value: mintPrice * 3}(ids, salt);
        // assert ownerships
        assertEq(test.ownerOf(0), address(this));
        assertEq(test.ownerOf(1), address(this));
        assertEq(test.ownerOf(2), address(this));
    }

    function testBatchMintSpecific2_InvalidId() public {
        bytes32 salt = bytes32("1234");
        uint256[] memory ids = Solarray.uint256s(0, 1, 200000000000);
        bytes32 commitmentHash = test.computeBatchCommitment(address(this), ids, salt);
        test.commit(commitmentHash);
        vm.warp(this._timestamp() + 2 minutes);
        vm.expectRevert(XXYYZZCore.InvalidHex.selector);
        test.batchMintSpecific{value: mintPrice * 3}(ids, salt);
    }

    function testBatchMintSpecific2_InvalidArray() public {
        bytes32 salt = bytes32("1234");
        uint256[] memory ids = Solarray.uint256s(0, 1, 2);
        bytes32 commitmentHash = test.computeBatchCommitment(address(this), ids, salt);
        test.commit(commitmentHash);
        vm.warp(this._timestamp() + 2 minutes);
        vm.expectRevert(abi.encodeWithSelector(CommitReveal.InvalidCommitment.selector, 0));
        test.batchMintSpecific{value: mintPrice * 3}(Solarray.uint256s(1, 0, 2), salt);
    }

    function testMintSpecific() public {
        bytes32 commitmentHash = test.computeCommitment(address(this), 0x123456, bytes32("1234"));
        test.commit(commitmentHash);

        vm.warp(this._timestamp() + 2 minutes);

        test.mintSpecific{value: mintPrice}(0x123456, bytes32("1234"));
        assertEq(test.balanceOf(address(this)), 1);
    }

    function testMintSpecific_PreviouslyFinalized() public {
        _mintSpecific(0, bytes32(0));
        test.burn(0, false);
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);
        test.burn(0, false);
        vm.expectRevert(XXYYZZCore.AlreadyFinalized.selector);
        test.mintSpecific{value: mintPrice}(0, bytes32(0));
    }

    // function testMint_RandomCutoff() public {
    //     uint256 max = test.RANDOM_MINT_CUTOFF();
    //     for (uint256 i = 0; i < max; i++) {
    //         test.mint{value: mintPrice}();
    //     }
    //     assertEq(test.balanceOf(address(this)), max);

    //     vm.expectRevert(XXYYZZCore.RandomMintingEnded.selector);
    //     test.mint{value: mintPrice}();
    // }

    // function testMint_MaxSupply() public {
    //     uint256 max = test.MAX_SUPPLY();
    //     for (uint256 i = 0; i < max; i++) {
    //         _mintSpecific(i, bytes32(0));
    //     }
    //     assertEq(test.balanceOf(address(this)), max);

    //     vm.expectRevert(XXYYZZCore.MaximumSupplyExceeded.selector);
    //     test.mint{value: mintPrice}();
    // }

    function testMint_InvalidPayment() public {
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.mint{value: mintPrice - 1}();

        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.mint{value: mintPrice + 1}();
    }

    function testMint_RoundRobin() public {
        _mintSpecific(3188073, bytes32(0));
        test.mint{value: mintPrice}();
        assertEq(test.ownerOf(3188074), address(this));
    }

    function testMint_RoundRobinFinalized() public {
        _mintSpecific(3188073, bytes32(0));
        test.finalize{value: finalizePrice}(3188073);
        test.burn(3188073, false);
        test.mint{value: mintPrice}();
        assertEq(test.ownerOf(3188074), address(this));
    }

    function testMintSpecific(uint24 xxyyzz, bytes32 salt) public {
        bytes32 commitmentHash = test.computeCommitment(address(this), xxyyzz, salt);
        test.commit(commitmentHash);

        vm.warp(this._timestamp() + 2 minutes);

        test.mintSpecific{value: mintPrice}(xxyyzz, salt);
        assertEq(test.balanceOf(address(this)), 1);
    }

    function testMintSpecific_InvalidHex() public {
        vm.expectRevert(XXYYZZCore.InvalidHex.selector);
        test.mintSpecific{value: mintPrice}(0x1000000000000000, bytes32(0));
    }

    function testMintSpecific_Invalidhex(uint256 id) public {
        id = bound(id, uint256(type(uint24).max) + 1, type(uint256).max);
        vm.expectRevert(XXYYZZCore.InvalidHex.selector);
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

        vm.warp(this._timestamp() + 2 minutes);
        vm.expectRevert(ERC721.TokenAlreadyExists.selector);
        test.mintSpecific{value: mintPrice}(0, bytes32(0));
    }

    // function testMintSpecific_MaxSupply() public {
    //     uint256 max = test.MAX_SUPPLY();
    //     for (uint256 i = 0; i < max; i++) {
    //         _mintSpecific(i, bytes32(0));
    //     }
    //     assertEq(test.balanceOf(address(this)), max);

    //     vm.expectRevert(XXYYZZCore.MaximumSupplyExceeded.selector);
    //     test.mintSpecific{value: mintPrice}(0, bytes32(0));
    // }

    function testMint_MintClosed() public {
        vm.warp(this._timestamp() + 365 days);
        vm.expectRevert(XXYYZZCore.MintClosed.selector);
        test.mint{value: mintPrice}();
    }

    function testMintSpecific_InvalidPayment() public {
        bytes32 commitmentHash = test.computeCommitment(address(this), 0, bytes32(0));
        test.commit(commitmentHash);

        vm.warp(this._timestamp() + 2 minutes);

        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.mintSpecific{value: mintPrice - 1}(0, bytes32(0));

        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.mintSpecific{value: mintPrice + 1}(0, bytes32(0));
    }

    function testFinalize_InvalidPayment() public {
        _mintSpecific(0, bytes32(0));
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.finalize{value: finalizePrice - 1}(0);

        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.finalize{value: finalizePrice + 1}(0);
    }

    function testFinalize_onlyTokenOwner() public {
        _mintSpecific(0, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(XXYYZZCore.OnlyTokenOwner.selector);
        test.finalize{value: finalizePrice}(0);
    }

    function testFinalize() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);
        assertTrue(test.isFinalized(0));
        assertEq(test.finalizers(0), address(this));
    }

    function testBatchFinalize() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        uint256[] memory ids = new uint256[](2);
        ids[1] = 1;
        test.batchFinalize{value: finalizePrice * 2}(ids);
    }

    function testFinalize_alreadyFinalized() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);

        vm.expectRevert(XXYYZZCore.AlreadyFinalized.selector);
        test.finalize{value: finalizePrice}(0);
    }

    function testIsFinalized_tokenDoesNotExist() public {
        // vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        assertFalse(test.isFinalized(0));
        _mintSpecific(0, bytes32(0));
        assertFalse(test.isFinalized(0));
        test.finalize{value: finalizePrice}(0);
        assertTrue(test.isFinalized(0));
    }

    function testRerollSpecific_InvalidPayment() public {
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.rerollSpecific{value: rerollSpecificPrice - 1}(0, 0, bytes32(0));
        vm.expectRevert(XXYYZZCore.InvalidPayment.selector);
        test.rerollSpecific{value: rerollSpecificPrice + 1}(0, 0, bytes32(0));
    }

    function testRerollSpecific_notOwner() public {
        _mintSpecific(0, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(XXYYZZCore.OnlyTokenOwner.selector);
        test.rerollSpecific{value: rerollSpecificPrice}(0, 0, bytes32(0));
    }

    function testRerollSpecific_AlreadyFinalized() public {
        _mintSpecific(0, bytes32(0));
        test.finalize{value: finalizePrice}(0);

        vm.expectRevert(XXYYZZCore.AlreadyFinalized.selector);
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
        vm.warp(this._timestamp() + 2 minutes);
        test.rerollSpecificAndFinalize{value: rerollSpecificPrice + finalizePrice}(0, 1, bytes32(0));
    }

    function testBatchRerollSpecificBatch() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));

        uint256[] memory oldIds = Solarray.uint256s(0, 1);
        uint256[] memory newIds = Solarray.uint256s(2, 3);
        bytes32 salt = bytes32("1234");
        _batchCommitAndWarp(newIds, salt);
        test.batchRerollSpecific{value: rerollSpecificPrice * 2}(oldIds, newIds, salt);

        vm.expectRevert(XXYYZZCore.ArrayLengthMismatch.selector);
        test.batchRerollSpecific{value: (rerollSpecificPrice) * 2}(oldIds, new uint256[](0), salt);
    }

    function testBatchRerollSpecificAndFinalizeBatch() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));

        uint256[] memory oldIds = Solarray.uint256s(0, 1);
        uint256[] memory newIds = Solarray.uint256s(2, 3);
        bytes32 salt = bytes32("1234");
        _batchCommitAndWarp(newIds, salt);
        test.batchRerollSpecificAndFinalize{value: (rerollSpecificPrice + finalizePrice) * 2}(oldIds, newIds, salt);
        assertTrue(test.isFinalized(2));
        assertTrue(test.isFinalized(3));

        vm.expectRevert(XXYYZZCore.ArrayLengthMismatch.selector);
        test.batchRerollSpecificAndFinalize{value: (rerollSpecificPrice + finalizePrice) * 2}(
            oldIds, new uint256[](0), salt
        );
    }

    function testReroll() public {
        _mintSpecific(0, bytes32(0));
        test.reroll{value: rerollPrice}(0);
        assertEq(test.ownerOf(10599171), address(this));
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function testBatchReroll1() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        uint256[] memory ids = new uint256[](2);
        ids[1] = 1;
        test.batchReroll{value: rerollPrice * 2}(ids);
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
        test.burn(0, false);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function testBurn_approved() public {
        _mintSpecific(0, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        startHoax(makeAddr("not owner"), 1 ether);

        test.burn(0, false);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
    }

    function testBurn_onlyApproved() public {
        _mintSpecific(0, bytes32(0));
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        test.burn(0, false);
    }

    function testBatchBurn() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        test.batchBurn(ids, false);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(0);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        test.ownerOf(1);

        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), true);
        vm.prank(makeAddr("not owner"));
        test.batchBurn(ids, false);

        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        test.setApprovalForAll(makeAddr("not owner"), false);
        vm.prank(makeAddr("not owner"));
        vm.expectRevert(XXYYZZCore.BatchBurnerNotApprovedForAll.selector);
        test.batchBurn(ids, false);
    }

    function testTotalSupplyNumMintedNumBurned(uint256 numMint, uint256 numBurn) public {
        numMint = bound(numMint, 0, 100);
        numBurn = bound(numBurn, 0, numMint);
        for (uint256 i = 0; i < numMint; i++) {
            _mintSpecific(i, bytes32(0));
        }
        for (uint256 i = 0; i < numBurn; i++) {
            test.burn(i, false);
        }
        assertEq(test.totalSupply(), numMint - numBurn);
        assertEq(test.numMinted(), numMint);
        assertEq(test.numBurned(), numBurn);
    }

    function testBatchBurn_NoIds() public {
        vm.expectRevert(XXYYZZCore.NoIdsProvided.selector);
        test.batchBurn(new uint256[](0), false);
    }

    function testBatchBurn_OwnerMismatch() public {
        _mintSpecific(0, bytes32(0));
        _mintSpecific(1, bytes32(0));
        test.transferFrom(address(this), makeAddr("not owner"), 0);
        test.setApprovalForAll(makeAddr("not owner"), true);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        startHoax(makeAddr("not owner"), 1 ether);

        vm.expectRevert(XXYYZZCore.OwnerMismatch.selector);
        test.batchBurn(ids, false);
    }

    function _rerollSpecific(uint256 oldId, uint256 newId, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), uint24(newId), salt);
        test.commit(commitmentHash);

        vm.warp(this._timestamp() + 2 minutes);

        test.rerollSpecific{value: rerollSpecificPrice}(oldId, newId, salt);
    }

    function testSupportsInterface() public {
        assertTrue(test.supportsInterface(0x01ffc9a7));
        assertTrue(test.supportsInterface(0x80ac58cd));
        assertTrue(test.supportsInterface(0x5b5e139f));
        assertTrue(test.supportsInterface(0x49064906));
    }
}
