// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZ} from "../../src/XXYYZZ.sol";

contract XXYYZZCoreImpl is XXYYZZ {
    constructor(address initialOwner) XXYYZZ(initialOwner) {}

    function tokenURI(uint256) public view virtual override returns (string memory) {
        revert();
    }
}
