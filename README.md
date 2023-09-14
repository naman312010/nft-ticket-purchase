# NFT Ticket Purchase and Resale
This project demonstrates a basic use case for NFT tickets (ERC721 based), which are purchasable by a pre-deployed ERC20 token.
For deployment, please make appropriate changes to scripts/deploy.js and add desired network's details to hardhat.config.js and account private key/required API keys (preferably to a .env file).
Refer to : [Hardhat Documentation](https://hardhat.org/hardhat-runner/docs/config) for further information on deployment.

## Commands
```shell
#to run test scripts
npx hardhat test

#to run test scripts with gas fee report
REPORT_GAS=true npx hardhat test

#to deploy
npx hardhat run --network <your-network> scripts/deploy.js
```
## Added Functions to ERC721 ticket smart contract:

1. buyFreshTicket(): Lets you purchase NFT ticket against the token and token price fixed at deployment. 
   - The buyer must call approve(address spender, uint256 amount) before purchasing transaction in the coin smart contract and approve atleast 'fixed price' amount of their own tokens to the ticket smart contract
   - After approval, they can do a separate transaction and purchase the NFT ticket for the fixed price
2. fulfillTicketSale(string memory orderId, uint256 price, address seller, uint256 ticketId, bytes memory signature): Lets a user purchase ticket via secondary sale, and defined royalty goes to Ticket Smart Contract owner. The way it works is as follows:
   - Sale details are taken from a ticket owner and stored in case for a proper marketplace
   - orderid is to be unique. Easy generation could be `ethers.utils.keccak256(timestamp + tokenId + seller)`
   - Message hash is generated using function getMessageHash and signed with ethersjs by the seller
   - This signature is used by the buyer when purchasing via secondary sale
   - This method lets a seller not make a transaction at the time of selling an NFT ticket
   - Before this function is called, the buyer must have called approve(address spender, uint256 amount) before purchasing transaction in the coin smart contract and approve atleast 'price' amount of their own tokens to the ticket smart contract
   - Also, before this function is called, the seller must have either called approve(address to, uint256 tokenId) or setApprovalForAll(address operator, bool approved) and approved the NFT ticket smart contract to handle their TIcket(s) on the seller's behalf.
   - Upon all conditions being met, buyer gets the NFT Ticket from the seller.