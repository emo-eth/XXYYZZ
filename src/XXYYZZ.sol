// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "./XXYYZZCore.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

contract XXYYZZ is XXYYZZCore {
    using LibString for uint256;
    using LibString for address;
    using Base64 for bytes;

    constructor(address initialOwner) XXYYZZCore(initialOwner) {
        _mint(initialOwner, 0x000000);
        _mint(initialOwner, 0x00DEAD);
        _mint(initialOwner, 0xFF6000);
        _mint(initialOwner, 0x000069);
        _mint(initialOwner, 0x6AFF34);
        _finalizeToken(0x000000, initialOwner);
        _finalizeToken(0x00DEAD, initialOwner);
        _finalizeToken(0xFF6000, initialOwner);
        _finalizeToken(0x000069, initialOwner);
        _finalizeToken(0x6AFF34, initialOwner);
        _numMinted = 5;
    }

    ///@notice Return the base64-encoded token metadata
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string.concat("data:application/json;base64,", bytes(_stringURI(id)).encode());
    }

    ///@notice Return the base64-encoded contract-level metadata
    function contractURI() public pure returns (string memory) {
        return string.concat("data:application/json;base64,", bytes(_stringContractURI()).encode());
    }

    ///@dev Return a token-level JSON string
    function _stringURI(uint256 id) internal view virtual returns (string memory) {
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

    /**
     * @dev Return a contract-level JSON string
     */
    function _stringContractURI() internal pure returns (string memory) {
        return '{"name":"abc123","description":"my cool description","external_link":"https://mycoolsite.com"}';
    }

    ///@dev Return a name like "#aabbcc"
    function _name(uint256 id) internal pure returns (string memory) {
        return string.concat("#", id.toHexStringNoPrefix({length: 3}));
    }

    ///@dev Return an svg as a base64-encoded data uri string
    function _imageURI(uint256 id) internal pure returns (string memory) {
        return string.concat("data:image/svg+xml;base64,", bytes(_svg(id)).encode());
    }

    ///@dev Return a 690x690 SVG with a single rect of the token's color
    function _svg(uint256 id) internal pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="690" height="690"><rect width="690" height="690" fill="#',
            id.toHexStringNoPrefix({length: 3}),
            '" /></svg>'
        );
    }

    ///@dev Return a JSON array of {"trait_type":"key","value":"value"} pairs
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

    ///@dev return a {"trait_type":"key","value":"value"} pair
    function _trait(string memory key, string memory value) internal pure returns (string memory) {
        return string.concat('{"trait_type":"', key, '","value":"', value, '"}');
    }

    ///@dev return a "key":"value" pair
    function _kv(string memory key, string memory value) internal pure returns (string memory) {
        return string.concat('"', key, '":"', value, '"');
    }

    ///@dev Return a "key":value pair without quoting value
    function _kRawV(string memory key, string memory value) internal pure returns (string memory) {
        return string.concat('"', key, '":', value);
    }
}
