const { expect } = require("chai");

describe("CustomToken", function() {
  it("Should return the new greeting once it's changed", async function() {
    const CustomToken = await ethers.getContractFactory("CustomToken");
    const instance = await upgrades.deployProxy(CustomToken, []);
    
    await instance.deployed();
    // expect(await customToken.test()).to.equal("Hello, world!");
  });
});
