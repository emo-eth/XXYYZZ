// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solady/tokens/ERC721.sol";
import {CommitReveal} from "emocore/CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

abstract contract XXYYZZCore is ERC721, CommitReveal, Ownable {
    error InvalidPayment();
    error InvalidHex();
    error SameHex();
    error MaximumSupplyExceeded();
    error AlreadyFinalized();
    error OnlyTokenOwner();
    error OnlyEOAs();
    error NoIdsProvided();
    error OwnerMismatch();
    error RandomMintingEnded();

    uint256 public constant MINT_PRICE = 0.02 ether;
    uint256 public constant REROLL_PRICE = 0.005 ether;
    uint256 public constant REROLL_SPECIFIC_PRICE = 0.0075 ether;
    uint256 public constant FINALIZE_PRICE = 0.02 ether;
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

    /**
     * @notice Get the total number of tokens in circulation
     */
    function totalSupply() public view returns (uint256) {
        return _numMinted - _numBurned;
    }

    /**
     * @notice Get the total number of tokens minted
     */
    function numMinted() external view returns (uint256) {
        return _numMinted;
    }

    /**
     * @notice Get the total number of tokens burned
     */
    function numBurned() external view returns (uint256) {
        return _numBurned;
    }

    /**
     * @notice Get the name of the token
     */
    function name() public pure override returns (string memory) {
        // note that this is unsafe to call internally, as it abi-encodes the name and
        // performs a low-level return
        assembly {
            mstore(0x20, 0x20)
            mstore(0x46, 0x06585859595a5a)
            // mstore(0x46, 0x06616263313233)
            return(0x20, 0x80)
        }
    }

    /**
     * @notice Get the symbol of the token
     */
    function symbol() public pure override returns (string memory) {
        // note that this is unsafe to call internally, as it abi-encodes the symbol and
        // performs a low-level return
        assembly {
            mstore(0x20, 0x20)
            mstore(0x46, 0x06585859595a5a)
            // mstore(0x46, 0x06616263313233)
            return(0x20, 0x80)
        }
    }

    /**
     * @notice Get a commitment hash for a given sender, tokenId, and salt. Note that this could expose your desired
     *         ID to the RPC provider.
     * @param sender The address of the account that will mint or reroll the token ID
     * @param xxyyzz The 6-hex-digit token ID to mint or reroll
     * @param salt The salt to use for the commitment
     */
    function computeCommitment(address sender, uint24 xxyyzz, bytes32 salt)
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

    /**
     * @notice Mint a token with a pseudorandom hex value
     */
    function mint() public payable {
        // if (msg.sender != tx.origin) {
        //     revert OnlyEOAs();
        // }
        // check max supply
        uint256 numberMinted = _numMinted;
        _checkMintAndIncrementNumMinted(numberMinted);
        if (numberMinted >= RANDOM_MINT_CUTOFF) {
            revert RandomMintingEnded();
        }

        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    ///@dev Find the first unminted token ID based on the current number minted and PREVRANDAO
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

    /**
     * @notice Mint a token with a specific hex value
     * @param xxyyzz The 6-hex-digit token ID to mint
     * @param salt The salt used in the commitment for the commitment
     */
    function mintSpecific(uint256 xxyyzz, bytes32 salt) public payable {
        // if (msg.sender != tx.origin) {
        //     revert OnlyEOAs();
        // }

        _checkMintAndIncrementNumMinted(_numMinted);

        _mintSpecific(xxyyzz, salt);
    }

    function _checkMintAndIncrementNumMinted(uint256 numberMinted) internal {
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
    }

    function reroll(uint256 oldXXYYZZ) public payable {
        _validateReroll(oldXXYYZZ, REROLL_PRICE);
        // burn old token
        _burn(oldXXYYZZ);

        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    function _validateReroll(uint256 id, uint256 price) internal view {
        // check mint price
        if (msg.value != price) {
            revert InvalidPayment();
        }
        // only owner can reroll; also checks for existence
        if (msg.sender != ownerOf(id)) {
            revert OnlyTokenOwner();
        }
        // once finalized, cannot reroll
        if (_isFinalized(id)) {
            revert AlreadyFinalized();
        }
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID
     * @param oldXXYYZZ The 6-hex-digit token ID to burn
     * @param newXXYYZZ The 6-hex-digit token ID to mint
     * @param salt The salt used in the commitment for the new ID commitment
     */
    function rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt, REROLL_SPECIFIC_PRICE);
    }

    function _rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt, uint256 price) internal {
        _validateReroll(oldXXYYZZ, price);
        // burn old token
        _burn(oldXXYYZZ);

        _mintSpecific(newXXYYZZ, salt);
    }

    function rerollSpecificAndFinalize(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        uint256 totalPrice;
        unchecked {
            totalPrice = REROLL_SPECIFIC_PRICE + FINALIZE_PRICE;
        }
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt, totalPrice);
        _finalize(newXXYYZZ, totalPrice);
    }

    /**
     * @notice Finalize a token, which updates its metadata with a "Finalizer" trait and prevents it from being
     *         rerolled in the future.
     * @param xxyyzz The 6-hex-digit token ID to finalize. Must be owned by the caller.
     */
    function finalize(uint256 xxyyzz) public payable {
        _finalize(xxyyzz, FINALIZE_PRICE);
    }

    function _finalize(uint256 xxyyzz, uint256 price) internal {
        // validate finalization price
        if (msg.value != price) {
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
        _finalizeToken(xxyyzz);
    }

    /**
     * @notice Check if a specific token has been finalized.
     */
    function isFinalized(uint256 xxyyzz) public view returns (bool) {
        if (!_exists(xxyyzz)) {
            revert TokenDoesNotExist();
        }
        return _isFinalized(xxyyzz);
    }

    /**
     * @notice Permanently burn a token that the caller owns or is approved for.
     */
    function burn(uint256 xxyyzz) public {
        _numBurned += 1;
        _burn(msg.sender, xxyyzz);
    }

    /**
     * @notice Permanently burn multiple tokens. All must be owned by the same address.
     */
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

    ///@dev Mint a token with a specific hex value and validate it was committed to
    function _mintSpecific(uint256 xxyyzz, bytes32 salt) internal {
        _validateId(xxyyzz);
        // validate commitment to prevent front-running
        bytes32 computedCommitment = computeCommitment(msg.sender, uint24(xxyyzz), salt);
        _assertCommittedReveal(computedCommitment);

        _mint(msg.sender, xxyyzz);
    }

    ///@dev Finalize a token, updating its metadata with a "Finalizer" trait, and preventing it from being rerolled in the future.
    function _finalizeToken(uint256 xxyyzz) internal {
        finalizers[xxyyzz] = msg.sender;
        _setExtraData(xxyyzz, 1);
    }

    ///@dev Check if a specific token has been finalized. Does not check if token exists.
    function _isFinalized(uint256 xxyyzz) internal view returns (bool) {
        return _getExtraData(xxyyzz) == FINALIZED;
    }

    ///@dev Check if an ID is a valid six-hex-digit number
    function _validateId(uint256 xxyyzz) internal pure {
        // check that xxyyzz is a valid 6-character hex number
        if (xxyyzz > MAX_UINT24) {
            revert InvalidHex();
        }
    }
}
