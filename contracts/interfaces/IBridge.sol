// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBridge
 * @notice Interface for the Nexus Bridge between Solana and Ethereum
 */
interface IBridge {
    /**
     * @notice Emitted when tokens are locked on Ethereum to be bridged to Solana
     * @param user Address of the user locking tokens
     * @param token Address of the token being locked
     * @param amount Amount of tokens locked
     * @param solanaRecipient Solana wallet address to receive wrapped tokens
     * @param nonce Unique nonce for this lock transaction
     */
    event TokensLocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        bytes32 solanaRecipient,
        uint256 indexed nonce
    );

    /**
     * @notice Emitted when tokens are unlocked on Ethereum after being burned on Solana
     * @param user Address of the user receiving unlocked tokens
     * @param token Address of the token being unlocked
     * @param amount Amount of tokens unlocked
     * @param nonce Unique nonce for this unlock transaction
     */
    event TokensUnlocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 indexed nonce
    );

    /**
     * @notice Emitted when wrapped tokens are minted on Ethereum
     * @param user Address receiving the wrapped tokens
     * @param wrappedToken Address of the wrapped token contract
     * @param amount Amount of wrapped tokens minted
     * @param solanaTokenMint Solana token mint address
     * @param nonce Unique nonce for this mint transaction
     */
    event WrappedTokensMinted(
        address indexed user,
        address indexed wrappedToken,
        uint256 amount,
        bytes32 solanaTokenMint,
        uint256 indexed nonce
    );

    /**
     * @notice Emitted when wrapped tokens are burned on Ethereum
     * @param user Address of the user burning wrapped tokens
     * @param wrappedToken Address of the wrapped token contract
     * @param amount Amount of wrapped tokens burned
     * @param solanaRecipient Solana wallet address to receive original tokens
     * @param nonce Unique nonce for this burn transaction
     */
    event WrappedTokensBurned(
        address indexed user,
        address indexed wrappedToken,
        uint256 amount,
        bytes32 solanaRecipient,
        uint256 indexed nonce
    );

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
    ) external;

    /**
     * @notice Unlock tokens on Ethereum after proof of burn on Solana
     * @param token Address of the token to unlock
     * @param amount Amount to unlock
     * @param recipient Ethereum address to receive tokens
     * @param nonce Nonce from the Solana burn transaction
     * @param signature Validator signature proving the Solana burn
     */
    function unlockTokens(
        address token,
        uint256 amount,
        address recipient,
        uint256 nonce,
        bytes calldata signature
    ) external;

    /**
     * @notice Mint wrapped Solana tokens on Ethereum
     * @param wrappedToken Address of the wrapped token contract
     * @param amount Amount to mint
     * @param recipient Ethereum address to receive wrapped tokens
     * @param solanaTokenMint Solana token mint address
     * @param nonce Nonce from the Solana lock transaction
     * @param signature Validator signature proving the Solana lock
     */
    function mintWrappedTokens(
        address wrappedToken,
        uint256 amount,
        address recipient,
        bytes32 solanaTokenMint,
        uint256 nonce,
        bytes calldata signature
    ) external;

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
    ) external;
}
