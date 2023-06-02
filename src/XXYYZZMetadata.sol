// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZ} from "./XXYYZZ.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

contract XXYYZZMetadata is XXYYZZ {
    using LibString for uint256;
    using LibString for address;
    using Base64 for bytes;

    constructor(address initialOwner) XXYYZZ(initialOwner) {}

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string.concat(
            "{",
            kv("description", "Proof of stuff."),
            ",",
            kv("image", imageURI(id)),
            ",",
            kRawV("attributes", traits(id)),
            "}"
        );
    }

    function imageURI(uint256 id) public pure returns (string memory) {
        return string.concat("data:image/svg+xml;base64,", bytes(svg(id)).encode());
    }

    function svg(uint256 id) public pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="690" height="690"><rect width="690" height="690" fill="#',
            id.toHexStringNoPrefix({length: 3}),
            '" /></svg>'
        );
    }

    function traits(uint256 id) public view returns (string memory) {
        string memory color = trait("Color", string.concat("#", id.toHexStringNoPrefix({length: 3})));
        if (isFinalized(id)) {
            string memory finalizedProp = trait("Finalized", "Yes");
            return string.concat(
                "[", color, ",", finalizedProp, ",", trait("Finalizer", finalizers[id].toHexString()), "]"
            );
        } else {
            return string.concat("[", color, ",", trait("Finalized", "No"), "]");
        }
    }

    function trait(string memory key, string memory value) public pure returns (string memory) {
        return string.concat('{"trait_type":"', key, '","value":"', value, '"}');
    }

    function kv(string memory key, string memory value) public pure returns (string memory) {
        return string.concat('"', key, '":"', value, '"');
    }

    function kRawV(string memory key, string memory value) public pure returns (string memory) {
        return string.concat('"', key, '":', value);
    }

    function contractURI() public pure returns (string memory) {
        return '{"name":"abc123","description": "my cool description", "external_link": "https://mycoolsite.com"}';
    }
}
