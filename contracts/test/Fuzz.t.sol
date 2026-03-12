// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Fuzz 测试套件
 * @notice 测试 Foundry 的模糊测试（Fuzz Testing）功能
 * @dev 使用随机生成的输入数据测试函数，发现边界条件和潜在漏洞
 *
 * Fuzz Testing 核心概念：
 * - 随机生成大量输入数据执行目标函数
 * - 自动发现导致失败的边界值和异常输入
 * - 适合发现整数溢出、访问控制、逻辑错误等问题
 *
 * Foundry Fuzz 测试特性：
 * - 自动生成输入参数（address, uint256, bytes 等）
 * - 内置假设函数（vm.assume）过滤无效输入
 * - bound 函数限制输入范围
 * - 失败时自动最小化复现用例
 */
import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {Owner} from "../src/Owner.sol";
import {BaseERC20} from "../src/BaseERC20.sol";

/**
 * @title FuzzTest
 * @notice 展示 Foundry 模糊测试的基本用法
 * @dev 测试函数以 "testFuzz_" 前缀开头，参数为随机生成的值
 *
 * Fuzz 测试最佳实践：
 * 1. 使用 vm.assume 添加前置条件，过滤无效输入
 * 2. 使用 bound 限制数值范围，避免测试过于发散
 * 3. 确保测试断言覆盖所有可能的输出情况
 * 4. 关注边界条件：0、最大值、负数转换等
 *
 * 安全关注点：
 * - 整数溢出/下溢
 * - 除零错误
 * - 访问控制失效
 * - 逻辑错误导致的异常状态
 */
contract FuzzTest is Test {
    Counter public counter;
    address public alice;
    address public bob;
    BaseERC20 public token;

    function setUp() public {
        counter = new Counter();
        token = new BaseERC20("Test", "TEST");
    }

    /**
     * @notice 模糊测试 Counter.setNumber 函数
     * @dev 使用随机 uint256 参数测试 setNumber
     *
     * 测试原理：
     * - Foundry 自动生成随机的 uint256 值 x
     * - 调用 counter.setNumber(x)
     * - 验证 number() 返回值等于 x
     *
     * 这种测试覆盖了：
     * - 0 值
     * - 小数值
     * - 大数值（接近 uint256 最大值）
     * - 各种边界值
     *
     * @param x 随机生成的 uint256 值，用于测试计数器设置
     */
    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }

    /**
     * @notice 模糊测试 ERC20 转账功能
     * @dev 使用随机地址和金额测试 ERC20 transfer
     *
     * 输入生成：
     * - to: 随机地址（ Foundry 自动生成）
     * - amount: 随机金额
     *
     * 前置条件（vm.assume）：
     * - 接收方不能是零地址（某些 ERC20 不允许）
     * - 接收方不能是测试合约本身（避免干扰）
     *
     * 范围限制（bound）：
     * - 将 amount 限制在 0 到 10000 * 10^18 之间
     * - bound 函数确保值在 [min, max] 范围内
     *
     * @param to 随机生成的接收地址
     * @param amount 随机生成的转账金额
     */
    function testFuzz_ERC20Transfer(address to, uint256 amount) public {
        // console.log("token:", address(token)); // 无法打印日志

        // vm.assume: 添加测试前置条件，过滤无效输入
        // 接收方不能是零地址（零地址转账通常被禁止或标记为特殊情况）
        vm.assume(to != address(0));
        // 接收方不能是当前合约（避免自我转账等边界情况）
        vm.assume(to != address(this));

        // bound: 限制随机值的范围
        // 将 amount 限制在 [0, 10000 * 10^18] 范围内
        // 10^18 因为 ERC20 默认 decimals = 18
        amount = bound(amount, 0, 10000 * 10 ** 18);

        // vm.assume(amount <= token.balanceOf(address(this)));
        // 执行转账
        token.transfer(to, amount);

        // 验证转账后接收方余额等于转账金额
        assertEq(token.balanceOf(to), amount);
    }

}