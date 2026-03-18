// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import 'forge-std/Test.sol';
import '../src/BigBank.sol';

/**
 * @title BigBankTest
 * @notice BigBank 合约的完整测试套件
 * @dev 测试覆盖：
 *      1. Bank 基础功能（存款、排行榜、提取）
 *      2. BigBank 存款门槛
 *      3. BigBank 权限管理
 *      4. Admin 代理合约
 *
 * 测试设计原则：
 * - 每个测试函数测试一个独立的功能点
 * - 使用清晰的测试名称描述测试内容
 * - 使用 assertEq/assertTrue 等进行断言验证
 * - 使用 vm.prank 模拟不同用户调用
 * - 使用 vm.expectRevert 验证错误回滚
 *
 * 测试账户说明：
 * - owner: 部署合约的账户，相当于测试框架的默认账户
 * - user1-user4: 通过 makeAddr 创建的虚拟测试账户
 */
contract BigBankTest is Test {
  /// @notice Bank 合约实例，用于测试基础银行功能
  Bank public bank;

  /// @notice BigBank 合约实例，用于测试带存款门槛的银行功能
  BigBank public bigBank;

  /// @notice Admin 代理合约实例，用于测试管理员代理功能
  Admin public admin;

  /// @notice 合约部署者账户，也是测试框架的默认账户
  address public owner;

  /// @notice 测试用户1，用于模拟普通用户存款操作
  address public user1;

  /// @notice 测试用户2
  address public user2;

  /// @notice 测试用户3
  address public user3;

  /// @notice 测试用户4
  address public user4;

  /// @notice 存款事件，用于验证存款时是否正确触发事件
  /// @param user 存款用户地址
  /// @param amount 存款金额（wei）
  event Deposit(address indexed user, uint amount);

  /**
   * @notice 接收 ETH 的回退函数
   * @dev 在测试中使用，用于测试管理员提取功能
   *      因为提取ETH需要有一个接收地址，否则转账会失败
   *      这个测试合约通过实现 receive() 函数来接收提取的ETH
   */
  receive() external payable {}

  /**
   * @notice 测试前置设置函数
   * @dev 在每个测试函数执行前自动调用
   *      负责初始化合约实例和测试账户
   *
   * 初始化步骤：
   * 1. 设置 owner 为当前测试合约地址
   * 2. 创建4个虚拟测试账户（user1-user4）
   * 3. 部署 Bank、BigBank、Admin 三个合约
   * 4. 为每个测试账户分配 100 ETH 用于测试
   */
  function setUp() public {
    // 获取当前合约地址作为 owner（forge-std Test 合约的默认账户）
    owner = address(this);

    // 使用 makeAddr 创建虚拟地址，模拟真实用户
    // makeAddr 是 forge-std 提供的辅助函数，可以创建确定性的虚拟地址
    user1 = makeAddr('user1');
    user2 = makeAddr('user2');
    user3 = makeAddr('user3');
    user4 = makeAddr('user4');

    // 部署三个合约：
    // 1. Bank: 基础银行合约，无存款门槛
    // 2. BigBank: 增强银行合约，有存款门槛和权限管理
    // 3. Admin: 管理员代理合约，用于代理执行银行操作
    bank = new Bank();
    bigBank = new BigBank();
    admin = new Admin();

    // 使用 vm.deal 分配测试 ETH
    // vm.deal 是 forge-std 提供的 cheatcode，用于给地址充值 ETH
    vm.deal(user1, 100 ether);
    vm.deal(user2, 100 ether);
    vm.deal(user3, 100 ether);
    vm.deal(user4, 100 ether);
  }

  // ============ Bank 基础功能测试 ============
  // 测试目标：验证 Bank 合约的基础存款、排行榜、提取功能

  /**
   * @notice 测试通过 deposit 函数存款
   * @dev 验证用户调用 deposit 函数时，存款金额正确记录到 deposits 映射中
   *
   * 测试步骤：
   * 1. 模拟 user1 调用 deposit 函数，存入 1 ETH
   * 2. 验证 user1 的存款余额等于 1 ETH
   *
   * 预期结果：bank.deposits(user1) == 1 ether
   */
  function testBankDeposit() public {
    // vm.prank 用于模拟从指定地址发送交易
    // 设置 msg.sender 为 user1，后续操作都以 user1 的身份执行
    vm.prank(user1);

    // 调用 deposit 函数并附带 1 ETH 的 value
    // { value: 1 ether } 表示发送 1 ETH 到合约
    bank.deposit{ value: 1 ether }();

    // 使用 assertEq 断言验证结果
    // 第一个参数是实际值，第二个是期望值
    assertEq(bank.deposits(user1), 1 ether);
  }

  /**
   * @notice 测试通过 receive 回退函数存款
   * @dev 验证用户直接向合约转账时（通过 call），存款正确记录
   *
   * 测试场景：
   * - 用户可能不调用 deposit 函数，而是直接向合约地址转账
   * - 这种情况下会触发 receive 回退函数，同样可以存款
   *
   * 测试步骤：
   * 1. 模拟 user1 直接向 Bank 合约地址转账 1 ETH
   * 2. 验证存款记录正确
   */
  function testBankReceive() public {
    vm.prank(user1);

    // 使用低级 call 向合约地址转账
    // address(bank) 转换为地址类型
    // .call{ value: 1 ether }('')，空字符串表示不带任何数据调用
    (bool success, ) = address(bank).call{ value: 1 ether }('');

    // 验证 call 执行成功
    assertTrue(success);

    // 验证存款记录
    assertEq(bank.deposits(user1), 1 ether);
  }

  /**
   * @notice 测试同一用户多次存款
   * @dev 验证用户的累计存款金额是正确累加的
   *
   * 测试步骤：
   * 1. user1 第一次存款 1 ETH
   * 2. user1 第二次存款 2 ETH
   * 3. 验证总存款 = 1 + 2 = 3 ETH
   */
  function testBankMultipleDeposits() public {
    // 第一次存款
    vm.prank(user1);
    bank.deposit{ value: 1 ether }();

    // 第二次存款（同一个用户）
    vm.prank(user1);
    bank.deposit{ value: 2 ether }();

    // 验证累计存款总额
    assertEq(bank.deposits(user1), 3 ether);
  }

  /**
   * @notice 测试获取前3名存款人排行榜
   * @dev 验证排行榜按照存款金额从高到低正确排序
   *
   * 测试数据：
   * - user1: 3 ETH
   * - user2: 5 ETH（最高）
   * - user3: 1 ETH
   *
   * 预期排序：user2 > user1 > user3
   */
  function testBankTopDepositors() public {
    // user1 存 3 ether
    vm.prank(user1);
    bank.deposit{ value: 3 ether }();

    // user2 存 5 ether
    vm.prank(user2);
    bank.deposit{ value: 5 ether }();

    // user3 存 1 ether
    vm.prank(user3);
    bank.deposit{ value: 1 ether }();

    // 调用 getTopDepositors 获取排行榜
    // 返回两个数组：地址数组和金额数组
    (address[3] memory topAddrs, uint[3] memory topAmounts) = bank.getTopDepositors();

    // 验证第1名：user2，5 ETH
    assertEq(topAddrs[0], user2);
    assertEq(topAmounts[0], 5 ether);

    // 验证第2名：user1，3 ETH
    assertEq(topAddrs[1], user1);
    assertEq(topAmounts[1], 3 ether);

    // 验证第3名：user3，1 ETH
    assertEq(topAddrs[2], user3);
    assertEq(topAmounts[2], 1 ether);
  }

  /**
   * @notice 测试排行榜更新逻辑
   * @dev 验证当用户追加存款导致排名变化时，排行榜正确更新
   *
   * 测试场景：
   * - 初始排名：user3(3) > user2(2) > user1(1)
   * - user1 追加 3 ETH后变为 4 ETH，超越 user3
   * - 新排名：user1(4) > user3(3) > user2(2)
   */
  function testBankTopDepositorsUpdate() public {
    // 初始排名：user1(1) < user2(2) < user3(3)
    vm.prank(user1);
    bank.deposit{ value: 1 ether }();

    vm.prank(user2);
    bank.deposit{ value: 2 ether }();

    vm.prank(user3);
    bank.deposit{ value: 3 ether }();

    // user1 追加存款 3 ETH，总额变为 4 ETH
    // 现在 user1(4) > user3(3)，应该排名第一
    vm.prank(user1);
    bank.deposit{ value: 3 ether }();

    // 获取更新后的排行榜
    (address[3] memory topAddrs, uint[3] memory topAmounts) = bank.getTopDepositors();

    // 验证新排序：user1(4) > user3(3) > user2(2)
    assertEq(topAddrs[0], user1);
    assertEq(topAmounts[0], 4 ether);
    assertEq(topAddrs[1], user3);
    assertEq(topAmounts[1], 3 ether);
    assertEq(topAddrs[2], user2);
    assertEq(topAmounts[2], 2 ether);
  }

  /**
   * @notice 测试超过3个用户时的排行榜行为
   * @dev 验证排行榜只保留前3名，忽略第4名及之后的用户
   *
   * 测试数据：
   * - user1: 1 ETH（第4名，应该被忽略）
   * - user2: 2 ETH（第3名）
   * - user3: 3 ETH（第2名）
   * - user4: 4 ETH（第1名）
   */
  function testBankTopDepositorsMoreThanThree() public {
    vm.prank(user1);
    bank.deposit{ value: 1 ether }();

    vm.prank(user2);
    bank.deposit{ value: 2 ether }();

    vm.prank(user3);
    bank.deposit{ value: 3 ether }();

    vm.prank(user4);
    bank.deposit{ value: 4 ether }();

    (address[3] memory topAddrs, uint[3] memory topAmounts) = bank.getTopDepositors();

    // 只保留前3名：user4(4) > user3(3) > user2(2)
    // user1(1) 被排除在外
    assertEq(topAddrs[0], user4);
    assertEq(topAmounts[0], 4 ether);
    assertEq(topAddrs[1], user3);
    assertEq(topAmounts[1], 3 ether);
    assertEq(topAddrs[2], user2);
    assertEq(topAmounts[2], 2 ether);
  }

  /**
   * @notice 测试管理员成功提取资金
   * @dev 验证 admin 调用 withdraw 函数可以成功提取合约中的所有 ETH
   *
   * 测试步骤：
   * 1. user1 存款 10 ETH 到 Bank 合约
   * 2. 记录 owner（admin）提取前的 ETH 余额
   * 3. admin 调用 withdraw 提取所有资金
   * 4. 验证 Bank 合约余额为 0
   * 5. 验证 owner 余额增加了 10 ETH
   */
  function testBankWithdrawByAdmin() public {
    // user1 存款
    vm.prank(user1);
    bank.deposit{ value: 10 ether }();

    // 记录提取前的余额
    uint balanceBefore = owner.balance;

    // admin（owner）调用 withdraw
    bank.withdraw();

    // 验证合约余额为 0
    assertEq(address(bank).balance, 0);

    // 验证 owner 余额增加
    assertEq(owner.balance, balanceBefore + 10 ether);
  }

  /**
   * @notice 测试非管理员无法提取资金
   * @dev 验证只有 admin 才能调用 withdraw 函数
   *
   * 测试步骤：
   * 1. user1 存款
   * 2. 模拟 user1 尝试调用 withdraw
   * 3. 验证交易回滚，错误信息为 "Only admin can withdraw"
   */
  function testBankWithdrawByNonAdmin() public {
    // user1 存款
    vm.prank(user1);
    bank.deposit{ value: 10 ether }();

    // 模拟 user1 尝试提取（应该失败）
    vm.prank(user1);

    // 使用 vm.expectRevert 预期交易会回滚
    // 验证错误信息匹配
    vm.expectRevert('Only admin can withdraw');
    bank.withdraw();
  }

  /**
   * @notice 测试零余额时无法提取
   * @dev 验证合约余额为 0 时，withdraw 函数应该回滚
   */
  function testBankWithdrawZeroBalance() public {
    // 直接调用 withdraw，预期回滚
    vm.expectRevert('No balance to withdraw');
    bank.withdraw();
  }

  // ============ BigBank 存款门槛测试 ============
  // 测试目标：验证 BigBank 合约的存款门槛功能
  // 存款门槛：每笔存款必须 > 0.001 ETH

  /**
   * @notice 测试存款金额高于门槛（正常存款）
   * @dev 验证当存款 > 0.001 ETH 时，存款成功
   *
   * 门槛说明：BigBank 要求每笔存款必须大于 0.001 ETH
   * 测试用例：0.002 ETH > 0.001 ETH，应该成功
   */
  function testBigBankDepositAboveThreshold() public {
    vm.prank(user1);

    // 存款 0.002 ETH，大于门槛 0.001 ETH
    bigBank.deposit{ value: 0.002 ether }();

    // 验证存款成功记录
    assertEq(bigBank.deposits(user1), 0.002 ether);
  }

  /**
   * @notice 测试存款金额低于门槛（应拒绝）
   * @dev 验证当存款 <= 0.001 ETH 时，交易回滚
   *
   * 测试用例：0.001 ETH = 门槛值，应该被拒绝
   * 注意：门槛是"大于"门槛，不是"大于等于"
   */
  function testBigBankDepositBelowThreshold() public {
    vm.prank(user1);

    // 存款 0.001 ETH，等于门槛，应该被拒绝
    vm.expectRevert('Deposit amount must be greater than 0.001 ether');
    bigBank.deposit{ value: 0.001 ether }();
  }

  /**
   * @notice 测试存款金额恰好等于门槛（应拒绝）
   * @dev 与上一个测试类似，验证等于门槛时也被拒绝
   */
  function testBigBankDepositExactlyThreshold() public {
    vm.prank(user1);

    // 再次验证等于门槛的情况
    vm.expectRevert('Deposit amount must be greater than 0.001 ether');
    bigBank.deposit{ value: 0.001 ether }();
  }

  /**
   * @notice 测试通过 receive 函数存款高于门槛
   * @dev 验证直接转账（触发 receive）也受存款门槛限制
   *
   * 与 deposit 函数不同，通过 receive 函数存款也需要检查门槛
   */
  function testBigBankReceiveAboveThreshold() public {
    vm.prank(user1);

    // 直接转账 0.002 ETH
    (bool success, ) = address(bigBank).call{ value: 0.002 ether }('');

    // 验证成功
    assertTrue(success);

    // 验证存款记录
    assertEq(bigBank.deposits(user1), 0.002 ether);
  }

  /**
   * @notice 测试通过 receive 函数存款低于门槛
   * @dev 验证低于门槛的直接转账会被拒绝
   */
  function testBigBankReceiveBelowThreshold() public {
    vm.prank(user1);

    // 转账 0.0005 ETH，小于门槛
    (bool success, ) = address(bigBank).call{ value: 0.0005 ether }('');

    // 应该失败（返回 false）
    assertFalse(success);
  }

  /**
   * @notice 测试 BigBank 排行榜功能
   * @dev 验证 BigBank 同样维护前3名存款人排行榜
   *
   * 与 Bank 的区别：BigBank 只接受大于门槛的存款
   * 所以低于门槛的存款不会影响排行榜
   */
  function testBigBankTopDepositorsWithThreshold() public {
    vm.prank(user1);
    bigBank.deposit{ value: 0.002 ether }();

    vm.prank(user2);
    bigBank.deposit{ value: 0.005 ether }();

    vm.prank(user3);
    bigBank.deposit{ value: 0.003 ether }();

    (address[3] memory topAddrs, uint[3] memory topAmounts) = bigBank.getTopDepositors();

    // 排序验证：user2(0.005) > user3(0.003) > user1(0.002)
    assertEq(topAddrs[0], user2);
    assertEq(topAmounts[0], 0.005 ether);
    assertEq(topAddrs[1], user3);
    assertEq(topAmounts[1], 0.003 ether);
    assertEq(topAddrs[2], user1);
    assertEq(topAmounts[2], 0.002 ether);
  }

  // ============ BigBank 权限管理测试 ============
  // 测试目标：验证 BigBank 的 owner 和 admin 权限分离设计

  /**
   * @notice 测试初始 owner 和 admin 相等
   * @dev 验证 BigBank 部署后，owner 和 admin 都是部署者
   *
   * BigBank 设计：
   * - owner: 部署者，immutable，不可变更
   * - admin: 初始为部署者，可通过 changeAdmin 变更
   */
  function testBigBankOwnerAndAdmin() public {
    // owner 和 admin 初始都是部署者（owner）
    assertEq(bigBank.owner(), owner);
    assertEq(bigBank.admin(), owner);
  }

  /**
   * @notice 测试 owner 成功变更 admin
   * @dev 验证 owner 可以将 admin 权限转移给其他地址
   *
   * 权限设计：
   * - owner: 拥有 changeAdmin 权限，可以变更 admin
   * - admin: 拥有 withdraw 权限，可以提取资金
   */
  function testBigBankChangeAdminByOwner() public {
    // owner 调用 changeAdmin 将 admin 变更为 user1
    bigBank.changeAdmin(user1);

    // 验证 admin 已变更
    assertEq(bigBank.admin(), user1);

    // 验证 owner 不变（immutable）
    assertEq(bigBank.owner(), owner);
  }

  /**
   * @notice 测试非 owner 无法变更 admin
   * @dev 验证权限控制，只有 owner 可以调用 changeAdmin
   */
  function testBigBankChangeAdminByNonOwner() public {
    // 模拟 user1 尝试变更 admin（应该失败）
    vm.prank(user1);
    vm.expectRevert('Only owner can change admin');
    bigBank.changeAdmin(user2);
  }

  /**
   * @notice 测试不能将 admin 变更为零地址
   * @dev 零地址是一个特殊地址，通常用于销毁权限
   *      禁止将 admin 设为零地址是安全最佳实践
   */
  function testBigBankChangeAdminToZeroAddress() public {
    vm.expectRevert('New admin cannot be zero address');
    bigBank.changeAdmin(address(0));
  }

  /**
   * @notice 测试新 admin 可以成功提取资金
   * @dev 验证 admin 变更后，新 admin 获得 withdraw 权限
   *
   * 工作流程：
   * 1. user1 存款到 bigBank
   * 2. owner 将 admin 变更为 user2
   * 3. user2（新的 admin）可以提取资金
   */
  function testBigBankWithdrawByNewAdmin() public {
    // 1. user1 存入资金
    vm.prank(user1);
    bigBank.deposit{ value: 1 ether }();

    // 2. 更换 admin 为 user2
    bigBank.changeAdmin(user2);

    // 3. 新 admin（user2）提取资金
    uint balanceBefore = user2.balance;
    vm.prank(user2);
    bigBank.withdraw();

    // 验证结果
    assertEq(address(bigBank).balance, 0);
    assertEq(user2.balance, balanceBefore + 1 ether);
  }

  /**
   * @notice 测试旧 admin 无法提取资金
   * @dev 验证 admin 变更后，旧 admin 失去 withdraw 权限
   *
   * 这是权限分离的安全设计：
   * - owner 保留 changeAdmin 权限（不可变更）
   * - admin 拥有 withdraw 权限（可变更）
   * - 变更 admin 后，旧 admin 立即失去权限
   */
  function testBigBankWithdrawByOldAdmin() public {
    // user1 存款
    vm.prank(user1);
    bigBank.deposit{ value: 1 ether }();

    // owner 将 admin 变更为 user2
    bigBank.changeAdmin(user2);

    // 旧的 admin（owner）尝试提取，应该失败
    vm.expectRevert('Only admin can withdraw');
    bigBank.withdraw();
  }

  // ============ Admin 代理合约测试 ============
  // 测试目标：验证 Admin 代理合约的功能
  // Admin 合约作为 Bank 合约的代理，间接管理多个银行

  /**
   * @notice 测试 Admin 合约构造函数
   * @dev 验证 Admin 部署后，admin 设置为部署者
   *
   * Admin 合约设计：
   * - admin: immutable，部署后不可更改
   * - 这是安全设计，避免管理员权限被篡改
   */
  function testAdminConstructor() public {
    assertEq(admin.admin(), owner);
  }

  /**
   * @notice 测试 Admin 合约接收 ETH
   * @dev 验证 Admin 合约可以通过 receive 函数接收 ETH
   *
   * 用途：
   * - Admin 合约需要接收 Bank 合约转来的 ETH
   * - 然后管理员可以调用 withdrawToOwner 转出
   */
  function testAdminReceive() public {
    vm.prank(user1);

    // user1 向 Admin 合约转账 1 ETH
    (bool success, ) = address(admin).call{ value: 1 ether }('');
    assertTrue(success);

    // 验证 Admin 合约余额
    assertEq(address(admin).balance, 1 ether);
  }

  /**
   * @notice 测试 Admin 从 Bank 提取资金
   * @dev 验证 Admin 代理提取的工作流程
   *
   * 工作流程：
   * 1. 将 bigBank 的 admin 设置为 Admin 合约地址
   * 2. user1 存款到 bigBank
   * 3. Admin 调用 adminWithdraw 从 bigBank 提取资金
   * 4. 资金转移到 Admin 合约
   */
  function testAdminWithdrawFromBank() public {
    // 1. 将 bigBank 的 admin 设置为 Admin 合约
    bigBank.changeAdmin(address(admin));

    // 2. user1 存款到 bigBank
    vm.prank(user1);
    bigBank.deposit{ value: 10 ether }();

    // 3. 通过 Admin 合约提取
    admin.adminWithdraw(IBank(address(bigBank)));

    // 4. 验证资金转到 Admin 合约
    assertEq(address(bigBank).balance, 0);
    assertEq(address(admin).balance, 10 ether);
  }

  /**
   * @notice 测试非管理员无法调用 adminWithdraw
   * @dev 验证权限控制，只有 Admin 合约的 admin 可以调用
   */
  function testAdminWithdrawFromBankByNonAdmin() public {
    bigBank.changeAdmin(address(admin));

    vm.prank(user1);
    bigBank.deposit{ value: 10 ether }();

    // user1 不是 Admin 合约的 admin，无法提取
    vm.prank(user1);
    vm.expectRevert('Only admin can withdraw');
    admin.adminWithdraw(IBank(address(bigBank)));
  }

  /**
   * @notice 测试 Admin 将资金转给 owner
   * @dev 验证 Admin 合约的 withdrawToOwner 功能
   *
   * 完整流程：
   * 1. ETH 转入 Admin 合约（通过任何方式）
   * 2. admin 调用 withdrawToOwner
   * 3. ETH 从 Admin 合约转给 admin
   */
  function testAdminWithdrawToOwner() public {
    // 1. 给 Admin 合约转入 ETH（通过 user1 转账）
    vm.prank(user1);
    (bool success, ) = address(admin).call{ value: 5 ether }('');
    assertTrue(success);

    // 记录提取前的余额
    uint balanceBefore = owner.balance;

    // 2. admin 调用 withdrawToOwner
    admin.withdrawToOwner();

    // 3. 验证结果
    assertEq(address(admin).balance, 0);
    assertEq(owner.balance, balanceBefore + 5 ether);
  }

  /**
   * @notice 测试非管理员无法调用 withdrawToOwner
   * @dev 验证权限控制
   */
  function testAdminWithdrawToOwnerByNonAdmin() public {
    // 先给 Admin 转入 ETH
    vm.prank(user1);
    (bool success, ) = address(admin).call{ value: 5 ether }('');
    assertTrue(success);

    // user1 尝试提取，应该失败
    vm.prank(user1);
    vm.expectRevert('Only admin can withdraw');
    admin.withdrawToOwner();
  }

  /**
   * @notice 测试零余额时无法提取
   * @dev 验证空合约无法提取
   */
  function testAdminWithdrawToOwnerZeroBalance() public {
    vm.expectRevert('No balance to withdraw');
    admin.withdrawToOwner();
  }

  /**
   * @notice 测试完整的 Admin 代理工作流程
   * @dev 模拟真实场景：用户存款 -> Admin 代理提取 -> 转给管理员
   *
   * 完整工作流程：
   * 1. 配置：设置 bigBank 的 admin 为 Admin 合约
   * 2. 存款：用户向 bigBank 存款
   * 3. 提取：Admin 从 bigBank 提取资金（资金到 Admin 合约）
   * 4. 转账：Admin 将资金转给真正的管理员
   *
   * 使用场景：
   * - DAO 治理：资金先到 DAO 合约，再由 DAO 投票决定用途
   * - 多签钱包：资金到多签合约，需要多个签名才能转出
   * - 安全管理：增加一层权限控制，避免直接暴露 admin 私钥
   */
  function testAdminFullWorkflow() public {
    // 1. 将 bigBank 的 admin 设置为 Admin 合约
    bigBank.changeAdmin(address(admin));

    // 2. 用户存款
    vm.prank(user1);
    bigBank.deposit{ value: 10 ether }();

    // 3. 通过 Admin 合约从 bigBank 提取
    // 注意：提取后资金到 Admin 合约，不是直接到 owner
    admin.adminWithdraw(IBank(address(bigBank)));
    assertEq(address(admin).balance, 10 ether);

    // 4. 将 ETH 转给真正的管理员（owner）
    uint balanceBefore = owner.balance;
    admin.withdrawToOwner();

    // 验证最终结果
    assertEq(owner.balance, balanceBefore + 10 ether);
    assertEq(address(admin).balance, 0);
  }

  // ============ 边界情况和 Gas 优化测试 ============
  // 测试目标：验证边界条件和特殊场景的处理

  /**
   * @notice 测试零存款
   * @dev 验证 Bank 允许零存款（可能用于测试或占位）
   *
   * 注意：BigBank 不允许零存款（有门槛限制）
   */
  function testBankZeroDeposit() public {
    vm.prank(user1);

    // 存款 0 ETH
    bank.deposit{ value: 0 }();

    // 验证存款记录为 0
    assertEq(bank.deposits(user1), 0);
  }

  /**
   * @notice 测试 BigBank 零存款（应拒绝）
   * @dev 验证 BigBank 拒绝低于门槛的存款
   */
  function testBigBankZeroDeposit() public {
    vm.prank(user1);

    // BigBank 拒绝 0 存款
    vm.expectRevert('Deposit amount must be greater than 0.001 ether');
    bigBank.deposit{ value: 0 }();
  }

  /**
   * @notice 测试大额存款
   * @dev 验证合约可以处理大额存款（1000 ETH）
   *
   * 这是边界测试，确保 uint256 不会溢出
   */
  function testBankLargeDeposit() public {
    // 先给 user1 分配足够的 ETH
    vm.deal(user1, 1000 ether);
    vm.prank(user1);

    // 存款 1000 ETH
    bank.deposit{ value: 1000 ether }();

    // 验证存款记录
    assertEq(bank.deposits(user1), 1000 ether);
  }

  /**
   * @notice 测试同一用户连续多次存款
   * @dev 验证多次存款正确累加，且用户成为排行榜第1
   *
   * 测试场景：
   * - user1 分3次存款：1 + 2 + 3 = 6 ETH
   * - 验证总存款 = 6 ETH
   * - 验证 user1 是排行榜第1
   */
  function testBankSameUserMultipleDeposits() public {
    // 使用 vm.startPrank 开始连续操作
    // 相当于连续多个 vm.prank，但更简洁
    vm.startPrank(user1);

    // 连续存款3次
    bank.deposit{ value: 1 ether }();
    bank.deposit{ value: 2 ether }();
    bank.deposit{ value: 3 ether }();

    // 结束连续操作
    vm.stopPrank();

    // 验证总存款 = 6 ETH
    assertEq(bank.deposits(user1), 6 ether);

    // 验证 user1 是第1名
    (address[3] memory topAddrs, ) = bank.getTopDepositors();
    assertEq(topAddrs[0], user1);
  }

  /**
   * @notice 测试排行榜中包含零地址的情况
   * @dev 验证当存款人数不足3人时，排行榜会包含零地址
   *
   * 测试场景：
   * - 只有 user1 存款 1 ETH
   * - 排行榜应该：[user1, address(0), address(0)]
   * - 对应金额：[1 ether, 0, 0]
   */
  function testBankTopDepositorsWithZeroAddresses() public {
    vm.prank(user1);
    bank.deposit{ value: 1 ether }();

    (address[3] memory topAddrs, uint[3] memory topAmounts) = bank.getTopDepositors();

    // 第1名：user1
    assertEq(topAddrs[0], user1);
    assertEq(topAmounts[0], 1 ether);

    // 第2名：零地址（未填充）
    assertEq(topAddrs[1], address(0));
    assertEq(topAmounts[1], 0);

    // 第3名：零地址（未填充）
    assertEq(topAddrs[2], address(0));
    assertEq(topAmounts[2], 0);
  }

  // ============ Fuzz 测试 ============
  // 测试目标：使用随机生成的输入值进行测试，发现边界问题
  // fuzz 测试通过随机值发现潜在的智能合约漏洞

  /**
   * @notice Fuzz 测试：Bank 存款功能
   * @dev 使用随机金额测试 Bank 的存款功能
   *
   * vm.assume 设置测试前提条件：
   * - amount > 0：排除零值测试（已在其他测试中覆盖）
   *
   * fuzz 测试优势：
   * - 自动生成大量随机测试用例
   * - 发现人工测试难以想到的边界情况
   * - 提高测试覆盖率
   *
   * @param amount 随机生成的存款金额（uint96 类型）
   */
  function testFuzzBankDeposit(uint96 amount) public {
    // 假设金额大于 0（vm.assume 会过滤掉不满足条件的输入）
    vm.assume(amount > 0);

    // 给 user1 分配随机金额的 ETH
    vm.deal(user1, amount);

    // user1 存款
    vm.prank(user1);
    bank.deposit{ value: amount }();

    // 验证存款记录
    assertEq(bank.deposits(user1), amount);
  }

  /**
   * @notice Fuzz 测试：BigBank 存款功能（高于门槛）
   * @dev 使用随机金额测试 BigBank 的存款门槛
   *
   * 条件：amount > 0.001 ether
   * 这样所有随机输入都应该成功存款
   *
   * @param amount 随机生成的存款金额
   */
  function testFuzzBigBankDeposit(uint96 amount) public {
    // 假设金额大于门槛
    vm.assume(amount > 0.001 ether);
    vm.deal(user1, amount);

    vm.prank(user1);
    bigBank.deposit{ value: amount }();

    assertEq(bigBank.deposits(user1), amount);
  }

  /**
   * @notice Fuzz 测试：BigBank 存款门槛验证
   * @dev 使用随机金额测试 BigBank 拒绝低存款
   *
   * 条件：amount <= 0.001 ether
   * 这样所有随机输入都应该被拒绝
   *
   * @param amount 随机生成的存款金额
   */
  function testFuzzBigBankDepositBelowThreshold(uint96 amount) public {
    // 假设金额小于等于门槛
    vm.assume(amount <= 0.001 ether);
    vm.deal(user1, amount);

    vm.prank(user1);
    vm.expectRevert('Deposit amount must be greater than 0.001 ether');
    bigBank.deposit{ value: amount }();
  }
}
