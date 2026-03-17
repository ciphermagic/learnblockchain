// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

/**
 * @title TokenBankPermit
 * @notice 支持EIP-2612 Permit功能的代币银行合约
 * @dev 核心改进：
 *      1. 传统存款：deposit() - 需要用户先approve
 *      2. Permit存款：permitDeposit() - 用户通过链下签名授权，一笔交易完成授权+存款
 *
 *      Permit存款的优势：
 *      - 用户体验：一笔交易完成授权+存款，节省gas和时间
 *      - 无需ETH：用户可以在没有ETH的情况下授权代币（元交易）
 *      - 安全性：使用EIP-712签名，防止重放攻击
 *
 *      工作流程：
 *      1. 用户在链下签名授权消息（包含owner、spender、value、nonce、deadline）
 *      2. 用户调用permitDeposit()，提交签名和存款金额
 *      3. 合约调用token.permit()验证签名并执行授权
 *      4. 合约立即调用transferFrom()转移代币
 *      5. 更新用户的存款记录
 *
 *      适用场景：
 *      - 改善用户体验，减少交易步骤
 *      - 支持元交易（meta-transaction）
 *      - 与支持EIP-2612的代币（如USDC、DAI）配合使用
 */
contract TokenBankPermit {
  /// @notice 代币合约接口
  IERC20 public token;

  /// @notice 记录每个用户存入的代币数量
  mapping(address => uint256) public deposits;

  /// @notice 存款事件
  event Deposit(address indexed user, uint256 amount);

  /// @notice 取款事件
  event Withdraw(address indexed user, uint256 amount);

  /**
   * @notice 构造函数，设置代币合约地址
   * @param _tokenAddress ERC20代币合约地址（必须支持EIP-2612 Permit）
   */
  constructor(address _tokenAddress) {
    require(_tokenAddress != address(0), 'TokenBank: token address cannot be zero');
    token = IERC20(_tokenAddress);
  }

  /**
   * @notice 传统存入代币方式（需要先approve）
   * @param _amount 存入数量
   * @dev 前置条件：用户必须先调用token.approve(address(this), _amount)
   */
  function deposit(uint256 _amount) external {
    require(_amount > 0, 'TokenBank: deposit amount must be greater than zero');
    require(token.balanceOf(msg.sender) >= _amount, 'TokenBank: insufficient token balance');

    bool success = token.transferFrom(msg.sender, address(this), _amount);
    require(success, 'TokenBank: transfer failed');

    deposits[msg.sender] += _amount;

    emit Deposit(msg.sender, _amount);
  }

  /**
   * @notice 使用 EIP-2612 Permit 进行存款（无需提前 approve）
   * @param _amount 存入数量
   * @param deadline 签名过期时间（Unix 时间戳）
   * @param v 签名参数 v
   * @param r 签名参数 r
   * @param s 签名参数 s
   *
   * @dev 工作流程：
   *      1. 用户在链下签名 EIP-2612 Permit 消息
   *         (owner = 用户地址, spender = 本合约地址, value = _amount)
   *      2. 用户调用 permitDeposit() 并提交签名
   *      3. 合约调用 token.permit() 验证签名并设置 allowance
   *      4. 合约调用 transferFrom() 将代币转入本合约
   *      5. 更新用户的存款记录
   *
   * @dev 注意：
   *      当前实现要求 **调用者必须是签名者本人**。
   *      因为 permit() 中的 owner 参数使用的是 msg.sender：
   *
   *          permit(owner = msg.sender, spender = address(this), ...)
   *
   *      因此如果第三方（relayer）尝试提交签名：
   *      - msg.sender ≠ 签名中的 owner
   *      - token.permit() 的签名校验会失败并 revert
   *
   *      也就是说，本函数不支持 meta-transaction 或 gas 代付。
   *
   * @dev 如果需要支持第三方提交交易，应将 owner 作为参数传入：
   *
   *          permit(owner, address(this), ...)
   *
   *      这样 relayer 可以代替用户提交交易，但资金仍然从 owner 扣除。
   */
  function permitDeposit(uint256 _amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(_amount > 0, 'TokenBank: deposit amount must be greater than zero');
    require(token.balanceOf(msg.sender) >= _amount, 'TokenBank: insufficient token balance');

    // 调用token的permit函数进行授权
    IERC20Permit(address(token)).permit(
      msg.sender, // owner（只能用户自己调用，如果希望第三方调用，owner要作为参数传入）
      address(this), // spender
      _amount, // value
      deadline, // deadline
      v,
      r,
      s // 签名
    );

    // 将代币从用户转移到合约
    bool success = token.transferFrom(msg.sender, address(this), _amount);
    require(success, 'TokenBank: transfer failed');

    deposits[msg.sender] += _amount;

    emit Deposit(msg.sender, _amount);
  }

  /**
   * @notice 提取代币
   * @param _amount 提取数量
   * @dev 安全机制：先减少记录再转账，防止重入攻击
   */
  function withdraw(uint256 _amount) external {
    require(_amount > 0, 'TokenBank: withdraw amount must be greater than zero');
    require(deposits[msg.sender] >= _amount, 'TokenBank: insufficient deposit balance');

    // 先减少记录，防止重入攻击
    deposits[msg.sender] -= _amount;

    bool success = token.transfer(msg.sender, _amount);
    require(success, 'TokenBank: transfer failed');

    emit Withdraw(msg.sender, _amount);
  }

  /**
   * @notice 查询用户在银行中的存款余额
   * @param _user 用户地址
   * @return 存款余额
   */
  function balanceOf(address _user) external view returns (uint256) {
    return deposits[_user];
  }
}
