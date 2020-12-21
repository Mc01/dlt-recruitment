const { ethers, upgrades } = require("hardhat");

async function main() {
  const CustomToken = await ethers.getContractFactory("CustomToken");
  const instance = await upgrades.deployProxy(CustomToken, []);

  await instance.deployed();
  console.log("CustomToken deployed to:", instance.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
