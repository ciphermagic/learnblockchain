// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin 提供的 ERC20 标准实现
// 包含 _mint, _burn, transfer, approve, transferFrom 等核心函数
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title BaseERC20
 * @notice 基础ERC20代币合约，用于测试和演示
 * @dev 继承OpenZeppelin的ERC20标准实现，在部署时一次性铸造100万代币给部署者
 *
 * 核心特性：
 * - 固定总量：100万代币（1,000,000 * 10^18 wei）
 * - 初始分配：全部代币在构造函数中铸造给部署者
 * - 无增发机制：没有额外的mint函数，总量恒定
 *
 * 适用场景：
 * - 测试环境中的模拟代币
 * - 学习ERC20标准的示例代码
 * - 作为其他合约（如TokenBank、NFTMarket）的测试代币
 *
 * 安全考虑：
 * - 构造函数中的铸造是安全的（部署者自己获得代币）
 * - 没有 mint 函数，防止通胀攻击
 * - 继承自 OpenZeppelin，已通过安全审计
 */
contract BaseERC20 is ERC20 {

    // ===== 状态变量 =====

    // 代币名称（如 "Test Token"）
    // 存储在 ERC20 父合约的 slot 0
    // 通过 name() 函数读取

    // 代币符号（如 "TEST"）
    // 存储在 ERC20 父合约的 slot 1
    // 通过 symbol() 函数读取

    // 代币小数位数
    // 标准为 18 位，与 ETH 保持一致
    // 1 代币 = 10^18 最小单位（wei）

    // ===== 构造函数 =====
    /**
     * @notice 构造函数，部署时铸造100万代币给部署者
     * @param name 代币名称（如 "Test Token"）
     * @param symbol 代币符号（如 "TEST"）
     *
     * @dev 执行流程：
     * 1. 调用 ERC20(name, symbol) 设置代币名称和符号
     * 2. 调用 _mint(msg.sender, amount) 铸造代币给部署者
     *
     * 铸造数量计算：
     * - 1000000 (总量) * 10^18 (小数位数) = 10^24 wei
     * - 这是 ERC20 标准的精度表示方式
     *
     * @notice msg.sender 是部署合约的外部账户（EOA）或另一个合约
     * @notice _mint 是内部函数，会更新 totalSupply 和 balances
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // 铸造 100 万代币给部署者
        // _mint 函数：
        // - 增加 totalSupply
        // - 增加 balances[msg.sender]
        // - 触发 Transfer 事件 (address(0), msg.sender, amount)
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

}