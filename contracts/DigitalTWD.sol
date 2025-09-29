// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DigitalTWD is ERC20, Ownable {
    constructor() ERC20("Digital New Taiwan Dollar", "TWD") Ownable(msg.sender) {
        // 初始發行一些數位新台幣給部署者，以便測試
        _mint(msg.sender, 1000000 * (10**decimals()));
    }

    // 允許合約擁有者增發貨幣
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}