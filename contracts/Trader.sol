// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Ticket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Trader smart contract / marketplace smart contract
/// @author Naman Bhardwaj (naman312010@gmail.com)
/// @notice This smart contract lets the ticket owners perform resale of their tickets, supports ERC2981 to credit royalty on secondary sale

contract Trader {
    ERC20 public token;
    Ticket public ticket;
    uint256 public originalTicketPrice;

    mapping(string => order) public pastOrders;
    mapping(uint256 => uint256) public tokenLastPrice;

    struct order {
        string orderID;
        address seller;
        uint256 ticketPrice;
        uint256 ticketId;
    }

    event SaleFulfilled(
        string indexed orderID,
        uint256 indexed price,
        uint256 indexed ticketId
    );

    constructor(
        address _tokenAddress,
        address _ticketAddress,
        uint256 _originalPrice
    ) {
        token = ERC20(_tokenAddress);
        ticket = Ticket(_ticketAddress);
        originalTicketPrice = _originalPrice;
    }

    /// @notice This function fulfills sale
    /// @param orderId orderID from database, generated with timestamp, tokenid and seller
    /// @param price price from database, entered by seller
    /// @param seller seller address
    /// @param ticketId token id, entered by seller
    /// @param signature generated signature by the seller
    /// @dev Need to generate messageHash, then get signed message (signature) then pass to this function for verification
    /// @dev Validates signature with sale information to fulfill sale
    function fulfillTicketSale(
        string memory orderId,
        uint256 price,
        address seller,
        uint256 ticketId,
        bytes memory signature
    ) external {
        require(
            verify(seller, orderId, ticketId, price, signature),
            "Signature not verified"
        );
        require(seller != address(0), "Seller cannot be 0 address");
        require(pastOrders[orderId].ticketPrice == 0, "order already closed");
        require(
            ticket.ownerOf(ticketId) != msg.sender,
            "Owner of ticket cannot purchase it"
        );
        require(
            ticket.ownerOf(ticketId) == seller,
            "Seller not owner of ticket"
        );
        if (tokenLastPrice[ticketId] != 0) {
            require(
                price <= ((tokenLastPrice[ticketId] * 110) / 100),
                "Price cannot be more than 110% of the previous price"
            );
        } else {
            require(
                price <= ((originalTicketPrice * 110) / 100),
                "Price cannot be more than 110% of the previous price"
            );
        }
        require(
            ticket.isApprovedForAll(seller, address(this)),
            "Owner of the ticket needs to have approved this smart contract"
        );
        require(price > 0, "Price cannot be 0");
        require(
            token.allowance(msg.sender, address(this)) >= price,
            "Insufficient allowance"
        );
        //record order for reference
        pastOrders[orderId] = order(orderId, seller, price, ticketId);
        //check royalty details
        address organizer;
        uint256 organizerShare;
        (organizer, organizerShare) = ticket.royaltyInfo(ticketId, price);
        if (seller != organizer) {
            //in case of the seller not being the organizer, this will be considered a secondary sale and royalty is owed to organizer
            token.transferFrom(msg.sender, organizer, organizerShare);
            token.transferFrom(
                msg.sender,
                pastOrders[orderId].seller,
                pastOrders[orderId].ticketPrice - organizerShare
            );
        } else
            // in case seller is the organizer, we need not credit the royalty separately. all proceeds to seller/organizer
            token.transferFrom(
                msg.sender,
                pastOrders[orderId].seller,
                pastOrders[orderId].ticketPrice
            );
        ticket.safeTransferFrom(
            pastOrders[orderId].seller,
            msg.sender,
            pastOrders[orderId].ticketId
        );
        tokenLastPrice[ticketId] = price;
        emit SaleFulfilled(
            orderId,
            pastOrders[orderId].ticketPrice,
            pastOrders[orderId].ticketId
        );
    }

    /// @notice Generates message hash to be signed by seller
    /// @param orderID orderID from database, generated with timestamp, tokenid and seller
    /// @param tokenId token id, desired to be sold by seller
    /// @param price price from database, entered by seller
    function getMessageHash(
        string memory orderID,
        uint256 tokenId,
        uint256 price
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderID, tokenId, price));
    }

    /// @notice Gives signed message structure
    /// @param _messageHash Message hash of order details
    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    /// @notice Verifies given signature against necessary order information and intended signer
    /// @param _signer intended signer for the signature passed
    /// @param orderID orderID from database, generated with timestamp, tokenid and seller
    /// @param tokenId token id, desired to be sold by seller
    /// @param price price from database, entered by seller
    /// @param signature signed message hash
    function verify(
        address _signer,
        string memory orderID,
        uint256 tokenId,
        uint256 price,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(orderID, tokenId, price);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    ///SIGNATURE OPERATIONS BELOW

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}
