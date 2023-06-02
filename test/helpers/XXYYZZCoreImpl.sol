// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "../../src/XXYYZZCore.sol";

contract XXYYZZCoreImpl is XXYYZZCore {
    constructor(address initialOwner, uint256 maxMintsPerWallet) XXYYZZCore(initialOwner, maxMintsPerWallet) {}

    function tokenURI(uint256) public view virtual override returns (string memory) {
        revert();
    }
}
