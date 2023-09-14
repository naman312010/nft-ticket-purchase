const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ticket", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployment() {

    const tokenName = "Simple Token";
    const tokenSymbol = "SIMP";

    const ticketName = "Tickets";
    const ticketSymbol = "TKT";

    const intPricePerTicket = 1;
    const pricePerTicket = ethers.formatUnits(intPricePerTicket, "ether");
    const royaltyNumerator = 1000;
    const royaltyDenominator = 10000;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, anotherAccount] = await ethers.getSigners();

    const Coin = await ethers.getContractFactory("Coin");
    const coin = await Coin.deploy(tokenName, tokenSymbol); // owner gets 50000 SIMP
    await coin.getDeployedCode;

    const Ticket = await ethers.getContractFactory("Ticket");
    const ticket = await Ticket.deploy(ticketName,
      ticketSymbol,
      coin.getAddress,
      pricePerTicket,
      owner,
      royaltyNumerator);
    await ticket.getDeployedCode;

    console.log(intPricePerTicket, pricePerTicket, anotherAccount, ticket, coin, owner, otherAccount);

    return { intPricePerTicket, pricePerTicket, anotherAccount, ticket, coin, owner, otherAccount };
  }

  describe("Deployment", async function () {
    const { coin, owner } = await loadFixture(deployment);
    it("Owner hould have 50k SIMP", async function () {
      await expect(coin.balanceOf(owner.address)).to.equal(ethers.formatUnits("50000", "ether"));
    });

  });

  describe("Ticket Trading", async function () {
    const { intPricePerTicket, anotherAccount, pricePerTicket, ticket, coin, owner, otherAccount } = await loadFixture(deployment);
    const resalePriceMax = ethers.formatUnits(1.1 * intPricePerTicket, "ether");
    const resalePriceFail = ethers.formatUnits(2 * intPricePerTicket, "ether");
    const resaleTkID = 1000;
    const resaleTkIDFail = 99;

    describe("Preparation to trade", function () {
      it("Owner should send enough SIMP to otherAccount for a 1000 tickets", async function () {

        await coin.connect(owner).transfer(otherAccount.address, ethers.formatUnits(1000 * intPricePerTicket, "ether"));
        await expect(coin.balanceOf(otherAccount.address)).to.equal(ethers.formatUnits(1000 * intPricePerTicket, "ether"));
      });

      it("OtherAccount should give SIMP allowance for 1000 tickets", async function () {
        await coin.connect(otherAccount).approve(ticket.getAddress, ethers.formatUnits(1000 * intPricePerTicket, "ether"));
        await expect(coin.allowance(otherAccount.address, ticket.getAddress)).to.equal(ethers.formatUnits(1000 * intPricePerTicket, "ether"));
      });

      it("OtherAccount should purchase 1000 fresh tickets", async function () {
        for (i = 1; i <= 1000; i++) {
          await ticket.connect(otherAccount).buyFreshTicket();
        }

        await expect(ticket.balanceOf(otherAccount.address)).to.equal(1000);
      });

      it("Owner should send enough SIMP to anotherAccount for 1 ticket", async function() {
        await coin.connect(owner).transfer(anotherAccount.address, pricePerTicket);
        await expect(coin.balanceOf(anotherAccount.address)).to.equal(pricePerTicket);
      });

      it("AnotherAccount should give SIMP allowance for 1 tickets", async function () {
        await coin.connect(anotherAccount).approve(ticket.getAddress, pricePerTicket);
        await expect(coin.allowance(anotherAccount.address, ticket.getAddress)).to.equal(pricePerTicket);
      });

      it("otherAccount should give allowance for all tickets", async function () {
        await ticket.connect(otherAccount).setApprovalForAll(ticket.getAddress, true);
        await expect(ticket.isApprovedForAll(otherAccount.address, ticket.getAddress)).to.be.true;
      });

      it("otherAccount sell 1 ticket to anotherAccount successfully", async function () {
        let orderid = ethers.keccak256((await time.latest()).toString + resaleTkID.toString + otherAccount.address.toString).toString
        const msghash = await ticket.getMessageHash(orderid, resaleTkID, resalePriceMax);
        const signature = await otherAccount.signMessage(msghash);
        
        await ticket.connect(anotherAccount).fulfillTicketSale(orderid, resalePriceMax, otherAccount.address, resaleTkID, signature);
        await expect(ticket.ownerOf(resaleTkID)).to.equal(anotherAccount.address);
      });

      it("otherAccount sell another ticket to anotherAccount unsuccessfully due to price more than 110% than before", async function () {
        let orderid = ethers.keccak256((await time.latest()).toString + resaleTkIDFail.toString + otherAccount.address.toString).toString
        const msghash = await ticket.getMessageHash(orderid, resaleTkIDFail, resalePriceFail);
        const signature = await otherAccount.signMessage(msghash);
        
        await expect(ticket.connect(anotherAccount).fulfillTicketSale(orderid, resalePriceFail, otherAccount.address, resaleTkIDFail, signature)).to.be.reverted;
      });

    });
  });
})