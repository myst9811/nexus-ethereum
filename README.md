# Nexus Bridge - Ethereum Contracts

Ethereum smart contracts for the Nexus Bridge, enabling secure cross-chain token transfers between Solana and Ethereum.

## Overview

Nexus Bridge is a decentralized cross-chain bridge that allows users to transfer tokens between the Solana and Ethereum blockchains. This repository contains the Ethereum-side smart contracts written in Solidity using the Hardhat development framework.

## Architecture

### Smart Contracts

- **BridgeLock.sol**: Main bridge contract that handles:
  - Locking ERC20 tokens on Ethereum to bridge to Solana
  - Unlocking tokens after proof of burn on Solana
  - Minting wrapped Solana tokens on Ethereum
  - Burning wrapped tokens to unlock originals on Solana

- **WrappedSolanaToken.sol**: ERC20 token contract representing Solana tokens on Ethereum
  - Mintable and burnable only by the bridge contract
  - Maintains 1:1 peg with original Solana tokens

- **IBridge.sol**: Interface defining the bridge protocol

### Key Features

- Cryptographic signature verification for cross-chain messages
- Nonce-based replay attack prevention
- Support for multiple ERC20 tokens
- Dynamic wrapped token registration
- Emergency withdrawal functionality
- Reentrancy protection

## Project Structure

```
nexus-ethereum/
├── contracts/
│   ├── BridgeLock.sol              # Main bridge contract
│   ├── WrappedSolanaToken.sol      # Wrapped token implementation
│   ├── MockERC20.sol               # Mock ERC20 for testing
│   └── interfaces/
│       └── IBridge.sol             # Bridge interface
├── scripts/
│   └── deploy.ts                   # Deployment script
├── test/
│   └── BridgeLock.test.ts          # Contract tests
├── hardhat.config.ts               # Hardhat configuration
├── .env.example                    # Environment variables template
└── README.md                       # This file
```

## Prerequisites

- Node.js v18+
- npm or yarn
- An Ethereum wallet with testnet/mainnet ETH for deployment

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd nexus-ethereum
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file:
```bash
cp .env.example .env
```

4. Configure your environment variables in `.env`:
```env
PRIVATE_KEY=your_private_key_here
VALIDATOR_ADDRESS=your_validator_address_here
SEPOLIA_RPC_URL=your_alchemy_or_infura_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Usage

### Compile Contracts

```bash
npm run compile
```

### Run Tests

```bash
npm test
```

### Test Coverage

```bash
npm run test:coverage
```

### Deploy to Local Network

1. Start a local Hardhat node:
```bash
npm run node
```

2. Deploy contracts (in a new terminal):
```bash
npm run deploy:localhost
```

### Deploy to Sepolia Testnet

```bash
npm run deploy:sepolia
```

### Deploy to Mainnet

```bash
npm run deploy:mainnet
```

## Bridge Flow

### Ethereum → Solana

1. User approves the bridge contract to spend their ERC20 tokens
2. User calls `lockTokens()` with:
   - Token address
   - Amount to lock
   - Solana recipient address
3. Tokens are locked in the bridge contract
4. Event is emitted with lock details
5. Relayer detects the event and mints wrapped tokens on Solana

### Solana → Ethereum

1. User burns wrapped tokens on Solana
2. Relayer detects burn event
3. Relayer calls `unlockTokens()` on Ethereum with validator signature
4. Bridge verifies signature and unlocks tokens to recipient

### Solana Token → Ethereum

1. User locks Solana tokens on Solana
2. Relayer detects lock event
3. Relayer calls `mintWrappedTokens()` on Ethereum with validator signature
4. Bridge mints wrapped ERC20 tokens to recipient

### Ethereum Wrapped Token → Solana

1. User calls `burnWrappedTokens()` on Ethereum
2. Wrapped tokens are burned
3. Event is emitted
4. Relayer detects event and unlocks original tokens on Solana

## Security Considerations

- All cross-chain messages must be signed by the authorized validator
- Nonces prevent replay attacks
- ReentrancyGuard protects against reentrancy attacks
- SafeERC20 prevents token transfer issues
- Emergency withdrawal available for owner only

## Testing

The test suite includes:

- Contract deployment tests
- Token locking/unlocking functionality
- Wrapped token minting/burning
- Signature verification
- Access control
- Edge cases and error conditions

Run tests with:
```bash
npm test
```

## Contract Verification

After deployment, verify your contracts on Etherscan:

```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## Gas Optimization

The contracts are optimized for gas efficiency:
- Optimizer enabled with 200 runs
- Minimal storage operations
- Efficient event emission

## Contributing

This is part of the Nexus Bridge project. For the complete bridge system, see:
- bridge-solana: Solana program implementation
- bridge-relayer: Off-chain relayer service
- bridge-frontend: User interface

## License

ISC

## Audit Status

⚠️ These contracts have not been audited. Use at your own risk.

## Support

For issues and questions, please open an issue on the GitHub repository.

## Roadmap

- [ ] Multi-signature validator support
- [ ] Pausable functionality
- [ ] Fee mechanism
- [ ] Governance token integration
- [ ] Professional security audit
- [ ] Mainnet deployment

## Deployment Addresses

### Testnet (Sepolia)
- BridgeLock: TBD
- Validator: TBD

### Mainnet
- BridgeLock: TBD
- Validator: TBD

---

Built with Hardhat and OpenZeppelin
