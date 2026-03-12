// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Fork 测试套件
 * @notice 测试 Foundry 的网络 Fork 功能
 * @dev 允许在测试环境中模拟真实区块链网络状态
 *
 * Fork 模式优势：
 * - 可以与真实部署的合约进行交互测试
 * - 无需支付真实 Gas 费用
 * - 测试环境与生产环境一致
 * - 可以回滚和重放测试
 *
 * Fork 模式限制：
 * - 需要 RPC URL 配置（通过 forge.toml 或环境变量）
 * - 某些链状态可能不稳定（跨链桥、代币流动性等）
 * - 大量 fork 测试可能产生网络请求延迟
 */
import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {Owner} from "../src/Owner.sol";
import {BaseERC20} from "../src/BaseERC20.sol";

/**
 * @title ForkTest
 * @notice 测试 Foundry 的 Fork 功能
 * @dev 演示如何创建、切换和测试真实网络的 fork
 *
 * Fork 使用场景：
 * 1. 集成测试：与已部署的合约交互
 * 2. 场景回放：重现链上发生的特定事件
 * 3. 升级测试：在真实状态上测试合约升级
 * 4. 行为验证：验证合约在真实网络环境中的行为
 *
 * 注意事项：
 * - 需要在 foundry.toml 中配置 rpcEndpoints.sepolia
 * - 或设置 FORK_URL_xxx 环境变量
 * - 过度使用 fork 可能导致测试运行缓慢
 */
contract ForkTest is Test {
    Counter public counter;
    address public alice;
    address public bob;
    uint256 public sepoliaForkId;  // 存储 fork 的唯一标识符

    /**
     * @notice 初始化测试，创建 Sepolia 测试网的 fork
     * @dev createSelectFork 创建 fork 并立即切换到该 fork
     *      也可以使用 createFork 创建 fork，然后手动 selectFork 切换
     *
     * 说明：
     * - forkBlock 指定从哪个区块开始 fork（可以回溯到历史状态）
     * - 使用较早的区块可以提高测试速度，但状态可能不同
     */
    function setUp() public {
        uint256 forkBlock = 8219000;  // Sepolia 网络的特定区块号
        // vm.rpcUrl("sepolia"): 从配置中获取 Sepolia 网络的 RPC URL
        // createSelectFork: 创建 fork 并立即切换到该 fork 环境
        sepoliaForkId = vm.createSelectFork(vm.rpcUrl("sepolia"), forkBlock);
    }

    /**
     * @notice 测试在 Sepolia Fork 环境中与真实合约交互
     * @dev 本测试连接到 Sepolia 网络的 fork，验证合约状态
     *
     * Fork 测试工作流程：
     * 1. createSelectFork: 创建并切换到 fork
     * 2. selectFork: 在不同 fork 之间切换（如需）
     * 3. activeFork: 获取当前活跃的 fork ID
     * 4. rollFork: 在 fork 中滚动到新区块
     *
     * @dev 测试逻辑：
     * - 切换到预先创建的 Sepolia fork
     * - 使用已部署的 BaseERC20 合约地址（Sepolia 网络）
     * - 验证特定地址的代币余额
     */
    function test_Sepolia() public {
        // 切换到之前创建的 Sepolia fork
        vm.selectFork(sepoliaForkId);
        // 验证当前活跃的 fork 确实是我们的 sepoliaForkId
        assertEq(vm.activeFork(), sepoliaForkId);

        // 使用 Sepolia 网络上已部署的 BaseERC20 合约
        // 合约地址: 0x21b4D1f6d42dc6083db848D42AA4b6895371E1e7
        BaseERC20 token = BaseERC20(0x21b4D1f6d42dc6083db848D42AA4b6895371E1e7);

        // 验证地址 0xe7a4159Be8c74c3BB38A45B31cF59889EF3F32b7 的代币余额 >= 1e18
        // assertGe: assert greater than or equal（大于等于）
        assertGe(token.balanceOf(0xe7a4159Be8c74c3BB38A45B31cF59889EF3F32b7), 1e18);
    }
}