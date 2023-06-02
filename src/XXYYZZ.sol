// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "./XXYYZZCore.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

contract XXYYZZ is XXYYZZCore {
    using LibString for uint256;
    using LibString for address;
    using Base64 for bytes;

    constructor(address initialOwner) XXYYZZCore(initialOwner) {}

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string.concat("data:application/json;base64,", bytes(stringURI(id)).encode());
    }

    function stringURI(uint256 id) public view virtual returns (string memory) {
        return string.concat(
            "{",
            _kv("name", _name(id)),
            ",",
            _kv("external_link", "https://mycoolsite.com"),
            ",",
            _kv("description", "Proof of stuff."),
            ",",
            _kv("image", _imageURI(id)),
            ",",
            _kRawV("attributes", _traits(id)),
            "}"
        );
    }

    function contractURI() public pure returns (string memory) {
        return string.concat("data:application/json;base64,", bytes(stringContractURI()).encode());
    }

    function stringContractURI() public pure returns (string memory) {
        return '{"name":"abc123","description":"my cool description","external_link":"https://mycoolsite.com"}';
    }

    function _name(uint256 id) internal pure returns (string memory) {
        return string.concat("#", id.toHexStringNoPrefix({length: 3}));
    }

    function _imageURI(uint256 id) internal pure returns (string memory) {
        return string.concat("data:image/svg+xml;base64,", bytes(_svg(id)).encode());
    }

    function _svg(uint256 id) internal pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="690" height="690"><rect width="690" height="690" fill="#',
            id.toHexStringNoPrefix({length: 3}),
            '" /></svg>'
        );
    }

    function _traits(uint256 id) internal view returns (string memory) {
        string memory color = _trait("Color", _name(id));
        if (isFinalized(id)) {
            string memory finalizedProp = _trait("Finalized", "Yes");
            return string.concat(
                "[", color, ",", finalizedProp, ",", _trait("Finalizer", finalizers[id].toHexString()), "]"
            );
        } else {
            return string.concat("[", color, ",", _trait("Finalized", "No"), "]");
        }
    }

    function _trait(string memory key, string memory value) internal pure returns (string memory) {
        return string.concat('{"trait_type":"', key, '","value":"', value, '"}');
    }

    function _kv(string memory key, string memory value) internal pure returns (string memory) {
        return string.concat('"', key, '":"', value, '"');
    }

    function _kRawV(string memory key, string memory value) internal pure returns (string memory) {
        return string.concat('"', key, '":', value);
    }
}
