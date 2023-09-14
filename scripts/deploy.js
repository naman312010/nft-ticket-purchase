// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  
  const tokenName = "Simple Token";
  const tokenSymbol = "SIMP";

  const ticketName = "Tickets";
  const ticketSymbol = "TKT";

  const pricePerTicket = hre.ethers.formatUnits("1", "ether");
  const royaltyNumerator = 1000;

  // Contracts are deployed using the first signer/account by default
  const [owner] = await hre.ethers.getSigners();

  const Coin = await hre.ethers.getContractFactory("Coin");
  const coin = await Coin.deployContract(tokenName, tokenSymbol); // owner gets 50000 SIMP
  await coin.waitForDeployment();
  console.log("coin deployed at:", coin.address);

  const Ticket = await hre.ethers.getContractFactory("Ticket");
  const ticket = await Ticket.deploy(ticketName,
    ticketSymbol,
    coin.address,
    pricePerTicket,
    owner,
    royaltyNumerator);
  await ticket.waitForDeployment();
  console.log("NFT Ticket contract deployed at:", ticket.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
