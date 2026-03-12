// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IDO (Initial DEX Offering) 合约
 * @dev 代币首次 DEX 发售合约
 *
 * 功能说明：
 * - 用户可以用 ETH 参与预售，兑换 OPS 代币
 * - 设置软顶（SOFT_CAP）和硬顶（HARD_CAP）
 * - 达到软顶则IDO成功，参与者可以Claim代币
 * - 未达到软顶则IDO失败，参与者可申请退款
 * - 预售结束后，Owner可以提取ETH和未售出的代币
 *
 * 典型应用场景：
 * - 项目代币公开发行
 * - 社区激励机制
 * - 去中心化融资
 *
 * 安全考虑：
 * - 软顶机制确保项目有最低融资目标
 * - 硬顶防止过度融资
 * - 最小参与金额防止粉尘攻击
 * - deadline机制确保发售有时限
 */
contract IDO {
    // ==================== 核心状态变量 ====================
    /// @dev 发售的代币合约
    IERC20 public opsToken;

    /// @dev 合约所有者
    address public owner;

    // ==================== 常量定义 ====================
    /// @dev 代币价格：1 OPS = 0.0001 ETH（即1 ETH = 10000 OPS）
    uint256 public constant TOKEN_PRICE = 0.0001 ether;

    /// @dev 总发售代币数量：100万 OPS
    uint256 public constant TOTAL_TOKENS = 1_000_000 * 1e18;

    /// @dev 软顶：最低融资目标 100 ETH（低于此金额则IDO失败）
    uint256 public constant SOFT_CAP = 100 ether;

    /// @dev 硬顶：最高融资上限 200 ETH
    uint256 public constant HARD_CAP = 200 ether;

    /// @dev 最小参与金额：0.001 ETH（防止粉尘攻击）
    uint256 public constant MIN_CONTRIBUTION = 0.001 ether;

    // ==================== 可变状态变量 ====================
    /// @dev 已募集的ETH总额
    uint256 public totalRaised;

    /// @dev 已Claim的代币总额
    uint256 public totalClaimed;

    /// @dev 预售截止时间（时间戳）
    uint256 public deadline;

    /// @dev IDO是否已结算（finalized）
    bool public finalized;

    /// @dev IDO是否成功（达到软顶）
    bool public success;

    // ==================== 数据映射 ====================
    /// @dev 用户贡献的ETH数量
    mapping(address => uint256) public contributions;

    /// @dev 用户已Claim的代币数量
    mapping(address => uint256) public claimed;

    // ==================== 事件定义 ====================
    /// @dev 预售事件
    /// @param user 参与用户地址
    /// @param amount 贡献的ETH数量
    event Presaled(address indexed user, uint256 amount);

    /// @dev Claim代币事件
    /// @param user 领取用户地址
    /// @param tokenAmount 领取的代币数量
    event Claimed(address indexed user, uint256 tokenAmount);

    /// @dev 退款事件
    /// @param user 退款用户地址
    /// @param amount 退款ETH数量
    event Refunded(address indexed user, uint256 amount);

    /// @dev 结算事件
    /// @param success IDO是否成功
    event Finalized(bool success);

    // ==================== 修饰符 ====================
    /// @dev 仅所有者修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @dev 截止时间前修饰符
    modifier beforeDeadline() {
        require(block.timestamp < deadline, "IDO ended");
        _;
    }

    /// @dev 截止时间后修饰符
    modifier afterDeadline() {
        require(block.timestamp >= deadline, "IDO not ended");
        _;
    }

    // ==================== 构造函数 ====================
    /// @dev 构造函数
    /// @param _opsToken 发售的代币合约地址
    /// @param _duration 预售持续时间（秒）
    constructor(address _opsToken, uint256 _duration) {
        require(_opsToken != address(0), "Invalid token");
        opsToken = IERC20(_opsToken);
        owner = msg.sender;
        deadline = block.timestamp + _duration;
    }

    // ==================== 核心功能函数 ====================

    /// @dev 结算IDO（截止时间后可调用）
    ///
    /// 结算逻辑：
    /// - 检查是否已结算，防止重复结算
    /// - 如果达到软顶则IDO成功，否则失败
    ///
    /// 安全考虑：
    /// - 仅在截止时间后可调用
    /// - 只能结算一次
    function finalize() external afterDeadline {
        require(!finalized, "Already finalized");
        finalized = true;
        if (totalRaised >= SOFT_CAP) {
            success = true;
        } else {
            success = false;
        }
        emit Finalized(success);
    }

    /// @dev 参与者Claim代币（IDO成功时）
    ///
    /// Claim条件：
    /// - IDO已结算
    /// - IDO成功（达到软顶）
    /// - 用户有贡献
    /// - 用户未Claim过
    ///
    /// 计算公式：
    /// - tokenAmount = userContributionETH / TOKEN_PRICE
    /// - 例如：0.1 ETH = 0.1 / 0.0001 = 1000 OPS
    function claim() external {
        require(finalized, "Not finalized");
        require(success, "IDO failed");

        uint256 userContribution = contributions[msg.sender];
        require(userContribution > 0, "No contribution");
        require(claimed[msg.sender] == 0, "Already claimed");

        // 计算可Claim的代币数量：ETH数量 / 单价
        uint256 tokenAmount = userContribution * 1e18 / TOKEN_PRICE;
        require(tokenAmount > 0, "No tokens to claim");

        // 更新状态
        claimed[msg.sender] = tokenAmount;
        totalClaimed += tokenAmount;

        // 转移代币
        require(opsToken.transfer(msg.sender, tokenAmount), "Token transfer failed");
        emit Claimed(msg.sender, tokenAmount);
    }

    /// @dev 退款（IDO失败时）
    ///
    /// 退款条件：
    /// - IDO已结算
    /// - IDO失败（未达到软顶）
    /// - 用户有贡献
    ///
    /// 安全注意：
    /// - 先清零contributions，防止重复退款
    /// - 再执行ETH转账
    function refund() external {
        require(finalized, "Not finalized");
        require(!success, "IDO succeeded");

        uint256 userContribution = contributions[msg.sender];
        require(userContribution > 0, "No contribution");

        // 先清零，防止重入攻击
        contributions[msg.sender] = 0;

        // 退还ETH
        (bool sent,) = msg.sender.call{value: userContribution}("");
        require(sent, "Refund failed");
        emit Refunded(msg.sender, userContribution);
    }

    /// @dev Owner提取募集的ETH（仅IDO成功时）
    ///
    /// 条件：
    /// - IDO已结算
    /// - IDO成功
    ///
    /// 安全注意：
    /// - 仅owner可调用
    /// - 需IDO成功才能提取
    function withdrawETH() external onlyOwner {
        require(finalized && success, "Not allowed");
        (bool sent,) = owner.call{value: address(this).balance}("");
        require(sent, "Withdraw failed");
    }

    /// @dev Owner回收未售出的代币
    ///
    /// 条件：
    /// - IDO已结算
    ///
    /// 计算公式：
    /// - unsold = TOTAL_TOKENS - (totalRaised / TOKEN_PRICE)
    function withdrawUnsoldTokens() external onlyOwner {
        require(finalized, "Not finalized");

        // 计算已售出代币数量
        uint256 sold = totalRaised * 1e18 / TOKEN_PRICE;
        // 计算未售出代币数量
        uint256 unsold = TOTAL_TOKENS - sold;

        if (unsold > 0) {
            require(opsToken.transfer(owner, unsold), "Token transfer failed");
        }
    }

    /// @dev 预售函数（显式调用）
    /// @dev 用户参与预售的显式函数调用方式
    function presale() external payable beforeDeadline {
        // 验证最小参与金额
        require(msg.value >= MIN_CONTRIBUTION, "Below min contribution");
        // 验证未超过硬顶
        require(totalRaised + msg.value <= HARD_CAP, "Exceeds hard cap");

        // 记录贡献
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Presaled(msg.sender, msg.value);
    }

    /// @dev 接收ETH（隐式调用）
    /// @dev 直接向合约转账ETH时自动触发
    ///
    /// 注意：此函数与presale()逻辑重复，存在代码冗余
    /// 建议：可合并为一个内部函数减少重复代码
    receive() external payable {
        require(msg.value >= MIN_CONTRIBUTION, "Below min contribution");
        require(block.timestamp < deadline, "IDO ended");
        require(totalRaised + msg.value <= HARD_CAP, "Exceeds hard cap");
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit Presaled(msg.sender, msg.value);
    }
}