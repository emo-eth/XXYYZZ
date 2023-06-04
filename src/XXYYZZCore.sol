// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solady/tokens/ERC721.sol";
import {CommitReveal} from "./lib/CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

abstract contract XXYYZZCore is ERC721, CommitReveal, Ownable {
    error InvalidPayment();
    error InvalidHex();
    error MaximumSupplyExceeded();
    error AlreadyFinalized();
    error OnlyTokenOwner();
    error NoIdsProvided();
    error OwnerMismatch();
    error BulkBurnerNotApprovedForAll();
    error RandomMintingEnded();
    error ArrayLengthMismatch();
    error MaximumMintsPerWalletExceeded();
    error MintClosed();
    error InvalidTimestamp();

    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant REROLL_PRICE = 0.005 ether;
    uint256 public constant REROLL_SPECIFIC_PRICE = 0.005 ether;
    uint256 public constant FINALIZE_PRICE = 0.02 ether;

    uint256 constant BYTES3_UINT_SHIFT = 232;
    uint256 constant MAX_UINT24 = 0xFFFFFF;
    uint96 constant FINALIZED = 1;
    uint96 constant NOT_FINALIZED = 0;
    // re-declared from solady ERC721 for custom gas optimizations
    uint256 private constant _ERC721_MASTER_SLOT_SEED = 0x7d8825530a5a2e7a << 192;

    mapping(uint256 tokenId => address finalizer) public finalizers;
    uint64 _numMinted;
    uint64 _numBurned;
    uint64 public mintCloseTimestamp;

    constructor(address initialOwner) CommitReveal(1 days, 1 minutes, 5) {
        _initializeOwner(initialOwner);
    }

    receive() external payable {
        // send ether – see what happens! :)
    }

    ///////////////////
    // OWNER METHODS //
    ///////////////////

    /**
     * @notice Withdraws all funds from the contract to the current owner. onlyOwner.
     */
    function withdraw() public onlyOwner {
        assembly {
            let succ := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
            // revert with returndata if call failed
            if iszero(succ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    ///////////////////
    // INFORMATIONAL //
    ///////////////////

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
     * @notice Check if a specific token ID has been finalized. Will return true for tokens that were finalized and
     *         then burned. Will not revert if the tokenID does not currently exist. Will revert on invalid tokenIds.
     */
    function isFinalized(uint256 xxyyzz) public view returns (bool) {
        _validateId(xxyyzz);
        return _isFinalized(xxyyzz);
    }

    /////////////////
    // COMMITMENTS //
    /////////////////

    /**
     * @notice Get a commitment hash for a given sender, tokenId, and salt. Note that this could expose your desired
     *         ID to the RPC provider. Won't revert if the ID is invalid, but will return an invalid hash.
     * @param sender The address of the account that will mint or reroll the token ID
     * @param xxyyzz The 6-hex-digit token ID to mint or reroll
     * @param salt The salt to use for the commitment
     */
    function computeCommitment(address sender, uint256 xxyyzz, bytes32 salt)
        public
        pure
        returns (bytes32 committmentHash)
    {
        assembly {
            // shift sender to top 160 bits; id stays in bottom 24
            mstore(0, or(shl(96, sender), and(xxyyzz, MAX_UINT24)))
            mstore(0x20, salt)
            committmentHash := keccak256(0, 0x40)
        }
    }

    /**
     * @notice Get a commitment hash for a given sender, tokenIds, and salts. Note that this could expose your desired
     *         IDs to the RPC provider. Won't revert if the IDs are invalid, but will return invalid hashes.
     * @param sender The address of the account that will mint or reroll the token IDs
     * @param ids The 6-hex-digit token IDs to mint or reroll
     * @param salts The salts to use for the commitments
     */
    function computeCommitments(address sender, uint256[] calldata ids, bytes32[] calldata salts)
        public
        pure
        returns (bytes32[] memory commitmentHashes)
    {
        if (ids.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        commitmentHashes = new bytes32[](ids.length);
        for (uint256 i; i < ids.length;) {
            commitmentHashes[i] = computeCommitment(sender, ids[i], salts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Get a commitment hash for a given sender, array of tokenIds, and salt. This allows for a single
     *         commitment for a batch of IDs, but note that order and length of IDs matters.
     *         If 5 IDs are passed, all 5 must be passed to either batchMintSpecific or batchRerollSpecific, in the
     *         same order. Note that this could expose your desired IDs to the RPC provider.
     *         Won't revert if any IDs are invalid or duplicated.
     * @param sender The address of the account that will mint or reroll the token IDs
     * @param ids The 6-hex-digit token IDs to mint or reroll
     * @param salt The salt to use for the batch commitment
     */
    function computeBatchCommitment(address sender, uint256[] memory ids, bytes32 salt)
        public
        pure
        returns (bytes32 commitmentHash)
    {
        assembly {
            // hash contents of array minus length
            let arrayHash :=
                keccak256(
                    // add 0x20 to get start of array contents
                    add(0x20, ids),
                    // multiply length of elements by 32 bytes for each element
                    // shl by 5 is equivalent to multiplying by 0x20
                    shl(5, mload(ids))
                )

            // cache free mem pointer
            let freeMemPtr := mload(0x40)
            // store sender in first memory slot
            mstore(0, sender)
            // store array hash in second memory slot
            mstore(0x20, arrayHash)
            // clobber free memory pointer with salt
            mstore(0x40, salt)
            // compute commitment hash
            commitmentHash := keccak256(0, 0x60)
            // restore free memory pointer
            mstore(0x40, freeMemPtr)
        }
    }

    /////////////
    // HELPERS //
    /////////////

    ///@dev Mint a token with a specific hex value and validate it was committed to
    function _mintSpecific(uint256 xxyyzz, bytes32 salt) internal {
        _mintSpecificWithCommitment(xxyyzz, computeCommitment(msg.sender, xxyyzz, salt));
    }

    ///@dev Mint a token with a specific hex value and validate it was committed to
    function _mintSpecificWithCommitment(uint256 xxyyzz, bytes32 computedCommitment) internal {
        // validate ID is valid 6-hex-digit number
        _validateId(xxyyzz);
        // validate commitment to prevent front-running
        _assertCommittedReveal(computedCommitment);

        // don't allow minting of tokens that were finalized and then burned
        if (_isFinalized(xxyyzz)) {
            revert AlreadyFinalized();
        }
        _mint(msg.sender, xxyyzz);
    }

    /**
     * @dev Find the first unminted token ID based on the current number minted and PREVRANDAO
     * @param seed The seed to use for the random number generation – when minting, should be _numMinted, when
     *             re-rolling, should be caller. In the case of re-rolling, this means that if a single caller makes
     *             multiple re-rolls in the same block, there will be collisions. This is fine, as the extra gas  cost
     *             discourages batch re-rolling with bots or scripts (at least from the same address).
     */
    function _findAvailableHex(uint256 seed) internal view returns (uint256) {
        uint256 tokenId;
        assembly ("memory-safe") {
            mstore(0, seed)
            mstore(0x20, prevrandao())
            // mstore(0x20, blockhash(sub(number(), 1)))
            // hash the two values together and then mask to a uint24
            tokenId := and(keccak256(0, 0x40), MAX_UINT24)
        }
        // check for the small chance that the token ID is already minted or finalized – if so, increment until we
        // find one that isn't
        while (_loadRawOwnershipSlot(tokenId) != 0) {
            // safe to do unchecked math here as it is modulo 2^24
            unchecked {
                tokenId = (tokenId + 1) & MAX_UINT24;
            }
        }
        return tokenId;
    }

    ///@dev Check if an ID is a valid six-hex-digit number
    function _validateId(uint256 xxyyzz) internal pure {
        if (xxyyzz > MAX_UINT24) {
            revert InvalidHex();
        }
    }

    ///@dev Validate msg value is equal to price
    function _validatePayment(uint256 unitPrice, uint256 quantity) internal view {
        // can't overflow because there are at most uint24 tokens, and existence is checked for each token down the line
        unchecked {
            if (msg.value != (unitPrice * quantity)) {
                revert InvalidPayment();
            }
        }
    }

    ///@dev Check if a specific token has been finalized. Does not check if token exists.
    function _isFinalized(uint256 xxyyzz) internal view returns (bool) {
        return _getExtraData(xxyyzz) == FINALIZED;
    }

    /**
     * @dev Load the raw ownership slot for a given token ID, which contains both the owner and the extra data
     *      (finalization status). This allows for succint checking of whether or not a token is mintable,
     *      i.e., whether it does not currently exist and has not been finalized. It also allows for avoiding
     *      an extra SLOAD in cases when checking both owner/existence and finalization status.
     */
    function _loadRawOwnershipSlot(uint256 id) internal view returns (uint256 result) {
        assembly ("memory-safe") {
            // since all ids are < uint24, this basically just clears the 0-slot before writing 4 bytes of slot seed
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            result := sload(add(id, add(id, keccak256(0x00, 0x20))))
        }
    }

    function _checkCallerIsOwnerAndNotFinalized(uint256 id) internal view {
        uint256 rawSlot = _loadRawOwnershipSlot(id);
        // clean and cast to address
        address owner = address(uint160(rawSlot));
        if ((rawSlot) > type(uint160).max) {
            revert AlreadyFinalized();
        }
        // if completely empty, token does not exist
        if (rawSlot == 0) {
            revert TokenDoesNotExist();
        }
        // check that caller is owner
        if (owner != msg.sender) {
            revert OnlyTokenOwner();
        }
    }
}
