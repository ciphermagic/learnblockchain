// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenBank
 * @notice ERC20代币银行合约，用户可以存入和提取ERC20代币
 * @dev 核心功能：
 *      1. 存入代币：用户需要先approve，然后调用deposit()
 *      2. 提取代币：用户可以提取自己存入的代币
 *      3. 查询余额：查询用户在银行中的存款余额
 *
 *      安全机制：
 *      - 使用mapping记录每个用户的存款，隔离用户资金
 *      - 提取时先减少记录再转账，防止重入攻击
 *      - 使用totalDeposits跟踪总存款量，便于审计
 *
 *      注意事项：
 *      - depositEth()函数存在硬编码地址，仅用于演示，生产环境应删除
 *      - 用户需要先调用token.approve(tokenBank地址, 金额)才能存款
 */
contract TokenBank {
    /// @notice 代币合约接口
    IERC20 public token;

    /// @notice 记录每个地址的存款数量
    mapping(address => uint256) public deposits;

    /// @notice 记录总存款数量，用于统计和审计
    uint256 public totalDeposits;

    /// @notice 存款事件
    event Deposit(address indexed user, uint256 amount);

    /// @notice 取款事件
    event Withdraw(address indexed user, uint256 amount);

    /**
     * @notice 构造函数，设置代币合约地址
     * @param _token ERC20代币合约地址
     */
    constructor(address _token)  {
        token = IERC20(_token);
    }

    /**
     * @notice 存入ETH并转给指定地址（仅用于演示）
     * @param amount 转账金额
     * @dev ⚠️ 警告：此函数硬编码了接收地址，仅用于测试演示
     *      生产环境应删除此函数或改为可配置的地址
     */
    function depositEth(uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than 0");
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        payable(alice).transfer(amount);
        emit Deposit(alice, amount);
    }

    /**
     * @notice 存入代币
     * @param amount 存入数量
     * @dev 执行流程：
     *      1. 检查金额 > 0
     *      2. 使用transferFrom从用户转移代币到合约
     *      3. 更新用户的存款记录和总存款量
     *      4. 触发Deposit事件
     *
     *      前置条件：
     *      - 用户必须先调用token.approve(address(this), amount)授权
     *      - 用户的代币余额 >= amount
     *
     *      安全考虑：
     *      - 使用require检查transferFrom返回值，确保转账成功
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // 将代币从用户转移到合约
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // 更新存款记录
        deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice 提取代币
     * @param amount 提取数量
     * @dev 执行流程：
     *      1. 检查金额 > 0
     *      2. 检查用户存款余额充足
     *      3. 先更新存款记录（防止重入攻击）
     *      4. 将代币转回给用户
     *      5. 触发Withdraw事件
     *
     *      安全机制：
     *      - 先减少记录再转账（Checks-Effects-Interactions模式）
     *      - 防止重入攻击
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        // 先更新存款记录，防止重入攻击
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        // 将代币转回给用户
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice 查询用户的存款余额
     * @param user 用户地址
     * @return 存款余额
     */
    function balanceOf(address user) external view returns (uint256) {
        return deposits[user];
    }
}