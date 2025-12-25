// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WrappedSolanaToken
 * @notice ERC20 token representing wrapped Solana tokens on Ethereum
 * @dev Only the bridge contract can mint and burn tokens
 */
contract WrappedSolanaToken is ERC20, Ownable {
    uint8 private _decimals;
    address public bridge;

    /**
     * @notice Constructor to create a wrapped token
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param decimals_ Token decimals
     * @param bridge_ Address of the bridge contract that can mint/burn
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address bridge_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(bridge_ != address(0), "Invalid bridge address");
        _decimals = decimals_;
        bridge = bridge_;
    }

    /**
     * @notice Returns the number of decimals used for token amounts
     * @return Number of decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint new wrapped tokens
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     * @dev Can only be called by the bridge contract
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == bridge, "Only bridge can mint");
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        _mint(to, amount);
    }

    /**
     * @notice Burn wrapped tokens
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Can only be called by the bridge contract
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == bridge, "Only bridge can burn");
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(from) >= amount, "Insufficient balance");
        _burn(from, amount);
    }

    /**
     * @notice Update the bridge address
     * @param newBridge New bridge contract address
     * @dev Can only be called by the owner
     */
    function updateBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "Invalid bridge address");
        bridge = newBridge;
    }
}
