// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BingoToken is ERC20, Ownable {
    uint256 private constant maxSupply = type(uint64).max;
    uint256 public supply;

    error SupplyExceeded(uint256 requested, uint256 max);
    constructor() ERC20("BingoToken", "BTK") {}

    function mint(address to, uint256 amount) public onlyOwner {
        if(supply + amount > maxSupply) {
            revert SupplyExceeded(supply + amount, maxSupply);
        }
        supply += amount;
        _mint(to, amount);
    }
}
