// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title IBank
 * @notice Bank合约的接口定义
 * @dev 定义了Bank合约的核心外部函数，用于合约间交互
 */
interface IBank {
  function deposit() external payable;

  function getTopDepositors() external view returns (address[3] memory, uint[3] memory);

  function withdraw() external;
}

/**
 * @title Bank
 * @notice ETH存款银行合约，维护存款排行榜（前3名）
 * @dev 实现IBank接口，与独立的Bank.sol功能相同，但这里作为BigBank的父合约
 *      核心功能：
 *      1. 接收用户的ETH存款
 *      2. 实时维护存款金额前3名的排行榜
 *      3. 管理员可提取合约中的所有ETH
 *
 *      与独立Bank.sol的区别：
 *      - admin不是immutable，允许子合约修改（BigBank需要此特性）
 *      - receive()和deposit()标记为virtual，允许子合约重写
 */
contract Bank is IBank {
  /// @notice 管理员地址，可以提取合约资金
  /// @dev 不使用immutable，因为BigBank需要修改admin
  address public admin;

  /// @notice 记录每个地址的存款总额（单位：wei）
  mapping(address => uint) public deposits;

  /// @notice 存储存款金额前3名的地址，按存款金额从高到低排序
  address[3] public topDepositors;

  /// @dev 排行榜固定长度为3
  uint8 private constant TOP_COUNT = 3;

  /**
   * @notice 构造函数，将部署者设置为管理员
   */
  constructor() {
    admin = msg.sender;
  }

  /**
   * @notice 接收ETH的回退函数
   * @dev 标记为virtual，允许子合约重写（BigBank需要添加存款金额限制）
   */
  receive() external payable virtual {
    _handleDeposit();
  }

  /**
   * @notice 显式存款函数
   * @dev 标记为virtual，允许子合约重写（BigBank需要添加存款金额限制）
   */
  function deposit() external payable virtual {
    _handleDeposit();
  }

  /**
   * @notice 内部函数，处理存款的核心逻辑
   */
  function _handleDeposit() internal {
    deposits[msg.sender] += msg.value;
    updateTopDepositors(msg.sender);
  }

  /**
   * @notice 更新前3名存款人排行榜
   * @param depositor 本次存款的用户地址
   * @dev 算法逻辑与独立Bank.sol相同
   */
  function updateTopDepositors(address depositor) internal {
    uint depositorBalance = deposits[depositor];

    // 如果存款人已经在前3名中，直接更新排序
    for (uint8 i = 0; i < TOP_COUNT; i++) {
      if (topDepositors[i] == depositor) {
        _updateRanking();
        return;
      }
    }

    // 检查是否应该加入前3名
    for (uint8 i = 0; i < TOP_COUNT; i++) {
      address currentAddr = topDepositors[i];
      if (currentAddr == address(0) || depositorBalance > deposits[currentAddr]) {
        for (uint8 j = 2; j > i; j--) {
          topDepositors[j] = topDepositors[j - 1];
        }
        topDepositors[i] = depositor;
        break;
      }
    }
  }

  /**
   * @notice 使用插入排序算法重新排序前3名
   */
  function _updateRanking() internal {
    for (uint8 i = 1; i < TOP_COUNT; i++) {
      address key = topDepositors[i];
      if (key == address(0)) continue;

      uint keyDeposit = deposits[key];
      int8 j = int8(i) - 1;

      while (j >= 0 && (topDepositors[uint8(j)] == address(0) || deposits[topDepositors[uint8(j)]] < keyDeposit)) {
        topDepositors[uint8(j + 1)] = topDepositors[uint8(j)];
        j--;
      }

      topDepositors[uint8(j + 1)] = key;
    }
  }

  /**
   *  @notice 查询前3名存款人及其存款金额
   */
  function getTopDepositors() external view returns (address[3] memory, uint[3] memory) {
    uint[3] memory amounts;
    for (uint8 i = 0; i < TOP_COUNT; i++) {
      amounts[i] = deposits[topDepositors[i]];
    }
    return (topDepositors, amounts);
  }

  /**
   * @notice 管理员提取合约中的所有ETH
   */
  function withdraw() external {
    require(msg.sender == admin, 'Only admin can withdraw');

    uint balance = address(this).balance;

    require(balance > 0, 'No balance to withdraw');

    (bool success, ) = admin.call{ value: balance }('');
    require(success, 'Withdrawal failed');
  }
}

/**
 * @title BigBank
 * @notice 继承Bank合约，增加存款门槛和管理员转移功能
 * @dev 核心改进：
 *      1. 存款门槛：要求每笔存款 > 0.001 ETH，过滤小额存款
 *      2. 双重权限：owner（部署者）和admin（可变更的管理员）
 *      3. 管理员转移：owner可以将admin权限转移给其他地址
 *
 *      权限设计：
 *      - owner：部署时确定，immutable，拥有changeAdmin权限
 *      - admin：可变更，拥有withdraw权限（继承自Bank）
 *
 *      适用场景：
 *      - 需要设置存款门槛的银行系统
 *      - 需要灵活管理员权限的场景（如DAO治理、多签管理）
 */
contract BigBank is Bank {
  /// @notice 合约所有者，部署后不可更改，拥有changeAdmin权限
  address public immutable owner;

  /**
   * @notice 构造函数，将部署者设置为owner
   * @dev owner和admin是两个独立的角色：
   *      - owner：部署者，拥有changeAdmin权限
   *      - admin：继承自Bank，初始为部署者，拥有withdraw权限
   */
  constructor() {
    owner = msg.sender;
  }

  /**
   * @notice 修饰器：要求存款金额大于0.001 ETH
   * @dev 用于deposit()函数，过滤小额存款，减少gas消耗和排行榜更新频率
   */
  modifier depositAmountGreaterThan001() {
    require(msg.value > 0.001 ether, 'Deposit amount must be greater than 0.001 ether');
    _;
  }

  /**
   * @notice 显式存款函数，重写父合约，增加存款门槛
   * @dev 使用modifier检查存款金额，只有 > 0.001 ETH 的存款才会被接受
   */
  function deposit() external payable override depositAmountGreaterThan001 {
    _handleDeposit();
  }

  /**
   * @notice 接收ETH的回退函数，重写父合约，增加存款门槛
   * @dev 直接转账也需要满足 > 0.001 ETH 的条件
   *      注意：这里没有使用modifier，而是直接写require，两种方式都可以
   */
  receive() external payable override {
    require(msg.value > 0.001 ether, 'Deposit amount must be greater than 0.001 ether');
    _handleDeposit();
  }

  /**
   * @notice 转移管理员权限
   * @param newAdmin 新的管理员地址
   * @dev 权限控制：只有owner可以调用
   *
   *      安全检查：
   *      1. 验证调用者是owner
   *      2. 验证新管理员地址不是零地址
   *
   *      使用场景：
   *      - 将管理员权限转移给DAO合约
   *      - 将管理员权限转移给多签钱包
   *      - 管理员私钥泄露时的应急处理
   *
   *      注意事项：
   *      - admin可以修改，因为父合约Bank中admin不是immutable
   *      - owner不可修改，因为使用了immutable 
   */
  function changeAdmin(address newAdmin) external {
    require(msg.sender == owner, 'Only owner can change admin');
    require(newAdmin != address(0), 'New admin cannot be zero address');
    admin = newAdmin;
  }
}

/**
 * @title Admin
 * @notice 管理员代理合约，用于管理多个Bank合约
 * @dev 设计模式：代理模式（Proxy Pattern）
 *
 *      核心功能：
 *      1. 作为Bank合约的admin，代理执行withdraw操作
 *      2. 接收从Bank合约提取的ETH
 *      3. 将ETH转移给真正的管理员（admin）
 *
 *      使用场景：
 *      - 管理多个Bank合约，统一提取资金
 *      - 将Bank的admin设置为Admin合约地址，实现间接管理
 *      - 增加一层安全隔离，避免直接暴露管理员地址
 *
 *      工作流程：
 *      1. 部署Admin合约，记录真正的管理员地址
 *      2. 将Bank合约的admin设置为Admin合约地址（通过BigBank.changeAdmin）
 *      3. 管理员调用Admin.adminWithdraw(bank)，触发bank.withdraw()
 *      4. Bank合约将ETH转给Admin合约（因为Admin是bank的admin）
 *      5. 管理员调用Admin.withdrawToOwner()，将ETH转给自己
 *
 *      安全考虑：
 *      - admin使用immutable，部署后不可更改
 *      - 所有提取操作都需要admin授权
 *      - 使用call{value}而非transfer，避免gas限制
 */
contract Admin {
  /// @notice 真正的管理员地址，部署后不可更改
  address public immutable admin;

  /**
   * @notice 构造函数，将部署者设置为管理员
   */
  constructor() {
    admin = msg.sender;
  }

  /**
   * @notice 接收ETH的回退函数
   * @dev 必须实现此函数，否则无法接收Bank.withdraw()转来的ETH
   */
  receive() external payable {}

  /**
   * @notice 从指定的Bank合约提取资金
   * @param bank Bank合约的接口实例
   * @dev 权限控制：只有admin可以调用
   *
   *      执行流程：
   *      1. 验证调用者是admin
   *      2. 调用bank.withdraw()，触发Bank合约的提取逻辑
   *      3. Bank合约会将ETH转给msg.sender（即Admin合约）
   *      4. Admin合约通过receive()接收ETH
   *
   *      前置条件：
   *      - Bank合约的admin必须是Admin合约地址
   *      - 否则bank.withdraw()会因为权限检查失败而revert
   */
  function adminWithdraw(IBank bank) external {
    require(msg.sender == admin, 'Only admin can withdraw');
    bank.withdraw();
  }

  /**
   * @notice 将Admin合约中的ETH转给管理员
   * @dev 权限控制：只有admin可以调用
   *
   *      使用场景：
   *      - 在调用adminWithdraw()后，将ETH从Admin合约转给管理员
   *      - 清空Admin合约的余额
   *
   *      安全机制：
   *      1. 验证调用者是admin
   *      2. 检查合约余额是否大于0
   *      3. 使用call{value}转账，避免gas限制
   *      4. 检查转账是否成功
   */
  function withdrawToOwner() external {
    require(msg.sender == admin, 'Only admin can withdraw');
    uint balance = address(this).balance;
    require(balance > 0, 'No balance to withdraw');
    (bool success, ) = admin.call{ value: balance }('');
    require(success, 'Withdrawal failed');
  }
}
