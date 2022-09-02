// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BingoToken is ERC20, Ownable {
    uint256 public constant maxSupply = type(uint64).max;
    uint256 public supply;

    constructor() ERC20("BingoToken", "BTK") {}

    function mint(address to, uint256 amount) public onlyOwner {
        require(supply + amount <= maxSupply, "Token supply is exhausted");
        supply += amount;
        _mint(to, amount);
    }
}
