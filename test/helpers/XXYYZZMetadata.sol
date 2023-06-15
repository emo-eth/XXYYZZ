// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZ} from "../../src/XXYYZZ.sol";

contract XXYYZZMetadataImpl is XXYYZZ {
    constructor(address initialOwner) XXYYZZ(initialOwner, 10_000, false, address(0)) {}

    function imageURI(uint256 id) external pure returns (string memory) {
        return _imageURI(id);
    }

    function svg(uint256 id) external pure returns (string memory) {
        return _svg(id);
    }

    function traits(uint256 id) external view returns (string memory) {
        return _traits(id);
    }

    function trait(string memory key, string memory value) external pure returns (string memory) {
        return _trait(key, value);
    }

    function kv(string memory key, string memory value) external pure returns (string memory) {
        return _kv(key, value);
    }

    function kRawV(string memory key, string memory value) external pure returns (string memory) {
        return _kRawV(key, value);
    }

    function stringURI(uint256 id) external view returns (string memory) {
        return _stringURI(id);
    }

    function stringContractURI() external pure returns (string memory) {
        return _stringContractURI();
    }
}
