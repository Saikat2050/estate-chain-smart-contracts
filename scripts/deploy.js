require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const chainlinkFeed = process.env.CHAINLINK_FEED;

  if (!chainlinkFeed) {
    throw new Error("Chainlink feed not found");
  }

  const PropertyToken = await hre.ethers.getContractFactory("PropertyToken");
  const contract = await PropertyToken.deploy(chainlinkFeed);

  await contract.deployed();

  console.log(`PropertyToken deployed at: ${contract.address}`);
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exitCode = 1;
});
