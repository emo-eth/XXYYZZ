// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZMetadata} from "./XXYYZZMetadata.sol";
import {XXYYZZBurn} from "./XXYYZZBurn.sol";
import {XXYYZZMint} from "./XXYYZZMint.sol";
import {XXYYZZRerollFinalize} from "./XXYYZZRerollFinalize.sol";
import {XXYYZZCore} from "./XXYYZZCore.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

contract XXYYZZ is XXYYZZMetadata, XXYYZZBurn, XXYYZZMint, XXYYZZRerollFinalize {
    using LibString for uint256;
    using LibString for address;
    using Base64 for bytes;

    constructor(address initialOwner, uint256 maxBatchSize, bool constructorMint)
        XXYYZZMint(initialOwner, maxBatchSize)
    {
        if (constructorMint) {
            _mint(initialOwner, 0x000000);
            _mint(initialOwner, 0x00DEAD);
            _mint(initialOwner, 0xFF6000);
            _mint(initialOwner, 0x000069);
            _mint(initialOwner, 0x00FF00);
            _finalizeToken(0x000000, initialOwner);
            _finalizeToken(0x00DEAD, initialOwner);
            _finalizeToken(0xFF6000, initialOwner);
            _finalizeToken(0x000069, initialOwner);
            _finalizeToken(0x00FF00, initialOwner);
            _numMinted = 5;
        }
    }
}
