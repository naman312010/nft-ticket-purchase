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

    mapping(string => order) public pastOrders;
    mapping(uint256 => uint256) public tokenLastPrice;

    struct order {
        string orderID;
        address seller;
        uint256 ticketPrice;
        uint256 ticketId;
    }

    event TicketPurchased(uint256 indexed ticketId);
    //Depreciated event, since sale generation need not be a transaction
    // event SaleCreated(string indexed orderID, uint256 indexed price, uint256 indexed ticketId);
    event SaleFulfilled(
        string indexed orderID,
        uint256 indexed price,
        uint256 indexed ticketId
    );

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
        tokenLastPrice[currentTickets] = pricePerTicket;
        emit TicketPurchased(currentTickets);
    }

    /// @notice This function has been depreciated as it is not necessary to make transactions for making a sale
    // function createTicketSale(
    //     string memory orderId,
    //     uint256 price,
    //     uint256 ticketId
    // ) external {
    //     require(order[orderId].orderID == "", "Orderid already exists");
    //     require(
    //         ownerOf(ticketId) == msg.sender,
    //         "Only owner of ticket can sell it"
    //     );
    //     require(
    //         isApprovedForAll(msg.sender, address(this)),
    //         "Owner of the ticket needs to approve this smart contract"
    //     );
    //     require(
    //         price <= tokenLastPrice[ticketId] * 1.1,
    //         "Price cannot be more than 110% of the previous price"
    //     );
    //     require(
    //         price > 0,
    //         "Price cannot be 0"
    //     );
    //     pastOrders[orderId] = order(
    //         orderId,
    //         msg.sender,
    //         true,
    //         price,
    //         ticketId
    //     );
    //     emit SaleCreated(orderId, price, ticketId);
    // }

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
            ownerOf(ticketId) != msg.sender,
            "Owner of ticket cannot purchase it"
        );
        require(ownerOf(ticketId) == seller, "Seller not owner of ticket");
        require(
            price <= ((tokenLastPrice[ticketId] * 110) / 100),
            "Price cannot be more than 110% of the previous price"
        );
        require(
            isApprovedForAll(seller, address(this)),
            "Owner of the ticket needs to have approved this smart contract"
        );
        require(price > 0, "Price cannot be 0");
        require(
            token.allowance(msg.sender, address(this)) >= price,
            "Insufficient allowance"
        );
        pastOrders[orderId] = order(orderId, seller, price, ticketId);
        address distributor;
        uint256 distributorShare;
        (distributor, distributorShare) = royaltyInfo(ticketId, price);
        token.transferFrom(msg.sender, distributor, distributorShare);
        token.transferFrom(
            msg.sender,
            pastOrders[orderId].seller,
            pastOrders[orderId].ticketPrice - distributorShare
        );
        safeTransferFrom(
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
