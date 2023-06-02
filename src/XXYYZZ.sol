// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";
import {CommitReveal} from "emocore/CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract XXYYZZ is ERC721, CommitReveal, Ownable {
    error InvalidPayment();
    error InvalidHex();
    error MaximumSupplyExceeded();
    error AlreadyFinalized();
    error OnlyTokenOwner();
    error OnlyEOAs();

    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant FINALIZATION_PRICE = 0.05 ether;
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant RANDOM_MINT_CUTOFF = 8_000;

    uint256 constant BYTES3_UINT_SHIFT = 232;
    uint256 constant MAX_UINT24 = 0xFFFFFF;
    uint96 constant FINALIZED = 1;
    uint96 constant NOT_FINALIZED = 1;

    // todo: numMinted, numBurned
    uint256 public totalSupply;
    mapping(uint256 => address) public finalizers;

    constructor() CommitReveal(1 days, 1 minutes) {}

    receive() external payable {
        // send ether – see what happens! :)
    }

    function name() public pure override returns (string memory) {
        assembly {
            mstore(0, 0x20)
            mstore(0x26, 0x06585859595a5a)
            return(0, 0x60)
        }
    }

    function symbol() public pure override returns (string memory) {
        assembly {
            mstore(0, 0x20)
            mstore(0x26, 0x06585859595a5a)
            return(0, 0x60)
        }
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        // return LibString.strConcat("https://example.com/token/", LibString.uint2str(tokenId));
    }

    function computeCommitment(address sender, uint256 xxyyzz, bytes32 salt)
        public
        view
        returns (bytes32 committmentHash)
    {
        assembly {
            mstore(0, or(shl(96, sender), xxyyzz))
            mstore(0x20, salt)
            committmentHash := keccak256(0, 0x40)
        }
    }

    function mint() public payable {
        // if (msg.sender != tx.origin) {
        //     revert OnlyEOAs();
        // }
        // check max supply
        if (totalSupply >= MAX_SUPPLY) {
            revert MaximumSupplyExceeded();
        }
        // validate mint price
        if (msg.value != MINT_PRICE) {
            revert InvalidPayment();
        }
        // increment supply before minting
        unchecked {
            totalSupply += 1;
        }
        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    function _findAvailableHex() internal view returns (uint256) {
        uint256 tokenId;
        assembly ("memory-safe") {
            mstore(0, sload(totalSupply.slot))
            mstore(0x20, prevrandao())
            tokenId := and(keccak256(0, 0x40), MAX_UINT24)
        }
        while (_exists(tokenId)) {
            unchecked {
                tokenId = (tokenId + 1) & MAX_UINT24;
            }
        }
        return tokenId;
    }

    function mintSpecific(uint256 xxyyzz, bytes32 salt) public payable {
        // if (msg.sender != tx.origin) {
        //     revert OnlyEOAs();
        // }
        // check max supply
        if (totalSupply >= MAX_SUPPLY) {
            revert MaximumSupplyExceeded();
        }
        // validate mint price
        if (msg.value != MINT_PRICE) {
            revert InvalidPayment();
        }
        // increment supply before minting
        unchecked {
            totalSupply += 1;
        }

        _mintSpecific(xxyyzz, salt);
    }

    function reroll(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        // check mint price
        if (msg.value != MINT_PRICE) {
            revert InvalidPayment();
        }
        // only owner can reroll; also checks for existence
        if (msg.sender != ownerOf(oldXXYYZZ)) {
            revert OnlyTokenOwner();
        }
        // once finalized, cannot reroll
        if (_isFinalized(oldXXYYZZ)) {
            revert AlreadyFinalized();
        }
        // burn old token
        _burn(oldXXYYZZ);

        // mint new token; do not update supply numbers
        _mintSpecific(newXXYYZZ, salt);
    }

    function finalize(uint256 xxyyzz) public payable {
        // validate finalization price
        if (msg.value != FINALIZATION_PRICE) {
            revert InvalidPayment();
        }
        // only owner can finalize; also checks for existence
        if (msg.sender != ownerOf(xxyyzz)) {
            revert OnlyTokenOwner();
        }
        // once finalized, cannot finalize again
        // send ether directly to contract if you'd like to donate :)
        if (_isFinalized(xxyyzz)) {
            revert AlreadyFinalized();
        }

        // set finalized flag
        _finalize(xxyyzz);
    }

    function _mintSpecific(uint256 xxyyzz, bytes32 salt) internal {
        _validateId(xxyyzz);
        // validate commitment to prevent front-running
        bytes32 computedCommitment = computeCommitment(msg.sender, xxyyzz, salt);
        _assertCommittedReveal(computedCommitment);

        _mint(msg.sender, xxyyzz);
    }

    function _finalize(uint256 xxyyzz) internal {
        _setExtraData(xxyyzz, 1);
    }

    function isFinalized(uint256 xxyyzz) public view returns (bool) {
        if (!_exists(xxyyzz)) {
            revert TokenDoesNotExist();
        }
        return _isFinalized(xxyyzz);
    }

    function _isFinalized(uint256 xxyyzz) internal view returns (bool) {
        return _getExtraData(xxyyzz) == FINALIZED;
    }

    function _validateId(uint256 xxyyzz) internal pure {
        // check that xxyyzz is a valid 6-character hex number
        if (xxyyzz > MAX_UINT24) {
            revert InvalidHex();
        }
    }

    /**
     * @notice Withdraws all funds from the contract to the current owner.
     */
    function withdraw() public onlyOwner {
        assembly ("memory-safe") {
            let succ := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
            if iszero(succ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
