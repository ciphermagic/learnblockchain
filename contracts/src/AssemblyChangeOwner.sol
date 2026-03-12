// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title AssemblyChangeOwner - 内联汇编操作存储槽示例
 * @notice 演示如何使用内联汇编直接读写存储槽
 * @dev 本合约展示了两种实现方式：
 *      1. AssemblyChangeOwnerV1 - 普通 Solidity 实现
 *      2. AssemblyChangeOwnerV2 - 使用内联汇编直接操作存储
 *
 * 存储槽布局（Storage Layout）：
 * - slot 0: string name (字符串会使用额外槽存储数据)
 * - slot 1: mapping(address => bool) approved
 * - slot 2: address owner (本合约关注的槽)
 *
 * 重要提示：
 * - 存储槽编号基于变量声明顺序
 * - 字符串和动态数组会占用多个槽
 * - 本示例中 owner 位于 slot 2
 * - 实际项目中应通过实验验证槽位置
 */

// ============================================================
// 版本1：普通 Solidity 实现
// ============================================================

/**
 * @title AssemblyChangeOwnerV1 - 普通实现
 * @dev 使用常规 Solidity 语法操作 owner 变量
 *
 * 特点：
 * - 代码简洁，易于理解和维护
 * - 编译器自动处理存储读写
 * - 安全性由 Solidity 类型系统保障
 */
contract AssemblyChangeOwnerV1 {
    // 合约名称
    string public name;

    // 已批准地址映射（未使用，仅作演示存储布局）
    mapping(address => bool) private approved;

    // 合约所有者地址
    address public owner;

    /**
     * @dev 授权修饰器：仅允许 owner 调用
     */
    modifier auth {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /**
     * @dev 构造函数
     * @param _name 合约名称
     */
    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    }

    /**
     * @notice 转移合约所有权
     * @param _addr 新 owner 地址
     *
     * 安全检查：
     * - 新地址不能是零地址
     * - 新地址不能与当前 owner 相同
     */
    function transferOwernship(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        require(owner != _addr, "New owner is the same as the old owner");
        owner = _addr;
    }
}

// ============================================================
// 版本2：内联汇编实现
// ============================================================

/**
 * @title AssemblyChangeOwnerV2 - 内联汇编实现
 * @dev 使用内联汇编直接操作存储槽
 *
 * 原理：
 * - 使用 assembly { sload(slot) } 读取存储
 * - 使用 assembly { sstore(slot, value) } 写入存储
 * - slot 2 对应 owner 变量的存储位置
 *
 * 优点：
 * - 可精确控制存储操作
 * - 可用于 Gas 优化
 * - 可用于降低合约字节码大小
 *
 * 缺点：
 * - 代码可读性差
 * - 容易出错（槽位置计算错误）
 * - 不易审计和维护
 *
 * 警告：
 * - 本示例仅用于演示，勿用于生产环境
 * - 存储槽位置可能因编译器版本、变量顺序改变
 * - 生产环境应使用成熟的代理模式
 */
contract AssemblyChangeOwnerV2 {
    // 合约名称
    string public name;

    // 已批准地址映射（未使用，仅作演示存储布局）
    mapping(address => bool) private approved;

    // 注意：owner 变量被移除，改用 slot 2 直接操作

    /**
     * @dev 授权修饰器：使用汇编读取 owner
     *
     * 内联汇编说明：
     * - sload(2): 从 slot 2 读取值（owner）
     * - slot 2 存储布局：
     *   - name: slot 0 (字符串额外占用数据槽)
     *   - approved: slot 1 (mapping)
     *   - owner: slot 2 (address)
     */
    modifier auth {
        address currentOwner;
        assembly {
            // 从存储槽 2 读取 owner 地址
            currentOwner := sload(2)
        }
        require(msg.sender == currentOwner, "Not authorized");
        _;
    }

    /**
     * @dev 构造函数
     * @param _name 合约名称
     *
     * 内联汇编说明：
     * - sstore(2, caller()): 将 caller() 写入 slot 2
     * - 设置 msg.sender 为 owner
     */
    constructor(string memory _name) {
        name = _name;
        assembly {
            // 将调用者地址写入存储槽 2（owner 位置）
            sstore(2, caller())
        }
    }

    /**
     * @notice 转移合约所有权
     * @param _addr 新 owner 地址
     *
     * 安全检查：
     * - 新地址不能是零地址
     * - 新地址不能与当前 owner 相同
     *
     * 操作流程：
     * 1. 验证新地址有效性
     * 2. 读取当前 owner
     * 3. 验证新旧地址不同
     * 4. 写入新 owner
     */
    function transferOwnership(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");

        // 使用汇编读取当前 owner
        address currentOwner;
        assembly {
            currentOwner := sload(2)
        }
        require(_addr != currentOwner, "New owner is the same as the old owner");

        // 使用汇编写入新 owner
        assembly {
            sstore(2, _addr)
        }
    }

    /**
     * @notice 获取当前 owner
     * @return ownerAddr 当前 owner 地址
     *
     * 纯汇编读取存储槽
     */
    function getOwner() public view returns (address ownerAddr) {
        assembly {
            ownerAddr := sload(2)
        }
    }
}
