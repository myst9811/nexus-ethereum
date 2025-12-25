import { expect } from "chai";
import { ethers } from "hardhat";
import { BridgeLock, WrappedSolanaToken, MockERC20 } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("BridgeLock", function () {
  let bridgeLock: BridgeLock;
  let mockToken: MockERC20;
  let wrappedToken: WrappedSolanaToken;
  let owner: SignerWithAddress;
  let validator: SignerWithAddress;
  let user: SignerWithAddress;
  let recipient: SignerWithAddress;

  const INITIAL_SUPPLY = ethers.parseEther("1000000");
  const LOCK_AMOUNT = ethers.parseEther("100");
  const SOLANA_RECIPIENT = ethers.encodeBytes32String("SolanaWallet123");
  const SOLANA_TOKEN_MINT = ethers.encodeBytes32String("SolanaTokenMint");

  beforeEach(async function () {
    [owner, validator, user, recipient] = await ethers.getSigners();


    const BridgeLock = await ethers.getContractFactory("BridgeLock");
    bridgeLock = await BridgeLock.deploy(validator.address);
    await bridgeLock.waitForDeployment();

    
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockToken = await MockERC20.deploy("Mock Token", "MTK", INITIAL_SUPPLY);
    await mockToken.waitForDeployment();
    
    await mockToken.transfer(user.address, LOCK_AMOUNT * 10n);
  });

  describe("Deployment", function () {
    it("Should set the correct validator", async function () {
      expect(await bridgeLock.validator()).to.equal(validator.address);
    });

    it("Should set the correct owner", async function () {
      expect(await bridgeLock.owner()).to.equal(owner.address);
    });

    it("Should revert if validator address is zero", async function () {
      const BridgeLock = await ethers.getContractFactory("BridgeLock");
      await expect(
        BridgeLock.deploy(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid validator address");
    });
  });

  describe("Lock Tokens", function () {
    it("Should lock tokens successfully", async function () {
      // Approve bridge to spend tokens
      await mockToken.connect(user).approve(await bridgeLock.getAddress(), LOCK_AMOUNT);

      // Lock tokens
      await expect(
        bridgeLock.connect(user).lockTokens(
          await mockToken.getAddress(),
          LOCK_AMOUNT,
          SOLANA_RECIPIENT
        )
      )
        .to.emit(bridgeLock, "TokensLocked")
        .withArgs(user.address, await mockToken.getAddress(), LOCK_AMOUNT, SOLANA_RECIPIENT, 0);

      // Check locked balance
      expect(await bridgeLock.lockedBalances(await mockToken.getAddress())).to.equal(LOCK_AMOUNT);
    });

    it("Should increment nonce after locking", async function () {
      await mockToken.connect(user).approve(await bridgeLock.getAddress(), LOCK_AMOUNT * 2n);

      await bridgeLock.connect(user).lockTokens(
        await mockToken.getAddress(),
        LOCK_AMOUNT,
        SOLANA_RECIPIENT
      );

      expect(await bridgeLock.nonce()).to.equal(1);

      await bridgeLock.connect(user).lockTokens(
        await mockToken.getAddress(),
        LOCK_AMOUNT,
        SOLANA_RECIPIENT
      );

      expect(await bridgeLock.nonce()).to.equal(2);
    });

    it("Should revert if amount is too small", async function () {
      const smallAmount = 100n; // Less than MIN_BRIDGE_AMOUNT

      await mockToken.connect(user).approve(await bridgeLock.getAddress(), smallAmount);

      await expect(
        bridgeLock.connect(user).lockTokens(
          await mockToken.getAddress(),
          smallAmount,
          SOLANA_RECIPIENT
        )
      ).to.be.revertedWith("Amount too small");
    });

    it("Should revert if Solana recipient is zero", async function () {
      await mockToken.connect(user).approve(await bridgeLock.getAddress(), LOCK_AMOUNT);

      await expect(
        bridgeLock.connect(user).lockTokens(
          await mockToken.getAddress(),
          LOCK_AMOUNT,
          ethers.ZeroHash
        )
      ).to.be.revertedWith("Invalid Solana recipient");
    });
  });

  describe("Unlock Tokens", function () {
    let unlockNonce: number;
    let signature: string;

    beforeEach(async function () {
      // Lock some tokens first
      await mockToken.connect(user).approve(await bridgeLock.getAddress(), LOCK_AMOUNT);
      await bridgeLock.connect(user).lockTokens(
        await mockToken.getAddress(),
        LOCK_AMOUNT,
        SOLANA_RECIPIENT
      );

      unlockNonce = 12345;

      // Create signature - must match the contract's abi.encodePacked
      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "address", "uint256", "string"],
        [await mockToken.getAddress(), LOCK_AMOUNT, recipient.address, unlockNonce, "unlock"]
      );

      signature = await validator.signMessage(ethers.getBytes(messageHash));
    });

    it("Should unlock tokens with valid signature", async function () {
      await expect(
        bridgeLock.unlockTokens(
          await mockToken.getAddress(),
          LOCK_AMOUNT,
          recipient.address,
          unlockNonce,
          signature
        )
      )
        .to.emit(bridgeLock, "TokensUnlocked")
        .withArgs(recipient.address, await mockToken.getAddress(), LOCK_AMOUNT, unlockNonce);

      expect(await mockToken.balanceOf(recipient.address)).to.equal(LOCK_AMOUNT);
    });

    it("Should mark nonce as processed", async function () {
      await bridgeLock.unlockTokens(
        await mockToken.getAddress(),
        LOCK_AMOUNT,
        recipient.address,
        unlockNonce,
        signature
      );

      expect(await bridgeLock.processedNonces(unlockNonce)).to.be.true;
    });

    it("Should revert if nonce already processed", async function () {
      await bridgeLock.unlockTokens(
        await mockToken.getAddress(),
        LOCK_AMOUNT,
        recipient.address,
        unlockNonce,
        signature
      );

      await expect(
        bridgeLock.unlockTokens(
          await mockToken.getAddress(),
          LOCK_AMOUNT,
          recipient.address,
          unlockNonce,
          signature
        )
      ).to.be.revertedWith("Nonce already processed");
    });

    it("Should revert with invalid signature", async function () {
      const invalidSignature = await user.signMessage(
        ethers.getBytes(ethers.keccak256(ethers.toUtf8Bytes("invalid")))
      );

      await expect(
        bridgeLock.unlockTokens(
          await mockToken.getAddress(),
          LOCK_AMOUNT,
          recipient.address,
          unlockNonce,
          invalidSignature
        )
      ).to.be.revertedWith("Invalid signature");
    });
  });

  describe("Wrapped Token Management", function () {
    it("Should register a new wrapped token", async function () {
      const tx = await bridgeLock.registerWrappedToken(
        SOLANA_TOKEN_MINT,
        "Wrapped SOL Token",
        "wSOL",
        9
      );

      const receipt = await tx.wait();
      const wrappedTokenAddress = await bridgeLock.wrappedTokens(SOLANA_TOKEN_MINT);

      expect(wrappedTokenAddress).to.not.equal(ethers.ZeroAddress);
      expect(await bridgeLock.solanaTokenMints(wrappedTokenAddress)).to.equal(SOLANA_TOKEN_MINT);
    });

    it("Should revert if trying to register twice", async function () {
      await bridgeLock.registerWrappedToken(
        SOLANA_TOKEN_MINT,
        "Wrapped SOL Token",
        "wSOL",
        9
      );

      await expect(
        bridgeLock.registerWrappedToken(
          SOLANA_TOKEN_MINT,
          "Wrapped SOL Token 2",
          "wSOL2",
          9
        )
      ).to.be.revertedWith("Already registered");
    });

    it("Should only allow owner to register wrapped tokens", async function () {
      await expect(
        bridgeLock.connect(user).registerWrappedToken(
          SOLANA_TOKEN_MINT,
          "Wrapped SOL Token",
          "wSOL",
          9
        )
      ).to.be.reverted;
    });
  });

  describe("Burn Wrapped Tokens", function () {
    beforeEach(async function () {
      // Register and get wrapped token
      await bridgeLock.registerWrappedToken(
        SOLANA_TOKEN_MINT,
        "Wrapped SOL Token",
        "wSOL",
        9
      );

      const wrappedTokenAddress = await bridgeLock.wrappedTokens(SOLANA_TOKEN_MINT);
      wrappedToken = await ethers.getContractAt("WrappedSolanaToken", wrappedTokenAddress);

      // Mint some wrapped tokens to user via bridge
      const mintNonce = 54321;
      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "address", "bytes32", "uint256", "string"],
        [wrappedTokenAddress, LOCK_AMOUNT, user.address, SOLANA_TOKEN_MINT, mintNonce, "mint"]
      );
      const signature = await validator.signMessage(ethers.getBytes(messageHash));

      await bridgeLock.mintWrappedTokens(
        wrappedTokenAddress,
        LOCK_AMOUNT,
        user.address,
        SOLANA_TOKEN_MINT,
        mintNonce,
        signature
      );
    });

    it("Should burn wrapped tokens successfully", async function () {
      const initialBalance = await wrappedToken.balanceOf(user.address);

      await expect(
        bridgeLock.connect(user).burnWrappedTokens(
          await wrappedToken.getAddress(),
          LOCK_AMOUNT,
          SOLANA_RECIPIENT
        )
      )
        .to.emit(bridgeLock, "WrappedTokensBurned")
        .withArgs(user.address, await wrappedToken.getAddress(), LOCK_AMOUNT, SOLANA_RECIPIENT, 0);

      expect(await wrappedToken.balanceOf(user.address)).to.equal(initialBalance - LOCK_AMOUNT);
    });

    it("Should revert if not a registered wrapped token", async function () {
      await expect(
        bridgeLock.connect(user).burnWrappedTokens(
          await mockToken.getAddress(),
          LOCK_AMOUNT,
          SOLANA_RECIPIENT
        )
      ).to.be.revertedWith("Not a wrapped token");
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to update validator", async function () {
      const newValidator = recipient.address;
      await bridgeLock.updateValidator(newValidator);
      expect(await bridgeLock.validator()).to.equal(newValidator);
    });

    it("Should revert if non-owner tries to update validator", async function () {
      await expect(
        bridgeLock.connect(user).updateValidator(recipient.address)
      ).to.be.reverted;
    });

    it("Should allow emergency withdraw", async function () {
      // Lock some tokens
      await mockToken.connect(user).approve(await bridgeLock.getAddress(), LOCK_AMOUNT);
      await bridgeLock.connect(user).lockTokens(
        await mockToken.getAddress(),
        LOCK_AMOUNT,
        SOLANA_RECIPIENT
      );

      const ownerBalanceBefore = await mockToken.balanceOf(owner.address);

      await bridgeLock.emergencyWithdraw(await mockToken.getAddress(), LOCK_AMOUNT);

      expect(await mockToken.balanceOf(owner.address)).to.equal(
        ownerBalanceBefore + LOCK_AMOUNT
      );
    });
  });
});

