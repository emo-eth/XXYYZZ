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
    uint256 public immutable MAX_MINTS_PER_WALLET;

    mapping(uint256 tokenId => address finalizer) public finalizers;
    uint128 _numMinted;
    uint128 _numBurned;

    constructor(address initialOwner, uint256 maxMintsPerWallet) CommitReveal(1 days, 1 minutes, 5) {
        _initializeOwner(initialOwner);
        MAX_MINTS_PER_WALLET = maxMintsPerWallet;
    }

    /////////////////
    // WITHDRAWALS //
    /////////////////

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

    //////////
    // MINT //
    //////////

    /**
     * @notice Mint a token with a pseudorandom hex value.
     */
    function mint() public payable {
        _checkRandomMintAndIncrementNumMinted(1);

        // get pseudorandom hex id
        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    /**
     * @notice Mint a number of tokens with pseudorandom hex values.
     * @param quantity The number of tokens to mint
     */
    function mint(uint256 quantity) public payable {
        // check payment and quantity once
        _checkRandomMintAndIncrementNumMinted(quantity);
        for (uint256 i; i < quantity;) {
            // get pseudorandom hex id
            uint256 tokenId = _findAvailableHex();
            _mint(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    ///@dev Perform price and quantity validation as well as random mint cutoff validation
    function _checkRandomMintAndIncrementNumMinted(uint256 quantity) internal {
        uint256 newAmount = _checkMintAndIncrementNumMinted(quantity);
        // ensure a certain number are reserved for mints of specific IDs
        if (newAmount > RANDOM_MINT_CUTOFF) {
            revert RandomMintingEnded();
        }
    }

    ///@dev Find the first unminted token ID based on the current number minted and PREVRANDAO
    function _findAvailableHex() internal view returns (uint256) {
        uint256 tokenId;
        assembly ("memory-safe") {
            // this is packed with _numBurned but that's fine for pseudorandom purposes, since it changes
            // with each new token minted
            mstore(0, sload(_numMinted.slot))
            mstore(0x20, prevrandao())
            // mstore(0x20, blockhash(sub(number(), 1)))
            // hash the two values together and then mask to a uint24
            tokenId := and(keccak256(0, 0x40), MAX_UINT24)
        }
        // check for the small chance that the token ID is already minted – if so, increment until we find one that
        // isn't
        while (_exists(tokenId) || _isFinalized(tokenId)) {
            // safe to do unchecked math here as it is modulo 2^24
            unchecked {
                tokenId = (tokenId + 1) & MAX_UINT24;
            }
        }
        return tokenId;
    }

    /**
     * @notice Mint a token with a specific hex value.
     *         A user must first call commit(bytes32) or batchCommit(bytes32[]) with the result(s) of
     *         computeCommittment(address,uint24,bytes32), and wait at least one minute.
     *         When calling mintSpecific, the "salt" should be the bytes32 salt provided to `computeCommitment` when
     *         creating the commitment hash.
     *
     *         Example: To register 0x123456 with salt bytes32(0xDEADBEEF)
     *             1. Call `computeCommitment(<minting addr>, 0x123456, bytes32(0xDEADBEEF))` for `bytes32 result`
     *             2. Call `commit(result)`
     *             3. Wait at least 1 minute, but less than 1 day
     *             4. Call `mintSpecific(0x123456, bytes32(0xDEADBEEF))`
     * @param xxyyzz The 6-hex-digit token ID to mint
     * @param salt The salt used in the commitment for the commitment
     */
    function mintSpecific(uint256 xxyyzz, bytes32 salt) public payable {
        _checkMintAndIncrementNumMinted(1);
        _mintSpecific(xxyyzz, salt);
    }

    /**
     * @notice Mint a number of tokens with specific hex values.
     *         A user must first call commit(bytes32) with the result of computeCommittment(address,uint24,bytes32), and wait at least one minute.
     *
     * @param ids The 6-hex-digit token IDs to mint
     * @param salts The salts used in the commitments for the tokens
     */
    function mintSpecific(uint256[] calldata ids, bytes32[] calldata salts) public payable {
        if (ids.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        _checkMintAndIncrementNumMinted(ids.length);
        bytes32[] memory computedCommitments = computeCommitments(msg.sender, ids, salts);
        for (uint256 i; i < ids.length;) {
            _mintSpecificWithCommitment(ids[i], computedCommitments[i]);
            unchecked {
                ++i;
            }
        }
    }

    ///@dev Check payment and quantity validation
    function _checkMintAndIncrementNumMinted(uint256 quantity) internal returns (uint256) {
        uint256 newAmount = _numMinted + quantity;
        uint256 totalPrice;
        uint256 newUserNumMinted;

        unchecked {
            totalPrice = quantity * MINT_PRICE;
            newUserNumMinted = _getAux(msg.sender) + quantity;
        }
        _validatePayment(totalPrice);
        if (newAmount > MAX_SUPPLY) {
            revert MaximumSupplyExceeded();
        }
        if (newUserNumMinted > MAX_MINTS_PER_WALLET) {
            revert MaximumMintsPerWalletExceeded();
        }

        // increment supply before minting
        unchecked {
            _numMinted = uint128(newAmount);
            _setAux(msg.sender, uint224(newUserNumMinted));
        }
        return newAmount;
    }

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

    ////////////
    // REROLL //
    ////////////

    /**
     * @notice Burn a token you own and mint a new one with a pseudorandom hex value.
     * @param oldXXYYZZ The 6-hex-digit token ID to burn
     */
    function reroll(uint256 oldXXYYZZ) public payable {
        _validatePayment(REROLL_PRICE);
        _reroll(oldXXYYZZ);
    }

    /**
     * @notice Burn a number of tokens you own and mint new ones with pseudorandom hex values.
     * @param ids The 6-hex-digit token IDs to burn
     */
    function batchReroll(uint256[] calldata ids) public payable {
        // unchecked block is safe because there are at most 2^24 tokens
        unchecked {
            _validatePayment(ids.length * REROLL_PRICE);
        }
        for (uint256 i; i < ids.length;) {
            _reroll(ids[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID
     * @param oldXXYYZZ The 6-hex-digit token ID to burn
     * @param newXXYYZZ The 6-hex-digit token ID to mint
     * @param salt The salt used in the commitment for the new ID commitment
     */
    function rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        _validatePayment(REROLL_SPECIFIC_PRICE);
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt);
    }

    /**
     * @notice Burn and re-mint a number of tokens with specific hex values.
     * @param oldIds The 6-hex-digit token IDs to burn
     * @param newIds The 6-hex-digit token IDs to mint
     * @param salts The salts used in the commitments for the new ID commitments
     */
    function batchRerollSpecific(uint256[] calldata oldIds, uint256[] calldata newIds, bytes32[] calldata salts)
        public
        payable
    {
        if (oldIds.length != newIds.length || oldIds.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        uint256 totalPrice;
        unchecked {
            totalPrice = oldIds.length * REROLL_SPECIFIC_PRICE;
        }
        _validatePayment(totalPrice);
        for (uint256 i; i < oldIds.length;) {
            _rerollSpecific(oldIds[i], newIds[i], salts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID, then finalize it.
     */
    function rerollSpecificAndFinalize(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        uint256 totalPrice;
        unchecked {
            totalPrice = REROLL_SPECIFIC_PRICE + FINALIZE_PRICE;
        }
        _validatePayment(totalPrice);
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt);
        // won't re-validate price, but above function already did
        _finalize(newXXYYZZ);
    }

    /**
     * @notice Burn and re-mint a number of tokens with specific hex values, then finalize them.
     */

    function batchRerollSpecificAndFinalize(
        uint256[] calldata oldIds,
        uint256[] calldata newIds,
        bytes32[] calldata salts
    ) public payable {
        if (oldIds.length != newIds.length || oldIds.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        uint256 totalPrice;
        unchecked {
            totalPrice = (oldIds.length * REROLL_SPECIFIC_PRICE) + (oldIds.length * FINALIZE_PRICE);
        }
        _validatePayment(totalPrice);
        for (uint256 i; i < oldIds.length;) {
            uint256 newId = newIds[i];
            _rerollSpecific(oldIds[i], newId, salts[i]);
            _finalize(newId);
            unchecked {
                ++i;
            }
        }
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a new hex ID
    function _reroll(uint256 oldXXYYZZ) internal {
        _validateReroll(oldXXYYZZ);
        // burn old token
        _burn(oldXXYYZZ);
        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    ///@dev Validate msg.value, msg.sender, and finalized status of an ID for rerolling
    function _validateReroll(uint256 id) internal view {
        // only owner can reroll; also checks for existence
        if (msg.sender != ownerOf(id)) {
            revert OnlyTokenOwner();
        }
        // once finalized, cannot reroll
        if (_isFinalized(id)) {
            revert AlreadyFinalized();
        }
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a specific new hex ID
    function _rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) internal {
        _validateReroll(oldXXYYZZ);
        // burn old token
        _burn(oldXXYYZZ);
        _mintSpecific(newXXYYZZ, salt);
    }

    //////////////
    // FINALIZE //
    //////////////

    /**
     * @notice Finalize a token, which updates its metadata with a "Finalizer" trait and prevents it from being
     *         rerolled in the future.
     * @param xxyyzz The 6-hex-digit token ID to finalize. Must be owned by the caller.
     */
    function finalize(uint256 xxyyzz) public payable {
        _validatePayment(FINALIZE_PRICE);
        _finalize(xxyyzz);
    }

    /**
     * @notice Finalize a number of tokens, which updates their metadata with a "Finalizer" trait and prevents them
     *         from being rerolled in the future. The caller must pay the finalization price for each token, and must
     *         own all tokens.
     * @param ids The 6-hex-digit token IDs to finalize
     */
    function batchFinalize(uint256[] calldata ids) public payable {
        uint256 totalPrice;
        // can't overflow because there are at most uint24 tokens, and _finalize checks for existence
        unchecked {
            totalPrice = ids.length * FINALIZE_PRICE;
        }
        _validatePayment(totalPrice);
        for (uint256 i; i < ids.length;) {
            _finalize(ids[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _finalize(uint256 xxyyzz) internal {
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
        _finalizeToken(xxyyzz, msg.sender);
    }

    ///@dev Finalize a token, updating its metadata with a "Finalizer" trait, and preventing it from being rerolled in the future.
    function _finalizeToken(uint256 xxyyzz, address finalizer) internal {
        finalizers[xxyyzz] = finalizer;
        _setExtraData(xxyyzz, 1);
    }

    ///@dev Check if a specific token has been finalized. Does not check if token exists.
    function _isFinalized(uint256 xxyyzz) internal view returns (bool) {
        return _getExtraData(xxyyzz) == FINALIZED;
    }

    //////////
    // BURN //
    //////////

    /**
     * @notice Permanently burn a token that the caller owns or is approved for.
     */
    function burn(uint256 xxyyzz) public {
        // cannot overflow as there are at most 2^24 tokens, and _numBurned is a uint128
        unchecked {
            _numBurned += 1;
        }
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
        // validate that msg.sender has approval to burn all tokens
        if (!(initialTokenOwner == msg.sender || isApprovedForAll(initialTokenOwner, msg.sender))) {
            revert BulkBurnerNotApprovedForAll();
        }
        // safe because there are at most 2^24 tokens, and ownerships are checked
        unchecked {
            _numBurned += uint128(ids.length);
        }
        _burn(ids[0]);
        for (uint256 i = 1; i < ids.length;) {
            uint256 id = ids[i];
            // ensure that all tokens are owned by the same address
            if (_ownerOf(id) != initialTokenOwner) {
                revert OwnerMismatch();
            }
            // no need to specify msg.sender since they are approved for all tokens
            // this also checks token exists
            _burn(id);
            unchecked {
                ++i;
            }
        }
    }

    /////////////
    // HELPERS //
    /////////////

    ///@dev Check if an ID is a valid six-hex-digit number
    function _validateId(uint256 xxyyzz) internal pure {
        if (xxyyzz > MAX_UINT24) {
            revert InvalidHex();
        }
    }

    ///@dev Validate msg value is equal to price
    function _validatePayment(uint256 price) internal view {
        if (msg.value != price) {
            revert InvalidPayment();
        }
    }
}
