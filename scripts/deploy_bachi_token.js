const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const BachiToken = await ethers.getContractFactory("BachiToken");
  const bachiToken = await BachiToken.deploy("BachiToken", "BN");
  await bachiToken.waitForDeployment();
  const tx = await bachiToken.deploymentTransaction();

  console.log("Contract deployed successfully.");
  console.log(`Deployed to: ${bachiToken.target}`);
  console.log(`Transaction hash: ${tx.hash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
