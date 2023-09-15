const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Tickets", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployment() {

    const tokenName = "Simple Token";
    const tokenSymbol = "SIMP";

    const ticketName = "Tickets";
    const ticketSymbol = "TKT";

    const intPricePerTicket = 1;
    const pricePerTicket = ethers.parseUnits(intPricePerTicket.toString(), "ether");
    const royaltyNumerator = 1000;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, anotherAccount] = await ethers.getSigners();

    const coin = await hre.ethers.deployContract("Coin", [tokenName, tokenSymbol]); // owner gets 50000 SIMP
    await coin.waitForDeployment();

    const ticket = await hre.ethers.deployContract("Ticket", [ticketName,
      ticketSymbol,
      coin.target,
      pricePerTicket,
      owner,
      royaltyNumerator]);
    await ticket.waitForDeployment();

    const trader = await hre.ethers.deployContract("Trader", [coin.target, ticket.target, pricePerTicket]); // owner gets 50000 SIMP
    await trader.waitForDeployment();

    return { intPricePerTicket, pricePerTicket, anotherAccount, ticket, trader, coin, owner, otherAccount };
  }

  describe("Deployment", function () {

    it("Owner should have 50k SIMP", async function () {
      const { coin, owner } = await loadFixture(deployment);
      await expect(await coin.balanceOf(owner.address)).to.equal(ethers.parseUnits("50000", "ether"));
    });

  });

  describe("Ticket Trading", async function () {




    it("Should trade successfully", async function () {

      const { intPricePerTicket, anotherAccount, pricePerTicket, ticket, trader, coin, owner, otherAccount } = await loadFixture(deployment);

      const resalePriceMax = ethers.parseUnits((1.1 * intPricePerTicket).toString(), "ether");
      const resalePriceFail = ethers.parseUnits((2 * intPricePerTicket).toString(), "ether");
      const resaleTkID = 1000;
      const resaleTkIDFail = 99;
      const thousandTokens = ethers.parseUnits((1000 * intPricePerTicket).toString(), "ether");

      await coin.connect(owner).transfer(otherAccount.address, thousandTokens);
      await expect(await coin.balanceOf(otherAccount.address)).to.equal(thousandTokens);
      console.log("owner transferred thousand and one SIMP to otherAccount");

      await coin.connect(otherAccount).approve(ticket.target, thousandTokens);
      await expect(await coin.allowance(otherAccount.address, ticket.target)).to.equal(thousandTokens);
      console.log("OtherAccount gave SIMP allowance for 1001 tickets");

      for (i = 1; i <= 1000; i++) {
        await ticket.connect(otherAccount).buyFreshTicket();
      }
      await expect(await ticket.balanceOf(otherAccount.address)).to.equal(1000);
      console.log("OtherAccount purchased 1000 fresh tickets");

      await expect(ticket.connect(otherAccount).buyFreshTicket()).to.be.reverted;
      console.log("OtherAccount attempted to purchase 1001st ticket and failed")

      await coin.connect(owner).transfer(anotherAccount.address, resalePriceMax);
      await expect(await coin.balanceOf(anotherAccount.address)).to.equal(resalePriceMax);
      console.log("Owner sent enough SIMP to anotherAccount for 1 ticket (assuming otherAccount has hiked prices to max)");

      await coin.connect(anotherAccount).approve(trader.target, resalePriceMax);
      await expect(await coin.allowance(anotherAccount.address, trader.target)).to.equal(resalePriceMax);
      console.log("AnotherAccount gave SIMP allowance for 1 ticket to Trader smart contract");

      await ticket.connect(otherAccount).setApprovalForAll(trader.target, true);
      await expect(await ticket.isApprovedForAll(otherAccount.address, trader.target)).to.be.true;
      console.log("otherAccount gave allowance for all tickets");


      let orderid = await ethers.id((await time.latest()).toString() + resaleTkID.toString() + otherAccount.address).toString()
      let msghash = await trader.connect(otherAccount).getMessageHash(orderid, resaleTkID, resalePriceMax);
      let signature = await otherAccount.signMessage(ethers.toBeArray(msghash));
      await trader.connect(anotherAccount).fulfillTicketSale(orderid, resalePriceMax, otherAccount.address, resaleTkID, signature);
      await expect(await ticket.ownerOf(resaleTkID)).to.equal(anotherAccount.address);
      console.log("otherAccount sold 1 ticket to anotherAccount successfully");


      orderid = ethers.id((await time.latest()).toString() + resaleTkIDFail.toString() + otherAccount.address.toString()).toString()
      msghash = await trader.getMessageHash(orderid, resaleTkIDFail, resalePriceFail);
      signature = await otherAccount.signMessage(ethers.toBeArray(msghash));
      await expect(trader.connect(anotherAccount).fulfillTicketSale(orderid, resalePriceFail, otherAccount.address, resaleTkIDFail, signature)).to.be.reverted;
      console.log("otherAccount sold another ticket to anotherAccount unsuccessfully due to price more than 110% than before");

    });

  });
})