// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ReentrancyGuard - 重入攻击防护示例合约
 * @dev 演示两种重入防护方式：传统状态变量 vs 现代瞬态存储
 *
 * ============================================================
 * 重入攻击防护修饰器对比
 * ============================================================
 *
 * 1. nonReentrantLegacy (传统状态变量方式)
 *    - 使用永久 storage 变量 locked (uint private)
 *    - Gas 消耗高：每次加/解锁需 SSTORE (~20k gas 首次，5k 后续)
 *    - 必须显式写 locked = 0，否则合约永久锁死
 *    - 兼容所有网络和旧版 Solidity
 *    - 适合对 Gas 不敏感、追求最大兼容性的场景
 *
 * 2. nonReentrantTransient (现代瞬态存储方式 - 推荐)
 *    - 使用 transient storage (TLOAD/TSTORE)，仅在当前交易内有效
 *    - Gas 极低：每次约 100 gas
 *    - 交易结束自动清空，无需担心永久锁死
 *    - 显式 tstore(0,0) 解锁是最佳实践（提高可读性与安全性）
 *    - 组合性更好：同一交易内可多次调用合约而无冲突
 *    - 要求：Solidity >= 0.8.24 + Cancun 升级后网络 (2024年3月已上线主流链)
 *
 * 结论：
 *   - 新项目、Gas 敏感、高频调用、复杂组合场景 → 强烈推荐使用 nonReentrantTransient
 *   - 需兼容旧网络或极简审计 → 可继续使用 nonReentrantLegacy
 *   - 两者防护效果相同，区别主要在 Gas、组合性和维护成本
 *
 * ============================================================
 * 安全最佳实践
 * ============================================================
 *
 * 重入攻击防御关键点（Checks-Effects-Interactions 模式）：
 * 1. Checks：先检查前置条件（余额 > 0）
 * 2. Effects：先更新内部状态（余额清零）
 * 3. Interactions：最后才进行外部调用（ETH 转账）
 *
 * 注意：本合约中 withdraw() 函数展示了有漏洞的实现
 *      实际生产中应避免这种先转账后清零的模式
 */

// ============================================================
// Bank 合约
// ============================================================

/**
 * @title Bank - 演示重入攻击与防护的银行合约
 * @dev 包含：
 *      - 有漏洞的 withdraw() 函数
 *      - 带传统防护的 withdrawLegacy()
 *      - 带现代防护的 withdrawTransient()
 *
 * 警告：withdraw() 函数存在重入漏洞，仅用于演示
 */
contract Bank {
    // 用户存款余额
    // key: 用户地址，value: 存款金额
    mapping(address => uint) public deposits;

    // 传统重入防护锁（0 = 未锁定，1 = 已锁定）
    uint private _locked;

    /**
     * @notice 获取当前锁定状态
     * @return uint 锁定状态值
     */
    function locked() public view returns (uint) {
        return _locked;
    }

    /**
     * @notice 存款功能
     * @dev 接收 ETH 并增加用户存款余额
     *
     * 注意：Solidity 0.8+ 自动检查 overflow
     */
    function deposit() public payable {
        deposits[msg.sender] += msg.value;
    }

    /**
     * @notice 有漏洞的取款函数（演示用）
     * @dev 此函数存在重入攻击风险
     *
     * 漏洞原因：
     * - 先执行外部调用（call）
     * - 后更新状态（清零余额）
     *
     * 攻击方式：
     * 1. 攻击者部署恶意合约
     * 2. 向 Bank 存款
     * 3. 调用 withdraw()
     * 4. Bank 先转账 ETH 到攻击合约
     * 5. 攻击合约的 fallback 回调再次调用 withdraw()
     * 6. 此时 deposits[msg.sender] 还未清零，可重复取款
     * 7. 重复步骤 4-6 直到 Bank 余额耗尽
     *
     * 正确做法：
     * - 先清零余额：deposits[msg.sender] = 0
     * - 再转账：msg.sender.call{value: amount}("")
     */
    function withdraw() public {
        // 漏洞：先转账，后清零
        (bool success,) = msg.sender.call{value: deposits[msg.sender]}("");
        deposits[msg.sender] = 0;

        require(success, "Failed to send Ether");
    }

    /**
     * @notice 使用传统状态变量防护的取款函数
     * @dev 适用于需要最大兼容性的场景
     *
     * 防护原理：
     * - 进入函数时检查 _locked == 0
     * - 设置 _locked = 1 加锁
     * - 执行函数逻辑
     * - 退出函数时设置 _locked = 0 解锁
     *
     * 注意：如果函数执行过程中 revert，解锁代码不会执行
     *       可能导致合约永久锁死（需人工干预）
     */
    function withdrawLegacy() external nonReentrantLegacy {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No balance to withdraw");

        // 先清零余额（Effect）
        deposits[msg.sender] = 0;

        // 后转账（Interaction）
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice 使用现代瞬态存储防护的取款函数（推荐）
     * @dev Gas 更低，组合性更好，适合新项目
     *
     * 防护原理：
     * - 使用 TLOAD/TSTORE 瞬态存储
     * - 仅在当前交易内有效
     * - 交易结束后自动清除
     *
     * 优点：
     * - Gas 消耗极低（约 100 gas vs 20000 gas）
     * - 同一交易内可多次调用（组合性）
     * - 无需担心永久锁死
     *
     * 注意：
     * - 需要 Solidity >= 0.8.24
     * - 需要目标网络支持 EVM Cancun 升级
     */
    function withdrawTransient() external nonReentrantTransient {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No balance to withdraw");

        // 先清零余额（Effect）
        deposits[msg.sender] = 0;

        // 后转账（Interaction）
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice 获取合约 ETH 余额
     * @return uint 合约余额
     */
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    // ============================================================
    // 重入防护修饰器
    // ============================================================

    /**
     * @dev 传统重入防护修饰器（状态变量版）
     *
     * 原理：
     * - 使用 storage 变量 _locked 作为锁
     * - 进入函数前检查锁状态
     * - 设置锁为 1 防止重入
     * - 函数执行完毕后重置为 0
     *
     * 风险：
     * - 如果函数内部 revert，锁不会被释放
     * - 需要使用 try-catch 或人工干预恢复
     *
     * Gas 消耗：
     * - 首次 SSTORE: ~20000 gas
     * - 后续 SSTORE: ~5000 gas
     */
    modifier nonReentrantLegacy() {
        require(_locked == 0, "ReentrancyGuard: reentrant call");

        _locked = 1;
        _;
        _locked = 0; // 必须显式解锁，否则永久锁死
    }

    /**
     * @dev 现代重入防护修饰器（瞬态存储版 - 推荐）
     *
     * 原理：
     * - 使用 EVM Cancun 新增的 TLOAD/TSTORE 指令
     * - 瞬态存储：仅在当前交易内有效
     * - 交易结束后自动清除（无需手动解锁）
     *
     * 优势：
     * - Gas 极低：约 100 gas vs 20000 gas
     * - 组合性：同一交易内可多次调用
     * - 安全性：交易结束自动清除，无永久锁死风险
     *
     * 要求：
     * - Solidity >= 0.8.24
     * - EVM Cancun 升级（2024年3月）
     *
     * 注意：
     * - 虽然交易结束自动清除，但显式解锁仍是最佳实践
     * - 提高代码可读性和调试便利性
     */
    modifier nonReentrantTransient {
        assembly {
            // 若 slot 0 已锁，则回退（防止重入）
            if tload(0) {revert(0, 0)}
            // 加锁：设置 slot 0 为 1
            tstore(0, 1)
        }
        _;

        // 解锁防护，使模式可组合
        // 函数退出后，即使在同一交易中也可以再次调用
        assembly {
            tstore(0, 0)
        }
    }
}
