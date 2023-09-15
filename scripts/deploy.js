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

  const pricePerTicket = hre.ethers.parseUnits("1", "ether");
  const royaltyNumerator = 1000;

  // Contracts are deployed using the first signer/account by default
  const [owner] = await hre.ethers.getSigners();

  const coin = await hre.ethers.deployContract("Coin", [tokenName, tokenSymbol]); // owner gets 50000 SIMP
  await coin.waitForDeployment();
  console.log("Coin deployed at:", coin.target);


  const ticket = await hre.ethers.deployContract("Ticket", [ticketName,
    ticketSymbol,
    coin.target,
    pricePerTicket,
    owner,
    royaltyNumerator]);
  await ticket.waitForDeployment();
  console.log("NFT Ticket contract deployed at:", ticket.target);

  const trader = await hre.ethers.deployContract("Trader", [coin.target, ticket.target, pricePerTicket]); // owner gets 50000 SIMP
  await trader.waitForDeployment();
  console.log("Trader deployed at:", trader.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
