import { ethers } from "hardhat";

async function main() {
  console.log("Deploying Nexus Bridge contracts...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Get account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // Get validator address from environment or use deployer as default
  const validatorAddress = process.env.VALIDATOR_ADDRESS || deployer.address;
  console.log("Validator address:", validatorAddress);

  // Deploy BridgeLock contract
  console.log("\nDeploying BridgeLock contract...");
  const BridgeLock = await ethers.getContractFactory("BridgeLock");
  const bridgeLock = await BridgeLock.deploy(validatorAddress);
  await bridgeLock.waitForDeployment();

  const bridgeLockAddress = await bridgeLock.getAddress();
  console.log("BridgeLock deployed to:", bridgeLockAddress);

  // Optional: Deploy a sample wrapped token for testing
  if (process.env.DEPLOY_SAMPLE_WRAPPED_TOKEN === "true") {
    console.log("\nDeploying sample WrappedSolanaToken...");

    // Sample Solana token mint (replace with actual Solana mint address)
    const sampleSolanaTokenMint = ethers.encodeBytes32String("SAMPLE_SOL_MINT");

    const tx = await bridgeLock.registerWrappedToken(
      sampleSolanaTokenMint,
      "Wrapped Solana USDC",
      "wSOL-USDC",
      6 // USDC has 6 decimals
    );

    const receipt = await tx.wait();
    console.log("Sample wrapped token registered in transaction:", receipt?.hash);
  }

  // Display deployment summary
  console.log("\n========================================");
  console.log("Deployment Summary");
  console.log("========================================");
  console.log("Network:", (await ethers.provider.getNetwork()).name);
  console.log("BridgeLock:", bridgeLockAddress);
  console.log("Validator:", validatorAddress);
  console.log("========================================");

  // Save deployment addresses to a file
  const fs = require("fs");
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    bridgeLock: bridgeLockAddress,
    validator: validatorAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
  };

  fs.writeFileSync(
    "deployment.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\nDeployment info saved to deployment.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
