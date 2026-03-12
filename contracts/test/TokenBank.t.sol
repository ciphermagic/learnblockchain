// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {BaseERC20} from "../src/BaseERC20.sol";

/**
 * @title TokenBankTest
 * @notice TokenBank合约的测试套件
 * @dev 测试覆盖：
 *      1. 存款功能：test_Deposit()
 *      2. 提款功能：test_Withdraw()
 *      3. 多用户场景：test_MultipleUsers()
 *
 *      测试策略：
 *      - 使用Foundry的Test框架
 *      - 使用vm.startPrank()模拟不同用户
 *      - 使用assertEq()验证状态变化
 *      - 测试正常流程，未测试边界条件和失败场景
 *
 *      测试环境：
 *      - 部署BaseERC20作为测试代币
 *      - 部署TokenBank合约
 *      - 为alice和bob分配初始代币
 */
contract TokenBankTest is Test {
    /// @notice TokenBank合约实例
    TokenBank public tokenBank;

    /// @notice 测试代币合约实例
    BaseERC20 public testToken;

    /// @notice 测试用户alice的地址
    address public alice = makeAddr("alice");

    /// @notice 测试用户bob的地址
    address public bob = makeAddr("bob");

    /// @notice 初始代币余额（1000个代币）
    uint256 public constant INITIAL_BALANCE = 1000 * 10 ** 18;

    /**
     * @notice 测试前置设置
     * @dev 执行流程：
     *      1. 部署BaseERC20测试代币
     *      2. 部署TokenBank合约
     *      3. 为alice和bob分配初始代币
     */
    function setUp() public {
        // 部署测试代币
        testToken = new BaseERC20("Test Token", "TEST");

        // 部署 TokenBank
        tokenBank = new TokenBank(address(testToken));

        // 给测试账户转账
        testToken.transfer(alice, INITIAL_BALANCE);
        testToken.transfer(bob, INITIAL_BALANCE);
    }

    /**
     * @notice 测试存款功能
     * @dev 测试场景：
     *      1. Alice授权TokenBank使用100个代币
     *      2. Alice调用deposit()存入100个代币
     *      3. 验证Alice在TokenBank的余额
     *      4. 验证TokenBank的总存款量
     *      5. 验证TokenBank合约持有的代币数量
     *
     *      使用的Foundry cheatcode：
     *      - vm.startPrank(alice)：模拟alice发起交易
     *      - vm.stopPrank()：停止模拟
     *      - assertEq()：断言相等
     */
    function test_Deposit() public {
        uint256 depositAmount = 100 * 10 ** 18;

        vm.startPrank(alice);

        // 授权 TokenBank 使用代币
        testToken.approve(address(tokenBank), depositAmount);

        // 执行存款
        tokenBank.deposit(depositAmount);

        // 验证余额
        assertEq(tokenBank.balanceOf(alice), depositAmount);
        assertEq(tokenBank.totalDeposits(), depositAmount);
        assertEq(testToken.balanceOf(address(tokenBank)), depositAmount);

        vm.stopPrank();
    }

    /**
     * @notice 测试提款功能
     * @dev 测试场景：
     *      1. Alice先存入100个代币
     *      2. Alice提取50个代币
     *      3. 验证Alice在TokenBank的剩余余额（50个）
     *      4. 验证TokenBank的总存款量减少
     *      5. 验证Alice的代币余额增加
     *
     *      测试重点：
     *      - 提款后余额正确更新
     *      - 代币正确转回用户
     *      - 总存款量正确减少
     */
    function test_Withdraw() public {
        uint256 depositAmount = 100 * 10 ** 18;
        uint256 withdrawAmount = 50 * 10 ** 18;

        vm.startPrank(alice);

        // 先存款
        testToken.approve(address(tokenBank), depositAmount);
        tokenBank.deposit(depositAmount);

        // 记录提款前的余额
        uint256 balanceBefore = testToken.balanceOf(alice);

        // 执行提款
        tokenBank.withdraw(withdrawAmount);

        // 验证余额
        assertEq(tokenBank.balanceOf(alice), depositAmount - withdrawAmount);
        assertEq(tokenBank.totalDeposits(), depositAmount - withdrawAmount);
        assertEq(testToken.balanceOf(alice), balanceBefore + withdrawAmount);

        vm.stopPrank();
    }

    /**
     * @notice 测试多用户场景
     * @dev 测试场景：
     *      1. Alice存入100个代币
     *      2. Bob存入200个代币
     *      3. 验证总存款量为300个代币
     *      4. 验证各用户的余额独立且正确
     *
     *      测试重点：
     *      - 多用户存款互不影响
     *      - 总存款量正确累加
     *      - 每个用户的余额独立记录
     *
     *      未覆盖的场景：
     *      - 用户之间的余额隔离（一个用户无法提取另一个用户的存款）
     *      - 并发存款/提款
     */
    function test_MultipleUsers() public {
        uint256 aliceDeposit = 100 * 10 ** 18;
        uint256 bobDeposit = 200 * 10 ** 18;

        // Alice 存款
        vm.startPrank(alice);
        testToken.approve(address(tokenBank), aliceDeposit);
        tokenBank.deposit(aliceDeposit);
        vm.stopPrank();

        // Bob 存款
        vm.startPrank(bob);
        testToken.approve(address(tokenBank), bobDeposit);
        tokenBank.deposit(bobDeposit);
        vm.stopPrank();

        // 验证总存款
        assertEq(tokenBank.totalDeposits(), aliceDeposit + bobDeposit);

        // 验证各个用户的余额
        assertEq(tokenBank.balanceOf(alice), aliceDeposit);
        assertEq(tokenBank.balanceOf(bob), bobDeposit);
    }
}