// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Ticket smart contract
/// @author Naman Bhardwaj (naman312010@gmail.com)
/// @notice This smart contract is a simple demonstration of NFT tickets, with royalty support and ticket resale support

contract Ticket is ERC721Royalty {
    ERC20 public token;
    address public owner;
    uint256 public ticketCap = 1000;
    uint256 public currentTickets = 0;
    uint256 public pricePerTicket;

    event TicketPurchased(uint256 indexed ticketId);

    /// @param name NFT ticket collection name
    /// @param symbol NFT ticket collection symbol
    /// @param _tokenAddress Address to the ERC20 to be used for ticket trading
    /// @param _pricePerTicket Price per ticket in above stated ERC20 currency (in wei)
    /// @param _owner NFT ticket distributor (recipient of secondary sale royalty)
    /// @param royaltyNumerator numerator for royalty fractiion, out of 10000 i.e., setting 1000 implies 10% royalty on secondary sales
    constructor(
        string memory name,
        string memory symbol,
        address _tokenAddress,
        uint256 _pricePerTicket,
        address _owner,
        uint96 royaltyNumerator
    ) ERC721(name, symbol) {
        owner = _owner;
        _setDefaultRoyalty(_owner, royaltyNumerator); //1% royalty to owner, on supported
        token = ERC20(_tokenAddress);
        pricePerTicket = _pricePerTicket;
    }

    /// @notice THis functions lets a user purchase a fresh NFT ticket for the set price using the defined token
    /// @dev The purchaser needs to give allowance to this smart contract equal to or greater than price for being able to purchase
    function buyFreshTicket() external {
        require(
            token.allowance(msg.sender, address(this)) >= pricePerTicket,
            "Insufficient token allowance granted to contract"
        );
        require(currentTickets + 1 <= 1000, "Maximum tickets minted");
        currentTickets++;
        token.transferFrom(msg.sender, owner, pricePerTicket);
        _mint(msg.sender, currentTickets);
        emit TicketPurchased(currentTickets);
    }

}
