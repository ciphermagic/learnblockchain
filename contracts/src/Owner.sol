// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Owner
 * @dev 简单的所有权管理合约，提供所有权转移功能
 * 注意：此合约包含一些额外的未使用状态变量
 */
contract Owner {
    // 合约所有者地址
    address public owner;


    /**
     * @dev 构造函数，将合约部署者设置为初始所有者
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev 所有权转移事件
     * @param caller 发起所有权转移的调用者地址
     * @param newOwner 新的所有者地址
     */
    event OwnerTransfer(address indexed caller, address indexed newOwner);

    /**
     * @dev 转移合约所有权
     * @param newOwner 新的所有者地址
     * @notice 只有当前所有者才能调用此函数进行所有权转移
     */
    function transferOwnership(address newOwner) public {
        // 检查调用者是否为当前所有者
        require(msg.sender == owner, "Only the owner can transfer ownership");
        // 更新所有者地址
        owner = newOwner;
        // 发出所有权转移事件
        emit OwnerTransfer(msg.sender, newOwner);
    }

    /**
     * @dev 非所有者访问错误
     * @param caller 尝试访问的调用者地址
     */
    error NotOwner(address caller);

    /**
     * @dev 转移合约所有权（使用错误恢复的方式）
     * @param newOwner 新的所有者地址
     * @notice 只有当前所有者才能调用此函数进行所有权转移
     * @dev 此函数使用错误恢复而不是 require 语句来处理访问控制
     */
    function transferOwnership2(address newOwner) public {
        // 检查调用者是否为当前所有者，如果不是则恢复交易并抛出错误
        if (msg.sender != owner) revert NotOwner(msg.sender);
        // 更新所有者地址
        owner = newOwner;
    }
}