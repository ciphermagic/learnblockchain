// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {AbiEncode, AbiDecode} from "../src/AbiEncode_Decode.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AbiEncodeDecodeTest
 * @notice ABI 编码解码功能的完整测试套件
 * @dev 测试覆盖：
 *      1. 四种编码方式的正确性验证
 *      2. 复杂数据结构的编码解码
 *      3. 模糊测试确保边界情况的正确性
 *
 * 测试策略：
 * - 单元测试：验证每种编码方式的基本功能
 * - 集成测试：验证编码解码的完整流程
 * - 模糊测试：使用随机输入验证健壮性
 *
 * 运行测试：
 * forge test --match-contract AbiEncodeDecodeTest -vvv
 */
contract AbiEncodeDecodeTest is Test {
    // ============ 测试合约实例 ============

    /// @notice ABI 编码测试合约
    AbiEncode public abiEncode;

    /// @notice ABI 解码测试合约
    AbiDecode public abiDecode;

    // ============ 测试初始化 ============

    /**
     * @notice 测试前的初始化设置
     * @dev 在每个测试函数执行前自动调用
     *      部署新的合约实例，确保测试隔离
     */
    function setUp() public {
        abiEncode = new AbiEncode();
        abiDecode = new AbiDecode();
    }

    // ============ 编码方式测试 ============

    /**
     * @notice 测试 encodeWithSignature 编码方式
     * @dev 验证使用字符串签名编码的正确性
     *
     * 测试要点：
     * 1. 编码生成的数据包含正确的函数选择器
     * 2. 函数选择器是函数签名的 keccak256 哈希的前 4 字节
     *
     * 注意：此方法不安全，仅用于演示
     */
    function test_EncodeWithSignature() public {
        // 准备测试数据
        address to = address(0x123);
        uint256 amount = 100;

        // 调用编码函数
        bytes memory encoded = abiEncode.encodeWithSignature(to, amount);
        console.logBytes(encoded);

        // 验证编码结果：检查函数选择器（前 4 字节）
        // 函数选择器 = keccak256("transfer(address,uint256)") 的前 4 字节
        bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
        bytes4 encodedSelector = bytes4(encoded);

        assertEq(selector, encodedSelector, "Function selector mismatch");
    }

    /**
     * @notice 测试 encodeWithSelector 编码方式
     * @dev 验证使用函数选择器编码的正确性
     *
     * 测试要点：
     * 1. 使用接口定义的选择器进行编码
     * 2. 编码结果的函数选择器与接口定义一致
     *
     * 优势：比 encodeWithSignature 更安全，避免拼写错误
     */
    function test_EncodeWithSelector() public {
        // 准备测试数据
        address to = address(0x123);
        uint256 amount = 100;

        // 调用编码函数
        bytes memory encoded = abiEncode.encodeWithSelector(to, amount);
        console.logBytes(encoded);

        // 验证编码结果：检查函数选择器
        // 使用接口定义的选择器，确保一致性
        bytes4 selector = IERC20.transfer.selector;
        bytes4 encodedSelector = bytes4(encoded);

        assertEq(selector, encodedSelector, "Function selector mismatch");
        console.log("encodeWithSelector test passed");
    }

    /**
     * @notice 测试 encodeCall 编码方式（推荐）
     * @dev 验证类型安全编码的正确性
     *
     * 测试要点：
     * 1. 使用类型安全的编码方式
     * 2. 编译器会检查函数签名和参数类型
     * 3. 编码结果与其他方式一致
     *
     * 最佳实践：生产环境应优先使用此方法
     */
    function test_EncodeCall() public {
        // 准备测试数据
        address to = address(0x123);
        uint256 amount = 100;

        // 调用编码函数
        bytes memory encoded = abiEncode.encodeCall(to, amount);
        console.logBytes(encoded);

        // 验证编码结果：检查函数选择器
        bytes4 selector = IERC20.transfer.selector;
        bytes4 encodedSelector = bytes4(encoded);

        assertEq(selector, encodedSelector, "Function selector mismatch");
        console.log("encodeCall test passed");
    }

    /**
     * @notice 测试基础参数编码
     * @dev 验证 abi.encode 的正确性
     *
     * 测试要点：
     * 1. 只编码参数，不包含函数选择器
     * 2. 编码后可以正确解码
     * 3. 解码结果与原始数据一致
     *
     * 应用场景：构造复杂调用数据、存储编码数据
     */
    function test_EncodeParameter() public {
        // 准备测试数据
        address to = address(0x123);
        uint256 amount = 100;

        // 调用编码函数
        bytes memory encoded = abiEncode.encodeParameter(to, amount);
        console.logBytes(encoded);

        // 解码参数以验证编码正确性
        (address decodedTo, uint256 decodedAmount) = abi.decode(encoded, (address, uint256));

        // 验证解码结果与原始数据一致
        assertEq(to, decodedTo, "Address mismatch");
        assertEq(amount, decodedAmount, "Amount mismatch");
        console.log("encodeParameter test passed");
    }

    // ============ 复杂数据结构测试 ============

    /**
     * @notice 测试复杂数据结构的编码和解码
     * @dev 验证包含结构体、数组等复杂类型的完整编码解码流程
     *
     * 测试数据类型：
     * - uint256: 基础整数类型
     * - address: 地址类型
     * - uint256[]: 动态长度数组
     * - MyStruct: 自定义结构体（包含 string 和固定长度数组）
     *
     * 测试流程：
     * 1. 准备包含多种类型的测试数据
     * 2. 使用 encode 函数编码所有数据
     * 3. 使用 decode 函数解码编码后的数据
     * 4. 逐一验证解码结果与原始数据一致
     *
     * 验证要点：
     * - 基础类型的正确性
     * - 动态数组的长度和元素
     * - 结构体的所有字段
     */
    function test_EncodeAndDecode() public {
        // ========== 准备测试数据 ==========

        // 基础类型
        uint256 x = 42;
        address addr = address(0x456);

        // 动态数组
        uint256[] memory arr = new uint256[](3);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;

        // 自定义结构体
        AbiDecode.MyStruct memory myStruct = AbiDecode.MyStruct({
            name: "test",
            nums: [uint256(10), uint256(20)]
        });

        // ========== 编码数据 ==========
        bytes memory encoded = abiDecode.encode(x, addr, arr, myStruct);

        // ========== 解码数据 ==========
        (uint256 decodedX, address decodedAddr, uint256[] memory decodedArr, AbiDecode.MyStruct memory decodedStruct) =
            abiDecode.decode(encoded);

        // ========== 验证解码结果 ==========

        // 验证基础类型
        assertEq(x, decodedX, "Uint256 mismatch");
        assertEq(addr, decodedAddr, "Address mismatch");

        // 验证动态数组
        assertEq(arr.length, decodedArr.length, "Array length mismatch");
        for (uint i = 0; i < arr.length; i++) {
            assertEq(arr[i], decodedArr[i], "Array element mismatch");
        }

        // 验证结构体字段
        assertEq(myStruct.name, decodedStruct.name, "Struct name mismatch");
        assertEq(myStruct.nums[0], decodedStruct.nums[0], "Struct nums[0] mismatch");
        assertEq(myStruct.nums[1], decodedStruct.nums[1], "Struct nums[1] mismatch");

        console.log("encode and decode test passed");
    }

    // ============ 模糊测试 ============

    /**
     * @notice 模糊测试参数编码功能
     * @param to 随机生成的地址
     * @param amount 随机生成的数量
     * @dev 使用 Foundry 的模糊测试功能，自动生成随机输入
     *
     * 模糊测试优势：
     * - 自动生成大量随机测试用例
     * - 发现边界情况和异常输入
     * - 提高测试覆盖率
     *
     * 测试约束：
     * - 排除零地址（vm.assume）
     * - 验证任意有效输入的编码解码正确性
     *
     * 运行方式：
     * forge test --match-test testFuzz_EncodeParameter -vvv
     */
    function testFuzz_EncodeParameter(address to, uint256 amount) public {
        // 排除零地址（业务逻辑通常不允许零地址）
        vm.assume(to != address(0));

        // 编码参数
        bytes memory encoded = abiEncode.encodeParameter(to, amount);

        // 解码并验证
        (address decodedTo, uint256 decodedAmount) = abi.decode(encoded, (address, uint256));

        // 断言：解码结果必须与原始输入完全一致
        assertEq(to, decodedTo, "Address mismatch");
        assertEq(amount, decodedAmount, "Amount mismatch");
    }
}