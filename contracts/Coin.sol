// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Simple ERC20 token
/// @author Naman Bhardwaj(naman312010@gmail.com)
/// @notice Simple ERC20 smart contractm used as the currency for this ticket trading ecosystem
contract Coin is ERC20 {
    
    constructor(string memory name, string memory symbol) ERC20(name,symbol) {
        _mint(msg.sender, 50000 ether);
    }

}
