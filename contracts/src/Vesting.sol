// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenVesting
 * @dev 代币锁定释放合约（Vesting合约）
 *
 * 功能说明：
 * - 12个月的锁定期（cliff），期间受益人无法提取任何代币
 * - 从第13个月开始，进入24个月线性释放期
 * - 每月释放总量的1/24（总共24个月释放完毕）
 * - 受益人可以调用release()方法提取已解锁的代币
 *
 * 典型应用场景：
 * - 团队代币分配（team allocation）
 * - 投资者代币解锁（investor unlock）
 * - 顾问激励（advisor rewards）
 *
 * 安全考虑：
 * - 使用不可变状态变量（immutable）存储关键参数，防止被篡改
 * - 锁定期设计防止早期大量抛售
 * - 只有受益人本人可以触发释放
 */
contract TokenVesting is Ownable {
    // 使用OpenZeppelin的Math库进行安全算术运算
    using Math for uint256;

    // ==================== 事件定义 ====================
    /// @dev 释放代币事件，通知代币已被提取
    event TokensReleased(uint256 amount);

    /// @dev 存入代币事件，通知代币已锁定到合约
    event TokensDeposited(uint256 amount);

    // ==================== 状态变量（不可变）====================
    /// @dev 锁定的ERC20代币合约地址（不可变）
    IERC20 public immutable token;

    /// @dev 受益人地址，即有资格提取代币的账户（不可变）
    address public immutable beneficiary;

    /// @dev 锁定期开始时间，通常为合约部署时间（不可变）
    uint256 public immutable startTime;

    /// @dev 锁定期时长（cliff duration），此期间内代币完全不可提取
    uint256 public immutable cliffDuration;

    /// @dev 线性释放期时长（vesting duration），锁定期结束后的释放期限
    uint256 public immutable vestingDuration;

    // ==================== 状态变量（可变）====================
    /// @dev 存入合约的总代币数量（存入后不可更改）
    uint256 public totalAmount;

    /// @dev 已释放给受益人的代币数量
    uint256 public releasedAmount;

    // ==================== 常量定义 ====================
    /// @dev 锁定期：365天（12个月）
    uint256 public constant CLIFF_DURATION = 365 days;

    /// @dev 线性释放期：730天（24个月）
    uint256 public constant VESTING_DURATION = 730 days;

    /// @dev 总期限：锁定期 + 线性释放期 = 1095天（36个月）
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION;

    /**
     * @dev 构造函数，初始化Vesting合约
     * @param _token 锁定的ERC20代币合约地址
     * @param _beneficiary 受益人地址，有权提取代币的账户
     *
     * 注意：部署时指定受益人，之后不可更改，确保受益人地址正确
     */
    constructor(
        IERC20 _token,
        address _beneficiary
    ) Ownable(msg.sender) {
        // 安全检查：代币地址不能为零地址
        require(address(_token) != address(0), "Token address cannot be zero");
        // 安全检查：受益人地址不能为零地址
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");

        token = _token;
        beneficiary = _beneficiary;
        startTime = block.timestamp;
        cliffDuration = CLIFF_DURATION;
        vestingDuration = VESTING_DURATION;
    }

    /**
     * @dev 存入代币到Vesting合约（仅Owner可调用）
     * @param amount 存入的代币数量
     *
     * 注意：此方法仅可调用一次，存入后不可追加
     * 安全考虑：使用transferFrom确保代币转移原子性
     */
    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        // 防止重复存入，确保只能存入一次
        require(totalAmount == 0, "Tokens already deposited");

        totalAmount = amount;
        // 使用require确保代币转移成功，否则回滚交易
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        emit TokensDeposited(amount);
    }

    /**
     * @dev 释放已解锁的代币给受益人
     *
     * 释放逻辑：
     * 1. 仅受益人可以触发释放
     * 2. 计算当前可释放的代币数量
     * 3. 更新已释放数量
     * 4. 将代币转给受益人
     *
     * 安全考虑：
     * - 先更新releasedAmount再转币，防止重入攻击
     * - 使用require确保代币转移成功
     */
    function release() external {
        // 仅受益人可以释放代币
        require(msg.sender == beneficiary, "Only beneficiary can release tokens");
        // 确保已有代币存入
        require(totalAmount > 0, "No tokens to release");

        // 计算当前可释放的代币数量
        uint256 releasableAmount = getReleasableAmount();
        require(releasableAmount > 0, "No tokens available for release");

        // 先更新状态变量，防止重入攻击
        releasedAmount += releasableAmount;
        require(
            token.transfer(beneficiary, releasableAmount),
            "Token transfer failed"
        );

        emit TokensReleased(releasableAmount);
    }

    /**
     * @dev 计算当前可释放但尚未提取的代币数量
     * @return 可释放但尚未提取的代币数量
     *
     * 公式：已解锁代币 - 已提取代币 = 可释放代币
     */
    function getReleasableAmount() public view returns (uint256) {
        return getVestedAmount() - releasedAmount;
    }

    /**
     * @dev 计算当前应该释放的总代币数量（包括已释放的）
     * @return 应该释放的总代币数量（包含已释放部分）
     *
     * 释放规则：
     * 1. 锁定期内（< cliffDuration）：返回0
     * 2. 超过总期限（>= TOTAL_DURATION）：返回全部代币
     * 3. 线性释放期内：按时间比例计算
     */
    function getVestedAmount() public view returns (uint256) {
        // 阶段1：锁定期内，未解锁任何代币
        if (block.timestamp < startTime + cliffDuration) {
            return 0;
        }
        // 阶段2：已超过总期限，全部代币解锁
        else if (block.timestamp >= startTime + TOTAL_DURATION) {
            return totalAmount;
        }
        // 阶段3：线性释放期内，按时间比例计算
        else {
            // 计算从锁定期结束到现在经过的时间
            uint256 timeFromCliff = block.timestamp - (startTime + cliffDuration);
            // 按比例计算应释放代币：(总量 * 已过去时间) / 释放期总时长
            return (totalAmount * timeFromCliff) / vestingDuration;
        }
    }

    /**
     * @dev 获取剩余锁定的代币数量
     * @return 剩余锁定的代币数量（尚未释放的代币）
     */
    function getRemainingAmount() external view returns (uint256) {
        return totalAmount - releasedAmount;
    }

    /**
     * @dev 获取当前时间距离开始时间的天数
     * @return 天数（向下取整）
     */
    function getDaysFromStart() external view returns (uint256) {
        if (block.timestamp <= startTime) {
            return 0;
        }
        return (block.timestamp - startTime) / 1 days;
    }

    /**
     * @dev 获取距离可以开始释放的剩余天数
     * @return 剩余天数，如果已经可以释放则返回0
     */
    function getDaysUntilCliff() external view returns (uint256) {
        uint256 cliffTime = startTime + cliffDuration;
        if (block.timestamp >= cliffTime) {
            return 0;
        }
        return (cliffTime - block.timestamp) / 1 days;
    }

    /**
     * @dev 检查是否已过锁定期
     * @return true表示已过锁定期，可以开始释放
     */
    function isCliffPassed() external view returns (bool) {
        return block.timestamp >= startTime + cliffDuration;
    }

    /**
     * @dev 检查是否完全释放完毕
     * @return true表示所有代币已释放完毕
     */
    function isFullyVested() external view returns (bool) {
        return block.timestamp >= startTime + TOTAL_DURATION;
    }

    /**
     * @dev 获取释放进度百分比
     * @return 进度（基点形式，0-10000，10000=100%）
     *
     * 注意：锁定期内进度为0%，完全释放后为100%
     */
    function getVestingProgress() external view returns (uint256) {
        // 锁定期内，进度为0%
        if (block.timestamp <= startTime + cliffDuration) {
            return 0;
        }
        // 已完全释放，进度为100%
        if (block.timestamp >= startTime + TOTAL_DURATION) {
            return 10000; // 100%
        }

        // 计算线性释放期内的进度
        uint256 timeFromCliff = block.timestamp - (startTime + cliffDuration);
        return (timeFromCliff * 10000) / vestingDuration;
    }
}