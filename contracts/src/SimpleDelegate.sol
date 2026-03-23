// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleDelegate
 * @notice EIP-7702 代理执行合约
 * @dev 部署后作为 EOA 的委托代码使用
 *      EOA 通过 EIP-7702 授权后，可以调用此合约的函数
 */
contract SimpleDelegate {
  // ==================== 结构体 ====================

  /**
   * @notice 批量调用的单个调用结构
   * @param data  调用数据（函数选择器 + 参数）
   * @param to    目标合约地址
   * @param value 发送的 ETH 数量
   */
  struct Call {
    bytes data;
    address to;
    uint256 value;
  }

  // ==================== 事件 ====================

  /// @notice 每次 execute 中的单笔调用成功后触发
  event Executed(address indexed to, uint256 value, bytes data);

  /// @notice 通用日志事件
  event Log(string message);

  // ==================== 接收 ETH ====================

  /// @notice 允许合约直接接收 ETH
  receive() external payable {}

  // ==================== 初始化 ====================

  /**
   * @notice 初始化函数（EIP-7702 授权后调用）
   * @dev payable：允许在初始化时发送 ETH
   *      通常在首次授权时调用，做一些初始化设置
   *      例如：设置 owner、记录初始状态等
   */
  function initialize() external payable {
    emit Log('initialized');
  }

  // ==================== 核心功能 ====================

  /**
   * @notice 批量执行多个合约调用
   * @dev EIP-7702 的核心功能
   *      EOA 获得授权后，可以通过此函数在单笔交易中执行多个操作
   *      例如：approve + deposit 一步完成
   * @param calls 要执行的调用数组
   */
  function execute(Call[] calldata calls) external payable {
    for (uint256 i = 0; i < calls.length; i++) {
      Call calldata call = calls[i];

      (bool success, ) = call.to.call{ value: call.value }(call.data);
      require(success, 'call failed');

      emit Executed(call.to, call.value, call.data);
    }
  }

  /**
   * @notice 封装好的 approve + deposit 一键调用
   * @dev 便捷函数，内部构造 calls 数组后调用 execute
   *      相当于：先 approve，再 deposit
   * @param token     ERC20 代币合约地址
   * @param tokenbank TokenBank 合约地址
   * @param amount    操作金额
   */
  function approveAndDeposit(address token, address tokenbank, uint256 amount) external {
    // approve calldata: token.approve(tokenbank, amount)
    bytes memory approveData = abi.encodeWithSignature('approve(address,uint256)', tokenbank, amount);

    // deposit calldata: tokenbank.deposit(amount)
    bytes memory depositData = abi.encodeWithSignature('deposit(uint256)', amount);

    Call[] memory calls = new Call[](2);
    calls[0] = Call({ data: approveData, to: token, value: 0 });
    calls[1] = Call({ data: depositData, to: tokenbank, value: 0 });

    for (uint256 i = 0; i < calls.length; i++) {
      (bool success, ) = calls[i].to.call{ value: calls[i].value }(calls[i].data);
      require(success, 'call failed');

      emit Executed(calls[i].to, calls[i].value, calls[i].data);
    }
  }

  /**
   * @notice 测试函数，确认合约代码已挂载到 EOA
   * @dev 触发 Log 事件，可在链上验证 EOA 已获得合约能力
   */
  function ping() external {
    emit Log('pong');
  }
}
