// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TestPlus} from "solady-test/utils/TestPlus.sol";
import {Test} from "forge-std/Test.sol";
import {XXYYZZCore} from "../src/XXYYZZCore.sol";
import {XXYYZZMetadata as XXYYZZ} from "./helpers/XXYYZZMetadata.sol";
import {CommitReveal} from "emocore/CommitReveal.sol";
import {ERC721} from "solady/tokens/ERC721.sol";

contract XXYYZZTest is Test, TestPlus {
    XXYYZZ test;

    function setUp() public {
        test = new XXYYZZ(address(this));
    }

    function testSVG() public {
        string memory expected = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="690" height="690"><rect width="690" height="690" fill="#000000" /></svg>'
        );
        assertEq(test.svg(0), expected);
    }

    function testImageURI() public {
        string memory expected = string.concat(
            "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2OTAiIGhlaWdodD0iNjkwIj48cmVjdCB3aWR0aD0iNjkwIiBoZWlnaHQ9IjY5MCIgZmlsbD0iIzAwMDAwMCIgLz48L3N2Zz4="
        );
        assertEq(test.imageURI(0), expected);
    }

    function testTraits() public {
        _mintSpecific(0, bytes32(0));
        assertEq(test.traits(0), '[{"trait_type":"Color","value":"#000000"},{"trait_type":"Finalized","value":"No"}]');
        test.finalize{value: test.FINALIZATION_PRICE()}(0);
        assertEq(
            test.traits(0),
            '[{"trait_type":"Color","value":"#000000"},{"trait_type":"Finalized","value":"Yes"},{"trait_type":"Finalizer","value":"0x7fa9385be102ac3eac297483dd6233d62b3e1496"}]'
        );
    }

    function testContractURI() public {
        assertEq(
            test.contractURI(),
            '{"name":"abc123","description": "my cool description", "external_link": "https://mycoolsite.com"}'
        );
    }

    function testTokenURI() public {
        _mintSpecific(0, bytes32(0));
        assertEq(
            test.tokenURI(0),
            '{"description":"Proof of stuff.","image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2OTAiIGhlaWdodD0iNjkwIj48cmVjdCB3aWR0aD0iNjkwIiBoZWlnaHQ9IjY5MCIgZmlsbD0iIzAwMDAwMCIgLz48L3N2Zz4=","attributes":[{"trait_type":"Color","value":"#000000"},{"trait_type":"Finalized","value":"No"}]}'
        );

        test.finalize{value: test.FINALIZATION_PRICE()}(0);
        assertEq(
            test.tokenURI(0),
            '{"description":"Proof of stuff.","image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2OTAiIGhlaWdodD0iNjkwIj48cmVjdCB3aWR0aD0iNjkwIiBoZWlnaHQ9IjY5MCIgZmlsbD0iIzAwMDAwMCIgLz48L3N2Zz4=","attributes":[{"trait_type":"Color","value":"#000000"},{"trait_type":"Finalized","value":"Yes"},{"trait_type":"Finalizer","value":"0x7fa9385be102ac3eac297483dd6233d62b3e1496"}]}'
        );
    }

    function _mintSpecific(uint256 id, bytes32 salt) internal {
        bytes32 commitmentHash = test.computeCommitment(address(this), id, salt);
        test.commit(commitmentHash);

        vm.warp(block.timestamp + 2 minutes);

        test.mintSpecific{value: test.MINT_PRICE()}(id, salt);
    }
}
