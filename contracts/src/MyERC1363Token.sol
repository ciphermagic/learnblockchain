// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";

/**
 * @title MyERC1363Token
 * @dev 直接继承OpenZeppelin的ERC1363实现
 */
contract MyERC1363Token is ERC1363 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // 初始铸造一些代币给部署者
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}