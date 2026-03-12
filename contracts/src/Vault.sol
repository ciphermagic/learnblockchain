// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Vault 合约
 * @dev 这是一个包含代理模式（delegatecall）安全漏洞的演示合约
 *
 * 合约说明：
 * - VaultLogic: 逻辑合约，存储owner和password，通过delegatecall被Vault代理执行
 * - Vault: 代理合约，使用delegatecall调用VaultLogic，实现代理模式
 *
 * 安全漏洞说明：
 * 1. 代理模式漏洞：Vault使用delegatecall代理VaultLogic
 *    - delegatecall会使用调用者的存储上下文执行逻辑合约代码
 *    - VaultLogic中的owner和password变量会写入Vault的存储槽位
 * 2. 访问控制漏洞：openWithdraw()仅检查Vault.owner而非VaultLogic.owner
 * 3. 重入攻击漏洞：withdraw()使用.call()而非safeTransfer，存在重入风险
 *
 * 此合约用于安全审计教学，演示常见的代理模式和访问控制漏洞
 */
/// @title VaultLogic 逻辑合约
/// @dev 通过delegatecall被Vault代理执行
contract VaultLogic {

    /// @dev 合约所有者地址（存储在Vault的storage slot 0）
    address public owner;

    /// @dev 密码（存储在Vault的storage slot 1）
    bytes32 private password;

    /// @dev 构造函数
    /// @param _password 设置的密码
    constructor(bytes32 _password) {
        owner = msg.sender;
        password = _password;
    }

    /// @dev 修改所有者（需要提供正确密码）
    /// @param _password 密码
    /// @param newOwner 新所有者地址
    ///
    /// 安全注意：此函数通过delegatecall在Vault上下文中执行时
    /// 会修改Vault存储中的owner变量，而非VaultLogic中的owner
    function changeOwner(bytes32 _password, address newOwner) public {
        if (password == _password) {
            owner = newOwner;
        } else {
            revert("password error");
        }
    }
}

/// @title Vault 代理合约
/// @dev 使用delegatecall模式调用VaultLogic，存在多个安全漏洞
///
/// 漏洞列表：
/// 1. 存储冲突：Vault的owner和VaultLogic的owner使用相同存储槽位
/// 2. 访问控制绕过：通过Vault调用changeOwner可修改Vault.owner
/// 3. 重入攻击：withdraw()函数使用低级的.call()存在重入风险
/// 4. 条件检查漏洞：withdraw中deposites[msg.sender] >= 0永远为true
contract Vault {

    /// @dev 合约所有者（存储槽位0）
    address public owner;

    /// @dev VaultLogic逻辑合约实例
    VaultLogic logic;

    /// @dev 用户存款金额映射（存储槽位2）
    mapping(address => uint) deposites;

    /// @dev 是否允许提款（存储槽位3）
    bool public canWithdraw = false;

    /// @dev 构造函数
    /// @param _logicAddress VaultLogic合约部署地址
    ///
    /// 注意：此合约将VaultLogic作为逻辑合约，通过delegatecall执行其代码
    constructor(address _logicAddress) {
        logic = VaultLogic(_logicAddress);
        owner = msg.sender;
    }

    /// @dev 回退函数，将调用代理到VaultLogic执行
    ///
    /// 关键漏洞：使用delegatecall会将VaultLogic的代码在Vault的上下文中执行
    /// 这意味着VaultLogic中的状态变量修改会直接影响Vault的存储
    fallback() external {
        // 使用delegatecall将调用转发到逻辑合约
        (bool result,) = address(logic).delegatecall(msg.data);
        if (result) {
            this;
        }
    }

    /// @dev 接收ETH的回调函数
    /// 允许直接向Vault发送ETH（用于存款）
    receive() external payable {
    }

    /// @dev 存款函数
    /// 用户存入ETH，记录到deposites映射中
    function deposit() public payable {
        deposites[msg.sender] += msg.value;
    }

    /// @dev 检查是否解题成功
    /// @return true表示Vault余额为0（资金已被提取）
    function isSolve() external view returns (bool){
        if (address(this).balance == 0) {
            return true;
        }
        return false;
    }

    /// @dev 开启提款功能
    /// 漏洞：仅检查Vault.owner，未检查是否是VaultLogic.owner
    /// 攻击者可以通过VaultLogic的changeOwner修改Vault.owner后调用此函数
    function openWithdraw() external {
        if (owner == msg.sender) {
            canWithdraw = true;
        } else {
            revert("not owner");
        }
    }

    /// @dev 提款函数
    /// 漏洞1：使用低级.call()而非safeTransfer，存在重入攻击风险
    /// 漏洞2：deposites[msg.sender] >= 0条件永远为true（uint不可能小于0）
    /// 漏洞3：先转账后清零状态变量，违反 Checks-Effects-Interactions 模式
    function withdraw() public {
        // 漏洞：>= 0 检查无意义
        if (canWithdraw && deposites[msg.sender] >= 0) {
            // 漏洞：使用.call()存在重入风险，且先转账后清零
            (bool result,) = msg.sender.call{value: deposites[msg.sender]}("");
            if (result) {
                // 漏洞：状态变量在转账之后才更新
                deposites[msg.sender] = 0;
            }
        }
    }
}