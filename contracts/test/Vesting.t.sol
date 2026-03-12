// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Vesting.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20 测试代币
 * @dev 用于测试的ERC20代币合约，一次性铸造全部代币给部署者
 */
contract MockERC20 is ERC20 {

    /**
     * @dev 构造函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        // 一次性把所有代币铸造给部署者（msg.sender）
        _mint(msg.sender, initialSupply);
    }

}

/**
 * @title Vesting合约测试套件
 * @dev 全面测试TokenVesting合约的功能
 *
 * 测试覆盖：
 * - 初始状态验证
 * - 锁定期内无法提取
 * - 锁定期后首次释放
 * - 线性释放机制
 * - 完整释放周期
 * - 辅助函数验证
 * - 访问控制验证
 */
contract VestingTest is Test {
    // ==================== 合约实例 ====================
    /// @dev Vesting合约实例
    TokenVesting public vesting;

    /// @dev 测试代币合约实例
    MockERC20 public token;

    // ==================== 测试地址 ====================
    /// @dev 部署者地址（Owner角色）
    address public deployer = address(1);

    /// @dev 受益人地址（代币接收者）
    address public beneficiary = address(2);

    // ==================== 代币常量 ====================
    /// @dev 初始代币供应量：1000万枚
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10 ** 18;

    /// @dev 锁定/释放代币数量：100万枚
    uint256 public constant VESTING_AMOUNT = 1_000_000 * 10 ** 18;

    // ==================== 时间常量 ====================
    /// @dev 一个月（30天）
    uint256 public constant ONE_MONTH = 30 days;

    /// @dev 一年（365天）
    uint256 public constant ONE_YEAR = 365 days;

    /// @dev 锁定期：365天（12个月）
    uint256 public constant CLIFF_DURATION = 365 days;

    /// @dev 线性释放期：730天（24个月）
    uint256 public constant VESTING_DURATION = 730 days;

    // ==================== 测试设置 ====================
    /**
     * @dev 测试前置设置
     *
     * 执行流程：
     * 1. 设置deployer为msg.sender
     * 2. 部署测试代币（MockERC20）
     * 3. 部署Vesting合约
     * 4. 存入代币到Vesting合约
     */
    function setUp() public {
        // 设置deployer为msg.sender
        vm.startPrank(deployer);

        // 部署测试代币
        token = new MockERC20("Test Token", "TEST", INITIAL_SUPPLY);

        // 部署Vesting合约
        vesting = new TokenVesting(IERC20(address(token)), beneficiary);

        // 批准并存入代币到Vesting合约
        token.approve(address(vesting), VESTING_AMOUNT);
        vesting.deposit(VESTING_AMOUNT);

        vm.stopPrank();
    }

    // ==================== 初始状态测试 ====================
    /**
     * @dev 测试Vesting合约初始状态
     *
     * 验证项：
     * - 代币地址正确
     * - 受益人地址正确
     * - 总锁定金额正确
     * - 已释放金额为0
     * - Vesting合约余额正确
     * - 受益人初始余额为0
     */
    function testInitialState() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.totalAmount(), VESTING_AMOUNT);
        assertEq(vesting.releasedAmount(), 0);
        assertEq(token.balanceOf(address(vesting)), VESTING_AMOUNT);
        assertEq(token.balanceOf(beneficiary), 0);
    }

    // ==================== 锁定期测试 ====================
    /**
     * @dev 测试锁定期内无法提取代币
     *
     * 测试场景：
     * 1. 部署后立即尝试提取（应失败）
     * 2. 11个月后尝试提取（仍在锁定期内，应失败）
     *
     * 预期结果：两次提取都应被revert
     */
    function testCannotReleaseBeforeCliff() public {
        // 设置受益人
        vm.startPrank(beneficiary);

        // 尝试在锁定期内提取，应该失败
        vm.expectRevert("No tokens available for release");
        vesting.release();

        // 推进时间但仍在锁定期内（11个月）
        vm.warp(block.timestamp + 11 * ONE_MONTH);

        // 仍然无法提取
        vm.expectRevert("No tokens available for release");
        vesting.release();

        vm.stopPrank();
    }

    /**
     * @dev 测试锁定期结束后的首次释放
     *
     * 测试场景：
     * - 推进到第13个月（锁定期结束后1个月）
     * - 验证首次释放数量为1/24总量
     * - 执行释放并验证结果
     */
    function testReleaseAfterCliff() public {
        // 推进时间到锁定期结束后一个月（13个月）
        vm.warp(block.timestamp + ONE_YEAR + ONE_MONTH);

        // 计算应该释放的数量 (1/24 的总量)
        uint256 expectedRelease = VESTING_AMOUNT / 24;

        // 验证可释放金额（允许2%误差）
        assertApproxEqRel(vesting.getReleasableAmount(), expectedRelease, 0.02e18);

        // 受益人提取代币
        vm.startPrank(beneficiary);
        vesting.release();
        vm.stopPrank();

        // 验证已释放金额和余额
        assertApproxEqRel(vesting.releasedAmount(), expectedRelease, 0.02e18);
        assertApproxEqRel(token.balanceOf(beneficiary), expectedRelease, 0.02e18);
    }

    // ==================== 线性释放测试 ====================
    /**
     * @dev 测试线性释放机制
     *
     * 测试场景：
     * - 循环测试24个月每月的释放量
     * - 验证每月释放量按线性比例增长
     */
    function testLinearRelease() public {
        // 循环测试不同月份的释放量
        for (uint256 i = 0; i < 24; i++) {
            // 跳过锁定期，进入第i+1个月
            uint256 timeToWarp = ONE_YEAR + (i + 1) * ONE_MONTH;
            vm.warp(block.timestamp + timeToWarp);

            // 计算应该释放的总量
            uint256 expectedTotalVested = (i + 1) * VESTING_AMOUNT / 24;

            // 验证已解锁的总量（允许2%误差）
            assertApproxEqRel(vesting.getVestedAmount(), expectedTotalVested, 0.02e18);

            // 重置时间继续下一次循环
            vm.warp(block.timestamp - timeToWarp);
        }
    }

    // ==================== 完整释放周期测试 ====================
    /**
     * @dev 测试完整的释放周期
     *
     * 测试场景：
     * - 在9个关键时间点测试释放
     * - 验证每个时间点的释放金额
     * - 最终验证所有代币完全释放
     */
    function testCompleteVestingSchedule() public {
        // 按照3个月的间隔来测试释放
        uint256[] memory checkpoints = new uint256[](9);
        checkpoints[0] = ONE_YEAR;                       // 12个月（锁定期结束）
        checkpoints[1] = ONE_YEAR + 3 * ONE_MONTH;       // 15个月
        checkpoints[2] = ONE_YEAR + 6 * ONE_MONTH;       // 18个月
        checkpoints[3] = ONE_YEAR + 9 * ONE_MONTH;       // 21个月
        checkpoints[4] = ONE_YEAR + 12 * ONE_MONTH;      // 24个月
        checkpoints[5] = ONE_YEAR + 15 * ONE_MONTH;      // 27个月
        checkpoints[6] = ONE_YEAR + 18 * ONE_MONTH;      // 30个月
        checkpoints[7] = ONE_YEAR + 21 * ONE_MONTH;     // 33个月
        checkpoints[8] = ONE_YEAR + 24 * ONE_MONTH;      // 36个月（完全释放）

        uint256 totalReleased = 0;

        for (uint256 i = 0; i < checkpoints.length; i++) {
            // 跳到指定时间点
            vm.warp(block.timestamp + checkpoints[i]);

            // 计算这个时间点应该已解锁的总量
            uint256 vestedAmount = vesting.getVestedAmount();
            console.log("Expected vested amount:", vestedAmount);

            // 计算可释放的数量
            uint256 releasableAmount = vesting.getReleasableAmount();

            // 如果有可释放的代币，则释放
            if (releasableAmount > 0) {
                vm.startPrank(beneficiary);
                vesting.release();
                vm.stopPrank();

                totalReleased += releasableAmount;

                // 验证已释放的总量和受益人的余额
                assertEq(vesting.releasedAmount(), totalReleased);
                assertEq(token.balanceOf(beneficiary), totalReleased);
            }

            // 重置时间继续下一次循环
            vm.warp(block.timestamp - checkpoints[i]);
        }

        // 最后一次检查，应该全部释放
        vm.warp(block.timestamp + ONE_YEAR + VESTING_DURATION);

        // 受益人提取剩余代币
        vm.startPrank(beneficiary);
        vesting.release();
        vm.stopPrank();

        // 验证所有代币都已释放
        assertEq(vesting.releasedAmount(), VESTING_AMOUNT);
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT);
        assertEq(vesting.getReleasableAmount(), 0);
        assertEq(vesting.getRemainingAmount(), 0);
        assertTrue(vesting.isFullyVested());
    }

    // ==================== 辅助函数测试 ====================
    /**
     * @dev 测试辅助查询函数
     *
     * 验证辅助函数在：
     * - 初始状态
     * - 锁定期结束时刻
     * - 释放中期（50%）
     * - 完全释放（100%）
     *
     * 返回值的正确性
     */
    function testHelperFunctions() public {
        // 检查初始状态下的辅助函数
        assertEq(vesting.getDaysFromStart(), 0);
        assertEq(vesting.getDaysUntilCliff(), 365);
        assertFalse(vesting.isCliffPassed());
        assertFalse(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 0);

        // 推进到锁定期结束
        vm.warp(block.timestamp + ONE_YEAR);

        // 检查锁定期结束时的辅助函数
        assertEq(vesting.getDaysFromStart(), 365);
        assertEq(vesting.getDaysUntilCliff(), 0);
        assertTrue(vesting.isCliffPassed());
        assertFalse(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 0);

        // 推进到锁定期结束后中间阶段（24个月，即50%进度）
        vm.warp(2 * (block.timestamp + ONE_YEAR));

        // 检查中间阶段的辅助函数
        assertEq(vesting.getDaysFromStart(), 730);
        assertEq(vesting.getDaysUntilCliff(), 0);
        assertTrue(vesting.isCliffPassed());
        assertFalse(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 5000); // 50%

        // 推进到完全释放（36个月）
        vm.warp(block.timestamp + 3 * ONE_YEAR);

        // 检查完全释放时的辅助函数
        assertTrue(vesting.isCliffPassed());
        assertTrue(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 10000); // 100%
    }

    // ==================== 访问控制测试 ====================
    /**
     * @dev 测试访问控制：非受益人无法提取代币
     *
     * 验证只有beneficiary地址可以调用release()
     */
    function testOnlyBeneficiaryCanRelease() public {
        // 推进到有可释放代币的时间点（18个月）
        vm.warp(block.timestamp + ONE_YEAR + 6 * ONE_MONTH);

        // 非受益人尝试提取
        vm.startPrank(deployer);
        vm.expectRevert("Only beneficiary can release tokens");
        vesting.release();
        vm.stopPrank();
    }
}