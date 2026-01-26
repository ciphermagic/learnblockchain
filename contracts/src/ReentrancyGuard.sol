// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev 重入攻击防护修饰器对比
 *
 * 1. noReentrancy (传统状态变量方式)
 *    - 使用永久 storage 变量 locked (uint private)
 *    - gas 消耗高：每次加/解锁需 SSTORE (~20k gas 首次，5k 后续)
 *    - 必须显式写 locked = 0，否则合约永久锁死
 *    - 兼容所有网络和旧版 Solidity
 *    - 适合对 gas 不敏感、追求最大兼容性的场景
 *
 * 2. nonreentrant (现代瞬态存储方式 - 推荐)
 *    - 使用 transient storage (TLOAD/TSTORE)，仅在当前交易内有效
 *    - gas 极低：每次 ~100 gas
 *    - 交易结束自动清空，无需担心永久锁死
 *    - 显式 tstore(0,0) 解锁是最佳实践（提高可读性与安全性）
 *    - 组合性更好：同一交易内可多次调用合约而无冲突
 *    - 要求：Solidity >= 0.8.24 + Cancun 升级后网络 (2024年3月已上线主流链)
 *
 * 结论：
 *   - 新项目、gas 敏感、高频调用、复杂组合场景 → 强烈推荐使用 nonreentrant
 *   - 需兼容旧网络或极简审计 → 可继续使用 noReentrancy
 *   - 两者防护效果相同，区别主要在 gas、组合性和维护成本
 */
contract Bank {
    mapping(address => uint) public deposits;
    uint private _locked;

    function locked() public view returns (uint) {
        return _locked;
    }

    function deposit() public payable {
        deposits[msg.sender] += msg.value;
    }

    function withdraw() public {
        (bool success,) = msg.sender.call{value: deposits[msg.sender]}("");
        deposits[msg.sender] = 0;

        require(success, "Failed to send Ether");
    }

    /**
     * @dev 使用传统状态变量防护的取款函数
     *      - 适用于需要最大兼容性的场景
     */
    function withdrawLegacy() external nonReentrantLegacy {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No balance to withdraw");

        deposits[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @dev 使用现代瞬态存储防护的取款函数（推荐）
     *      - gas 更低，组合性更好，适合新项目
     */
    function withdrawTransient() external nonReentrantTransient {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No balance to withdraw");

        deposits[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    /// @dev 传统重入防护（状态变量版）
    modifier nonReentrantLegacy() {
        require(_locked == 0, "No reentrancy");

        _locked = 1;
        _;
        _locked = 0; // 必须显式解锁，否则永久锁死
    }

    /// @dev 现代重入防护（瞬态存储版 - 推荐）
    modifier nonReentrantTransient {
        assembly {
            // 若 slot 0 已锁，则回退
            if tload(0) {revert(0, 0)}
            // 加锁
            tstore(0, 1)
        }
        _;

        // 解锁防护，使模式可组合。
        // 函数退出后，即使在同一交易中也可以再次调用。
        assembly {
            tstore(0, 0)
        }
    }

}