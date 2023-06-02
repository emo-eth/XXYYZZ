// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TestPlus} from "solady-test/utils/TestPlus.sol";
import {Test} from "forge-std/Test.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";

contract XXYYZZTest is Test, TestPlus {
    XXYYZZ test;
    uint256 mintPrice;

    function setUp() public {
        test = new XXYYZZ();
        mintPrice = test.MINT_PRICE();
        vm.warp(10_000 days);
    }

    function testName() public {
        assertEq(test.name(), "XXYYZZ");
    }

    function testSymbol() public {
        assertEq(test.symbol(), "XXYYZZ");
    }

    function testComputeCommitment(uint256 xxyyzz, bytes32 salt) public {
        uint256 concated;
        assembly {
            concated := or(shl(96, address()), xxyyzz)
        }
        assertEq(test.computeCommitment(address(this), xxyyzz, salt), keccak256(abi.encodePacked(concated, salt)));
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

    function testMint_MaxSupply() public {
        uint256 max = test.MAX_SUPPLY();
        for (uint256 i = 0; i < max; i++) {
            test.mint{value: mintPrice}();
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

    function _mintSpecific(uint256 id, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), id, salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: mintPrice}(id, salt);
    }

    function testMintSpecific(uint24 xxyyzz, bytes32 salt) public {
        bytes32 commitmentHash = test.computeCommitment(address(this), xxyyzz, salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: mintPrice}(xxyyzz, salt);
        assertEq(test.balanceOf(address(this)), 1);
    }
}
