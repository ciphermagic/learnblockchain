// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ABI 编码与解码示例合约
 * @notice 演示 Solidity 中多种 ABI 编码和解码方法的使用
 * @dev 包含两个合约：
 *      1. AbiEncode - 演示 4 种编码方式及其优缺点
 *      2. AbiDecode - 演示复杂数据结构的编码和解码
 *
 * 知识点：
 * - abi.encodeWithSignature: 使用字符串签名（不安全，无编译时检查）
 * - abi.encodeWithSelector: 使用函数选择器（部分安全，无类型检查）
 * - abi.encodeCall: 类型安全编码（推荐，有完整编译时检查）
 * - abi.encode/decode: 基础编码解码
 */

// ERC20 代币合约地址示例: 0x5FbDB2315678afecb367f032d93F642f64180aa3
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AbiEncode
 * @notice 演示多种 ABI 编码方式，用于构造函数调用数据
 * @dev 部署命令示例：
 *      forge create src/testAbiEncode_Decode.sol:AbiEncode \
 *        --rpc-url local \
 *        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
 *        --broadcast
 *      部署后地址: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
 */
contract AbiEncode {

    /**
     * @notice 转发调用到目标合约（通用代理调用）
     * @param _contract 目标合约地址
     * @param data 已编码的函数调用数据
     * @dev 使用低级 call 转发调用，并正确处理 revert 原因
     *
     * 使用示例：
     * cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
     *   "forwardCall(address,bytes)" \
     *   0x5FbDB2315678afecb367f032d93F642f64180aa3 \
     *   0xa9059cbb00000000000000000000000000000000000000000000000000000000000012340000000000000000000000000000000000000000000000000000000000000064 \
     *   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
     *
     * 技术要点：
     * - 使用 call 进行低级调用
     * - 通过 assembly 正确传递 revert 原因
     * - 适用于代理合约、多签钱包等场景
     */
    function forwardCall(address _contract, bytes calldata data) external {
        // 执行低级调用
        (bool ok, bytes memory ret) = _contract.call(data);

        if (!ok) {
            // 如果调用失败，解码并传递底层 revert 原因
            if (ret.length > 0) {
                // 使用 assembly 直接 revert，保留原始错误信息
                // ret 的内存布局：[长度(32字节)][数据...]
                // add(ret, 0x20) 跳过长度字段，指向实际数据
                // mload(ret) 读取数据长度
                assembly { revert(add(ret, 0x20), mload(ret)) }
            } else {
                // 如果没有返回数据，使用通用错误信息
                revert("call failed (no revert reason)");
            }
        }
    }

    /**
     * @notice 使用函数签名字符串编码调用数据（方式1：不推荐）
     * @param to 接收地址
     * @param amount 转账数量
     * @return 编码后的调用数据
     * @dev ⚠️ 不安全：函数签名是字符串，编译器不检查拼写错误
     *
     * 使用示例：
     * cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 \
     *   "encodeWithSignature(address,uint256)(bytes)" \
     *   0x0000000000000000000000000000000000001234 100
     *
     * 缺点：
     * - 函数名拼写错误不会被编译器发现
     * - 参数类型错误不会被编译器发现
     * - 运行时才能发现错误，增加风险
     *
     * 示例错误（编译通过但运行时失败）：
     * - "tranfer(address,uint256)" // 拼写错误
     * - "transfer(address,uint)" // 类型不精确
     */
    function encodeWithSignature(address to, uint256 amount)
    external
    pure
    returns (bytes memory)
    {
        // 注意：即使写成 "transfer(address, uint)" 也能编译通过
        // 但可能导致运行时错误或意外行为
        return abi.encodeWithSignature("transfer(address,uint256)", to, amount);
    }

    /**
     * @notice 使用函数选择器编码调用数据（方式2：部分安全）
     * @param to 接收地址
     * @param amount 转账数量
     * @return 编码后的调用数据
     * @dev ⚠️ 部分安全：选择器正确，但参数类型不检查
     *
     * 使用示例：
     * cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 \
     *   "encodeWithSelector(address,uint256)(bytes)" \
     *   0x0000000000000000000000000000000000001234 100
     *
     * 优点：
     * - 使用接口定义的选择器，避免函数名拼写错误
     * - 比 encodeWithSignature 更安全
     *
     * 缺点：
     * - 参数类型不检查，可能传入错误类型
     * - 例如：(IERC20.transfer.selector, true, amount) 能编译通过
     *   但 true 不是 address 类型，会导致运行时错误
     */
    function encodeWithSelector(address to, uint256 amount)
    external
    pure
    returns (bytes memory)
    {
        // 使用接口的函数选择器，避免拼写错误
        // 但参数类型错误不会被检查
        return abi.encodeWithSelector(IERC20.transfer.selector, to, amount);
    }

    /**
     * @notice 使用类型安全的方式编码调用数据（方式3：✅ 推荐）
     * @param to 接收地址
     * @param amount 转账数量
     * @return 编码后的调用数据
     * @dev ✅ 最安全：编译器完整检查函数签名和参数类型
     *
     * 使用示例：
     * cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 \
     *   "encodeCall(address,uint256)(bytes)" \
     *   0x0000000000000000000000000000000000001234 100
     *
     * 优点（推荐使用）：
     * - ✅ 函数名拼写错误会导致编译失败
     * - ✅ 参数类型错误会导致编译失败
     * - ✅ 参数数量错误会导致编译失败
     * - ✅ 完全的编译时类型安全
     *
     * 对比其他方式：
     * - encodeWithSignature: 无任何编译时检查
     * - encodeWithSelector: 只检查函数存在，不检查参数类型
     * - encodeCall: 完整的编译时检查（最佳实践）
     */
    function encodeCall(address to, uint256 amount)
    external
    pure
    returns (bytes memory)
    {
        // 使用 abi.encodeCall 提供完整的类型安全
        // 任何拼写错误或类型错误都会导致编译失败
        return abi.encodeCall(IERC20.transfer, (to, amount));
    }

    /**
     * @notice 基础参数编码（方式4：通用编码）
     * @param to 接收地址
     * @param amount 转账数量
     * @return 编码后的参数数据（不包含函数选择器）
     * @dev 使用 abi.encode 进行基础的参数编码
     *
     * 使用示例：
     * cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 \
     *   "encodeParameter(address,uint256)(bytes)" \
     *   0x0000000000000000000000000000000000001234 100
     *
     * 特点：
     * - 只编码参数，不包含函数选择器
     * - 适用于需要传递编码数据的场景
     * - 常用于构造复杂的调用数据或存储数据
     *
     * 与其他编码方式的区别：
     * - abi.encode: 只编码参数
     * - abi.encodeWithSelector: 包含函数选择器 + 参数
     * - abi.encodeCall: 类型安全的选择器 + 参数
     */
    function encodeParameter(address to, uint256 amount) public pure returns (bytes memory){
        // 基础编码，只编码参数本身
        return abi.encode(to, amount);
    }
}

/**
 * @title AbiDecode
 * @notice 演示复杂数据结构的 ABI 编码和解码
 * @dev 展示如何处理包含结构体、数组等复杂类型的编码解码
 *
 * 应用场景：
 * - 跨合约调用时传递复杂数据
 * - 链下签名数据的编码解码
 * - 事件日志的数据解析
 */
contract AbiDecode {
    /**
     * @notice 自定义结构体示例
     * @dev 包含字符串和固定长度数组
     */
    struct MyStruct {
        string name;      // 动态长度字符串
        uint256[2] nums;  // 固定长度数组（2个元素）
    }

    /**
     * @notice 编码复杂数据结构
     * @param x 普通整数
     * @param addr 地址类型
     * @param arr 动态长度数组
     * @param myStruct 自定义结构体
     * @return 编码后的字节数据
     * @dev 演示如何编码多种类型的数据
     *
     * 编码规则：
     * - 基础类型（uint, address）：直接编码为 32 字节
     * - 动态类型（string, bytes, 动态数组）：编码为偏移量 + 长度 + 数据
     * - 结构体：按字段顺序递归编码
     * - 固定数组：连续编码所有元素
     */
    function encode(
        uint256 x,
        address addr,
        uint256[] calldata arr,
        MyStruct calldata myStruct
    ) external pure returns (bytes memory) {
        // abi.encode 会按照 ABI 规范编码所有参数
        return abi.encode(x, addr, arr, myStruct);
    }

    /**
     * @notice 解码复杂数据结构
     * @param data 编码后的字节数据
     * @return x 解码后的整数
     * @return addr 解码后的地址
     * @return arr 解码后的动态数组
     * @return myStruct 解码后的结构体
     * @dev 演示如何解码多种类型的数据
     *
     * 解码要点：
     * - 必须指定正确的类型顺序和类型
     * - 类型不匹配会导致解码失败或数据错误
     * - 可以使用元组解构语法简化代码
     *
     * 使用示例：
     * 1. 先调用 encode 获取编码数据
     * 2. 将编码数据传入 decode 进行解码
     * 3. 验证解码结果与原始数据一致
     */
    function decode(bytes calldata data)
    external
    pure
    returns (
        uint256 x,
        address addr,
        uint256[] memory arr,
        MyStruct memory myStruct
    )
    {
        // 使用 abi.decode 解码数据
        // 必须指定正确的类型列表，顺序和类型必须与编码时一致
        (x, addr, arr, myStruct) =
        abi.decode(data, (uint256, address, uint256[], MyStruct));
    }
}