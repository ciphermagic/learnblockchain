// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ERC20 标准接口 - 包含 balanceOf, transfer, approve, transferFrom, allowance 等函数
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ERC1363 扩展 - 提供 transferAndCall, transferFromAndCall, approveAndCall 等函数
// 这些函数在转账/授权完成后会自动回调接收方合约
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";

/**
 * @title MyERC1363Token - ERC-1363 可支付代币
 * @dev 直接继承 OpenZeppelin 的 ERC1363 实现
 *
 * ERC-1363 是什么？
 * ==============
 * ERC-1363 是 "Payable Token" 标准，扩展了 ERC-20 和 ERC-721
 * 允许代币合约在转账后直接触发接收方的回调函数
 *
 * 主要特点：
 * - 转账后自动执行接收方合约的 onTokenTransfer 回调
 * - 授权后自动执行接收方合约的 onApprovalReceived 回调
 * - 支持 ERC-20 的转账 + 操作一体化
 *
 * 与 ERC-20 的区别：
 * ==================
 * | 功能 | ERC-20 | ERC-1363 |
 * |------|--------|----------|
 * | 转账 | transfer() | transferAndCall() |
 * | 授权转账 | transferFrom() | transferFromAndCall() |
 * | 授权 | approve() | approveAndCall() |
 * | 回调支持 | ❌ | ✅ |
 *
 * 应用场景：
 * - 支付后自动执行智能合约逻辑
 * - 代币化的订阅服务
 * - 去中心化交易所自动化交易
 * - 防止代币被困在合约中（通过回调释放）
 * - 游戏道具购买后自动装备
 *
 * 接口：
 * - IERC1363Receiver: 接收方实现此接口以接收代币
 * - IERC1363Spender: Spender 实现此接口以接收授权通知
 *
 * 注意：
 * - 需要同时实现 ERC20 和 ERC1363
 * - ERC1363 继承自 ERC20
 * - 接收方合约必须实现 IERC1363Receiver 接口
 */
contract MyERC1363Token is ERC1363 {

    // ===== 状态变量 =====

    // 继承自 ERC20 的状态变量：
    // - _balances: mapping(address => uint256) - 用户余额
    // - _allowances: mapping(address => mapping(address => uint256)) - 授权额度
    // - _totalSupply: uint256 - 代币总供应量

    // 继承自 ERC1363 的状态变量：
    // 无新增状态变量，主要通过函数扩展实现功能

    // ===== 构造函数 =====
    /**
     * @dev 构造函数，部署时铸造 100 万代币给部署者
     * @param name 代币名称（如 "MyToken"）
     * @param symbol 代币符号（如 "MYT"）
     *
     * 执行流程：
     * 1. ERC20(name, symbol) - 设置代币名称和符号
     * 2. _mint(msg.sender, amount) - 铸造代币给部署者
     *
     * 铸造数量计算：
     * - decimals() 返回 18（默认值）
     * - 1000000 * 10^18 = 10^24 wei
     *
     * @notice 这是最简单的代币部署方式
     * @notice 部署者获得全部代币，可用于初始流动性分发
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // 初始铸造 100 万代币给部署者
        // decimals() 从 ERC20 继承，默认返回 18
        // 1000000 * 10^18 = 1,000,000,000,000,000,000,000,000 (1e24)
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
