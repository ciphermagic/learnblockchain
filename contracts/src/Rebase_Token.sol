// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RebaseToken
 * @dev 通缩型 Rebase Token 实现
 * 起始发行量为 1 亿，每年通缩 1%
 * 参考 Ampleforth 的实现原理
 *
 * 核心机制说明：
 * 1. Gons（内部份额）：用户实际持有的是 gons，这是一个不变的内部单位
 * 2. Fragments（代币数量）：用户看到的代币余额，会随着 rebase 变化
 * 3. _gonsPerFragment：gons 和 fragments 之间的转换比率
 * 4. 通过调整 _gonsPerFragment，实现所有用户余额同步变化
 *
 * 举例说明：
 * - 用户 A 持有 1000 gons
 * - 初始 _gonsPerFragment = 1，则余额显示为 1000 tokens
 * - rebase 后 _gonsPerFragment = 1.01，则余额显示为 990.099 tokens（通缩 1%）
 * - 用户持有的 gons 不变，但显示的 token 数量减少了
 */
contract RebaseToken {
  // ============ 状态变量 ============

  /**
   * @dev 用户的 gons 余额（内部份额）
   * gons 是用户实际持有的不变单位，不会因为 rebase 而改变
   * 用户的代币余额 = _gonBalances[user] / _gonsPerFragment
   */
  mapping(address => uint256) private _gonBalances;

  /**
   * @dev 授权额度映射
   * _allowances[owner][spender] 表示 owner 授权给 spender 的代币数量
   */
  mapping(address => mapping(address => uint256)) private _allowances;

  // ============ 常量定义 ============

  /**
   * @dev uint256 的最大值
   * 用于计算 TOTAL_GONS，确保 gons 总量足够大以支持精确的 rebase 计算
   */
  uint256 private constant MAX_UINT256 = ~uint256(0);

  /**
   * @dev 初始代币总供应量：1 亿枚（带 18 位小数）
   * 这是用户看到的初始代币数量
   */
  uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 100_000_000 * 10 ** 18;

  /**
   * @dev gons 总量（内部份额总量）
   * 计算方式：取 MAX_UINT256 减去余数，确保能被初始供应量整除
   * 这个值在合约生命周期内保持不变，是所有 gons 的总和
   * 通过调整 _gonsPerFragment，可以改变 gons 对应的代币数量
   */
  uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

  // ============ ERC20 基本信息 ============

  string public name = 'Rebase Deflation Token';
  string public symbol = 'RDT';
  uint8 public decimals = 18;

  // ============ 动态状态变量 ============

  /**
   * @dev 当前代币总供应量（用户视角）
   * 初始值为 1 亿，每次 rebase 后会减少 1%
   * 这是用户看到的代币总量，会随着 rebase 变化
   */
  uint256 private _totalSupply;

  /**
   * @dev gons 到 fragments 的转换比率
   * 计算公式：_gonsPerFragment = TOTAL_GONS / _totalSupply
   * 用户余额 = _gonBalances[user] / _gonsPerFragment
   *
   * 每次 rebase 时，_totalSupply 减少，_gonsPerFragment 增加
   * 从而实现所有用户余额同步减少的效果
   */
  uint256 private _gonsPerFragment;

  /**
   * @dev 上次 rebase 的时间戳
   * 用于判断是否可以执行下一次 rebase（需要间隔 365 天）
   */
  uint256 public lastRebaseTime;

  /**
   * @dev rebase 执行次数
   * 每次 rebase 时递增，用于追踪 rebase 历史
   */
  uint256 public rebaseCount;

  /**
   * @dev 合约所有者地址
   * 只有所有者可以执行 rebase 操作
   */
  address public owner;

  // ============ Rebase 参数常量 ============

  /**
   * @dev 通缩率分子：99
   * 每次 rebase 后，新供应量 = 旧供应量 * 99 / 100 = 旧供应量 * 0.99
   * 即每次通缩 1%
   */
  uint256 private constant DEFLATION_RATE = 99;

  /**
   * @dev 通缩率分母：100
   * 与 DEFLATION_RATE 配合使用，实现精确的百分比计算
   */
  uint256 private constant RATE_DENOMINATOR = 100;

  /**
   * @dev rebase 时间间隔：365 天
   * 每年只能执行一次 rebase
   */
  uint256 private constant REBASE_INTERVAL = 365 days;

  // ============ 事件定义 ============

  /**
   * @dev 代币转账事件
   * @param from 发送方地址
   * @param to 接收方地址
   * @param value 转账金额（代币数量，非 gons）
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev 授权事件
   * @param owner 授权方地址
   * @param spender 被授权方地址
   * @param value 授权金额（代币数量，非 gons）
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);

  /**
   * @dev Rebase 事件
   * @param epoch rebase 次数（rebaseCount）
   * @param totalSupply rebase 后的新总供应量
   */
  event Rebase(uint256 indexed epoch, uint256 totalSupply);

  // ============ 修饰器 ============

  /**
   * @dev 仅所有者可调用的修饰器
   * 用于保护 rebase 等关键操作
   */
  modifier onlyOwner() {
    require(msg.sender == owner, 'Not owner');
    _;
  }

  // ============ 构造函数 ============

  /**
   * @dev 构造函数：初始化 Rebase Token
   * 执行步骤：
   * 1. 设置合约所有者为部署者
   * 2. 设置初始总供应量为 1 亿
   * 3. 计算初始 gons 转换比率
   * 4. 记录初始 rebase 时间
   * 5. 将所有 gons 分配给部署者
   * 6. 触发 Transfer 事件（从零地址铸造）
   */
  constructor() {
    owner = msg.sender;
    _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
    _gonsPerFragment = TOTAL_GONS / _totalSupply;
    lastRebaseTime = block.timestamp;
    _gonBalances[msg.sender] = TOTAL_GONS;
    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  // ============ ERC20 标准函数 ============

  /**
   * @dev 查询代币总供应量
   * @return 当前代币总供应量（会随 rebase 变化）
   *
   * 注意：这是用户视角的总供应量，每次 rebase 后会减少 1%
   */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev 查询指定地址的代币余额
   * @param who 要查询的地址
   * @return 该地址的代币余额（用户视角）
   *
   * 计算方式：gons 余额 / gons 转换比率
   * 用户持有的 gons 不变，但随着 _gonsPerFragment 增加，显示的余额会减少
   */
  function balanceOf(address who) public view returns (uint256) {
    return _gonBalances[who] / _gonsPerFragment;
  }

  /**
   * @dev 转账代币
   * @param to 接收方地址
   * @param value 转账金额（代币数量）
   * @return 是否成功
   *
   * 实现原理：
   * 1. 将代币数量转换为 gons 数量
   * 2. 转移 gons（内部份额）
   * 3. 触发 Transfer 事件
   *
   * 安全检查：
   * - 不能转账到零地址
   * - 不能转账到合约自身
   */
  function transfer(address to, uint256 value) public returns (bool) {
    require(to != address(0), 'Transfer to zero address');
    require(to != address(this), 'Transfer to contract');

    uint256 gonValue = value * _gonsPerFragment;
    _gonBalances[msg.sender] -= gonValue;
    _gonBalances[to] += gonValue;
    emit Transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev 查询授权额度
   * @param owner_ 授权方地址
   * @param spender 被授权方地址
   * @return 授权的代币数量
   *
   * 注意：授权额度存储的是代币数量，不是 gons
   * rebase 不会影响授权额度的数值
   */
  function allowance(address owner_, address spender) public view returns (uint256) {
    return _allowances[owner_][spender];
  }

  /**
   * @dev 从授权额度中转账
   * @param from 发送方地址
   * @param to 接收方地址
   * @param value 转账金额（代币数量）
   * @return 是否成功
   *
   * 实现原理：
   * 1. 检查并扣减授权额度
   * 2. 将代币数量转换为 gons 数量
   * 3. 转移 gons（内部份额）
   * 4. 触发 Transfer 事件
   *
   * 安全检查：
   * - 不能转账到零地址
   * - 不能转账到合约自身
   * - 授权额度必须足够（会自动检查，不足会 revert）
   */
  function transferFrom(address from, address to, uint256 value) public returns (bool) {
    require(to != address(0), 'Transfer to zero address');
    require(to != address(this), 'Transfer to contract');

    _allowances[from][msg.sender] -= value;
    uint256 gonValue = value * _gonsPerFragment;
    _gonBalances[from] -= gonValue;
    _gonBalances[to] += gonValue;
    emit Transfer(from, to, value);
    return true;
  }

  /**
   * @dev 授权代币使用权限
   * @param spender 被授权方地址
   * @param value 授权金额（代币数量）
   * @return 是否成功
   *
   * 注意：
   * - 授权额度会被直接设置为 value，而不是增加
   * - 建议先将授权额度设为 0，再设置新值，以避免授权竞态问题
   */
  function approve(address spender, uint256 value) public returns (bool) {
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev 增加授权额度
   * @param spender 被授权方地址
   * @param addedValue 增加的金额
   * @return 是否成功
   *
   * 优势：避免了 approve 的授权竞态问题
   * 新授权额度 = 旧授权额度 + addedValue
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _allowances[msg.sender][spender] += addedValue;
    emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
    return true;
  }

  /**
   * @dev 减少授权额度
   * @param spender 被授权方地址
   * @param subtractedValue 减少的金额
   * @return 是否成功
   *
   * 安全处理：
   * - 如果减少的金额 >= 当前授权额度，则授权额度归零
   * - 否则，授权额度 = 旧授权额度 - subtractedValue
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    uint256 oldValue = _allowances[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      _allowances[msg.sender][spender] = 0;
    } else {
      _allowances[msg.sender][spender] = oldValue - subtractedValue;
    }
    emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
    return true;
  }

  // ============ Rebase 核心功能 ============

  /**
   * @dev 执行定时 rebase（需要满足时间间隔）
   * 只有所有者可以调用
   *
   * 限制条件：
   * - 必须距离上次 rebase 至少 365 天
   * - 只有合约所有者可以调用
   *
   * 执行效果：
   * - 代币总供应量减少 1%
   * - 所有用户的余额同步减少 1%
   * - 更新 rebase 时间戳
   */
  function rebase() external onlyOwner {
    require(block.timestamp >= lastRebaseTime + REBASE_INTERVAL, 'Rebase too early');
    _rebase();
  }

  /**
   * @dev 手动执行 rebase（无时间限制）
   * 只有所有者可以调用
   *
   * 用途：
   * - 测试环境快速 rebase
   * - 紧急情况下的手动调整
   *
   * 注意：生产环境应谨慎使用，建议使用 rebase() 函数
   */
  function manualRebase() external onlyOwner {
    _rebase();
  }

  /**
   * @dev 内部 rebase 实现
   * 核心逻辑：
   * 1. rebase 计数器递增
   * 2. 计算新的总供应量：旧供应量 * 99 / 100（通缩 1%）
   * 3. 更新总供应量
   * 4. 重新计算 gons 转换比率：TOTAL_GONS / 新总供应量
   * 5. 更新 rebase 时间戳
   * 6. 触发 Rebase 事件
   *
   * 关键原理：
   * - TOTAL_GONS（gons 总量）保持不变
   * - _totalSupply（代币总量）减少
   * - _gonsPerFragment（转换比率）增加
   * - 用户的 _gonBalances（gons 余额）不变
   * - 用户的 balanceOf（代币余额）= _gonBalances / _gonsPerFragment，因此减少
   *
   * 举例说明：
   * - rebase 前：_totalSupply = 100M，_gonsPerFragment = X
   * - rebase 后：_totalSupply = 99M，_gonsPerFragment = X * 100/99
   * - 用户 A 的 gons 余额不变，但代币余额从 1000 变为 990
   */
  function _rebase() internal {
    rebaseCount++;
    uint256 newTotalSupply = (_totalSupply * DEFLATION_RATE) / RATE_DENOMINATOR;
    _totalSupply = newTotalSupply;
    _gonsPerFragment = TOTAL_GONS / _totalSupply;
    lastRebaseTime = block.timestamp;
    emit Rebase(rebaseCount, _totalSupply);
  }

  // ============ 辅助查询函数 ============

  /**
   * @dev 查询当前 gons 转换比率
   * @return 当前的 _gonsPerFragment 值
   *
   * 用途：
   * - 调试和监控
   * - 计算 gons 和代币之间的转换
   */
  function gonsPerFragment() external view returns (uint256) {
    return _gonsPerFragment;
  }

  /**
   * @dev 检查当前是否可以执行 rebase
   * @return 如果距离上次 rebase 已满 365 天，返回 true
   *
   * 用途：
   * - 前端显示 rebase 按钮状态
   * - 自动化脚本判断执行时机
   */
  function canRebase() external view returns (bool) {
    return block.timestamp >= lastRebaseTime + REBASE_INTERVAL;
  }

  /**
   * @dev 查询下次可以 rebase 的时间
   * @return 下次 rebase 的时间戳
   *
   * 用途：
   * - 前端显示倒计时
   * - 计划 rebase 执行时间
   */
  function nextRebaseTime() external view returns (uint256) {
    return lastRebaseTime + REBASE_INTERVAL;
  }

  /**
   * @dev 查询指定地址的 gons 余额（内部份额）
   * @param who 要查询的地址
   * @return 该地址的 gons 余额
   *
   * 用途：
   * - 调试和监控
   * - 验证 rebase 机制正确性
   *
   * 注意：
   * - gons 余额在 rebase 前后保持不变
   * - 用户的代币余额 = gons 余额 / _gonsPerFragment
   */
  function gonBalanceOf(address who) external view returns (uint256) {
    return _gonBalances[who];
  }
}
