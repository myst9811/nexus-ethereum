// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/IBridge.sol";
import "./WrappedSolanaToken.sol";

/**
 * @title BridgeLock
 * @notice Main bridge contract for locking/unlocking tokens between Ethereum and Solana
 * @dev Implements the Nexus bridge protocol with cryptographic verification
 */
contract BridgeLock is IBridge, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Mapping of token address => total locked amount
    mapping(address => uint256) public lockedBalances;

    // Mapping of nonce => processed status to prevent replay attacks
    mapping(uint256 => bool) public processedNonces;

    // Mapping of Solana token mint => Ethereum wrapped token address
    mapping(bytes32 => address) public wrappedTokens;

    // Mapping of Ethereum wrapped token => Solana token mint
    mapping(address => bytes32) public solanaTokenMints;

    // Authorized validator address for signing cross-chain messages
    address public validator;

    // Bridge nonce counter
    uint256 public nonce;

    // Minimum amount for bridging
    uint256 public constant MIN_BRIDGE_AMOUNT = 1e6; // 0.000001 tokens (assuming 18 decimals)

    /**
     * @notice Constructor to initialize the bridge
     * @param _validator Address of the authorized validator
     */
    constructor(address _validator) Ownable(msg.sender) {
        require(_validator != address(0), "Invalid validator address");
        validator = _validator;
    }

    /**
     * @notice Lock ERC20 tokens on Ethereum to bridge to Solana
     * @param token Address of the ERC20 token to lock
     * @param amount Amount of tokens to lock
     * @param solanaRecipient Solana wallet address (32 bytes)
     */
    function lockTokens(
        address token,
        uint256 amount,
        bytes32 solanaRecipient
    ) external override nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount >= MIN_BRIDGE_AMOUNT, "Amount too small");
        require(solanaRecipient != bytes32(0), "Invalid Solana recipient");

        // Transfer tokens from user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Update locked balance
        lockedBalances[token] += amount;

        // Increment nonce
        uint256 currentNonce = nonce++;

        emit TokensLocked(msg.sender, token, amount, solanaRecipient, currentNonce);
    }

    /**
     * @notice Unlock tokens on Ethereum after proof of burn on Solana
     * @param token Address of the token to unlock
     * @param amount Amount to unlock
     * @param recipient Ethereum address to receive tokens
     * @param unlockNonce Nonce from the Solana burn transaction
     * @param signature Validator signature proving the Solana burn
     */
    function unlockTokens(
        address token,
        uint256 amount,
        address recipient,
        uint256 unlockNonce,
        bytes calldata signature
    ) external override nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(recipient != address(0), "Invalid recipient");
        require(!processedNonces[unlockNonce], "Nonce already processed");
        require(lockedBalances[token] >= amount, "Insufficient locked balance");

        // Verify signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(token, amount, recipient, unlockNonce, "unlock")
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == validator, "Invalid signature");

        // Mark nonce as processed
        processedNonces[unlockNonce] = true;

        // Update locked balance
        lockedBalances[token] -= amount;

        // Transfer tokens to recipient
        IERC20(token).safeTransfer(recipient, amount);

        emit TokensUnlocked(recipient, token, amount, unlockNonce);
    }

    /**
     * @notice Mint wrapped Solana tokens on Ethereum
     * @param wrappedToken Address of the wrapped token contract
     * @param amount Amount to mint
     * @param recipient Ethereum address to receive wrapped tokens
     * @param solanaTokenMint Solana token mint address
     * @param mintNonce Nonce from the Solana lock transaction
     * @param signature Validator signature proving the Solana lock
     */
    function mintWrappedTokens(
        address wrappedToken,
        uint256 amount,
        address recipient,
        bytes32 solanaTokenMint,
        uint256 mintNonce,
        bytes calldata signature
    ) external override nonReentrant {
        require(wrappedToken != address(0), "Invalid wrapped token address");
        require(amount >= MIN_BRIDGE_AMOUNT, "Amount too small");
        require(recipient != address(0), "Invalid recipient");
        require(solanaTokenMint != bytes32(0), "Invalid Solana token mint");
        require(!processedNonces[mintNonce], "Nonce already processed");

        // Verify that this wrapped token corresponds to the Solana token mint
        require(
            wrappedTokens[solanaTokenMint] == wrappedToken,
            "Wrapped token mismatch"
        );

        // Verify signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                wrappedToken,
                amount,
                recipient,
                solanaTokenMint,
                mintNonce,
                "mint"
            )
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == validator, "Invalid signature");

        // Mark nonce as processed
        processedNonces[mintNonce] = true;

        // Mint wrapped tokens
        WrappedSolanaToken(wrappedToken).mint(recipient, amount);

        emit WrappedTokensMinted(recipient, wrappedToken, amount, solanaTokenMint, mintNonce);
    }

    /**
     * @notice Burn wrapped tokens to unlock original tokens on Solana
     * @param wrappedToken Address of the wrapped token to burn
     * @param amount Amount of wrapped tokens to burn
     * @param solanaRecipient Solana wallet address (32 bytes)
     */
    function burnWrappedTokens(
        address wrappedToken,
        uint256 amount,
        bytes32 solanaRecipient
    ) external override nonReentrant {
        require(wrappedToken != address(0), "Invalid wrapped token address");
        require(amount >= MIN_BRIDGE_AMOUNT, "Amount too small");
        require(solanaRecipient != bytes32(0), "Invalid Solana recipient");

        // Verify this is a registered wrapped token
        bytes32 solanaTokenMint = solanaTokenMints[wrappedToken];
        require(solanaTokenMint != bytes32(0), "Not a wrapped token");

        // Burn wrapped tokens
        WrappedSolanaToken(wrappedToken).burn(msg.sender, amount);

        // Increment nonce
        uint256 currentNonce = nonce++;

        emit WrappedTokensBurned(
            msg.sender,
            wrappedToken,
            amount,
            solanaRecipient,
            currentNonce
        );
    }

    /**
     * @notice Register a new wrapped token for a Solana token mint
     * @param solanaTokenMint Solana token mint address
     * @param name Name of the wrapped token
     * @param symbol Symbol of the wrapped token
     * @param decimals Decimals of the wrapped token
     * @return wrappedToken Address of the newly created wrapped token
     */
    function registerWrappedToken(
        bytes32 solanaTokenMint,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external onlyOwner returns (address) {
        require(solanaTokenMint != bytes32(0), "Invalid Solana token mint");
        require(wrappedTokens[solanaTokenMint] == address(0), "Already registered");

        // Deploy new wrapped token contract
        WrappedSolanaToken wrappedToken = new WrappedSolanaToken(
            name,
            symbol,
            decimals,
            address(this)
        );

        address wrappedTokenAddress = address(wrappedToken);

        // Register the mapping
        wrappedTokens[solanaTokenMint] = wrappedTokenAddress;
        solanaTokenMints[wrappedTokenAddress] = solanaTokenMint;

        return wrappedTokenAddress;
    }

    /**
     * @notice Update the validator address
     * @param newValidator New validator address
     */
    function updateValidator(address newValidator) external onlyOwner {
        require(newValidator != address(0), "Invalid validator address");
        validator = newValidator;
    }

    /**
     * @notice Emergency pause function to stop all bridging operations
     * @dev This is a placeholder for future implementation with Pausable pattern
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amount <= lockedBalances[token], "Insufficient balance");

        lockedBalances[token] -= amount;
        IERC20(token).safeTransfer(owner(), amount);
    }
}
