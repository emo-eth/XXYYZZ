// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solady/tokens/ERC721.sol";
import {CommitReveal} from "emocore/CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract XXYYZZCore is ERC721, CommitReveal, Ownable {
    error InvalidPayment();
    error InvalidHex();
    error SameHex();
    error MaximumSupplyExceeded();
    error AlreadyFinalized();
    error OnlyTokenOwner();
    error OnlyEOAs();
    error NoIdsProvided();
    error OwnerMismatch();

    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant FINALIZATION_PRICE = 0.05 ether;
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant RANDOM_MINT_CUTOFF = 8_000;

    uint256 constant BYTES3_UINT_SHIFT = 232;
    uint256 constant MAX_UINT24 = 0xFFFFFF;
    uint96 constant FINALIZED = 1;
    uint96 constant NOT_FINALIZED = 1;

    mapping(uint256 tokenId => address finalizer) public finalizers;
    uint128 _numMinted;
    uint128 _numBurned;

    constructor(address initialOwner) CommitReveal(1 days, 1 minutes) {
        _initializeOwner(initialOwner);
    }

    receive() external payable {
        // send ether – see what happens! :)
    }

    function totalSupply() public view returns (uint256) {
        return _numMinted - _numBurned;
    }

    function numMinted() external view returns (uint256) {
        return _numMinted;
    }

    function numBurned() external view returns (uint256) {
        return _numBurned;
    }

    function name() public pure override returns (string memory) {
        assembly {
            mstore(0x20, 0x20)
            mstore(0x46, 0x06585859595a5a)
            // mstore(0x46, 0x06616263313233)
            return(0x20, 0x80)
        }
    }

    function symbol() public pure override returns (string memory) {
        assembly {
            mstore(0x20, 0x20)
            mstore(0x46, 0x06585859595a5a)
            // mstore(0x46, 0x06616263313233)
            return(0x20, 0x80)
        }
    }

    function tokenURI(uint256) public view virtual override returns (string memory) {
        // not implemented for separation of concerns
        revert();
    }

    function computeCommitment(address sender, uint256 xxyyzz, bytes32 salt)
        public
        pure
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
        if (_numMinted >= MAX_SUPPLY) {
            revert MaximumSupplyExceeded();
        }
        // validate mint price
        if (msg.value != MINT_PRICE) {
            revert InvalidPayment();
        }
        // increment supply before minting
        unchecked {
            _numMinted += 1;
        }
        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    function _findAvailableHex() internal view returns (uint256) {
        uint256 tokenId;
        assembly ("memory-safe") {
            // this is packed with _numBurned but that's fine for pseudorandom purposes
            mstore(0, sload(_numMinted.slot))
            mstore(0x20, prevrandao())
            // mstore(0x20, blockhash(sub(number(), 1)))
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
        uint256 numberMinted = _numMinted;
        if (numberMinted >= MAX_SUPPLY) {
            revert MaximumSupplyExceeded();
        }
        // validate mint price
        if (msg.value != MINT_PRICE) {
            revert InvalidPayment();
        }
        // increment supply before minting
        unchecked {
            _numMinted = uint128(numberMinted + 1);
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
        // disallow burning to same token
        if (oldXXYYZZ == newXXYYZZ) {
            revert SameHex();
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

        finalizers[xxyyzz] = msg.sender;
        // set finalized flag
        _finalize(xxyyzz);
    }

    function burn(uint256 xxyyzz) public {
        _numBurned += 1;
        _burn(msg.sender, xxyyzz);
    }

    function bulkBurn(uint256[] calldata ids) public {
        if (ids.length == 0) {
            revert NoIdsProvided();
        }
        address initialTokenOwner = _ownerOf(ids[0]);
        unchecked {
            _numBurned += uint128(ids.length);
        }
        _burn(msg.sender, ids[0]);
        for (uint256 i = 1; i < ids.length;) {
            uint256 id = ids[i];
            if (_ownerOf(id) != initialTokenOwner) {
                revert OwnerMismatch();
            }
            // still specify msg.sender since they may be not be approved for *all* tokens
            _burn(msg.sender, id);
            unchecked {
                ++i;
            }
        }
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
