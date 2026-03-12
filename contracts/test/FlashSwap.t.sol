// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/FlashSwap.sol";

/// @dev Uniswap V2 回调接口
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

/**
 * @title MockERC20
 * @dev 用于测试的 ERC20 代币
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @dev 铸造代币
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /// @dev 销毁代币
    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

/**
 * @title MockUniswapV2Pair
 * @dev 用于测试的 Mock Uniswap V2 配对合约
 *      模拟闪电贷功能
 */
contract MockUniswapV2Pair is IUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        reserve0 = 0;
        reserve1 = 0;
        blockTimestampLast = uint32(block.timestamp);
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
            if (amount0Out > 0) MockERC20(token0).transfer(to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) MockERC20(token1).transfer(to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) {
                // 假设to地址实现了uniswapV2Call回调函数
                // 这个函数会被FlashSwap等合约实现，用于处理闪贷逻辑
                (bool success,) = to.call(abi.encodeWithSignature("uniswapV2Call(address,uint256,uint256,bytes)",
                    msg.sender, amount0Out, amount1Out, data));
                require(success, "Uniswap V2 callback failed");
            }
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint(_reserve0) * _reserve1 * 1000 ** 2, 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 仅测试，不做任何操作
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
    }
}

/**
 * @title MockUniswapV2Factory
 * @dev 用于测试的 Mock Uniswap V2 工厂合约
 */
contract MockUniswapV2Factory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function setPair(address tokenA, address tokenB, address pair) external {
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair; // Uniswap V2 工厂函数是双向对称的
    }
}

/**
 * @title MockUniswapV2Router
 * @dev 用于测试的 Mock Uniswap V2 路由合约
 */
contract MockUniswapV2Router is IUniswapV2Router02 {
    /// @dev 根据输入数量和储备计算输出数量（Uniswap V2 公式）
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
}

/**
 * @title FlashSwapTest
 * @dev FlashSwap 合约的测试套件
 *      测试闪电贷套利功能
 */
contract FlashSwapTest is Test {
    FlashSwap public flashSwap;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockUniswapV2Pair public poolA;
    MockUniswapV2Pair public poolB;
    MockUniswapV2Factory public factory;
    MockUniswapV2Router public router;

    address public owner;

    function setUp() public {
        // 部署代币
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");

        // 部署工厂和路由器
        factory = new MockUniswapV2Factory();
        router = new MockUniswapV2Router();

        // 部署配对合约
        poolA = new MockUniswapV2Pair(address(tokenA), address(tokenB));
        poolB = new MockUniswapV2Pair(address(tokenA), address(tokenB));

        // 设置工厂中的配对信息
        factory.setPair(address(tokenA), address(tokenB), address(poolA));

        // 设置初始储备 (pairA: 1A = 1000B, 即 1:1000 的比例)
        // 设置为 1000000 A 和 1000000000 B (比例为 1:1000)
        tokenA.mint(address(poolA), 1000000);
        tokenB.mint(address(poolA), 1000000000);
        poolA.setReserves(1000000, 1000000000);

        // 设置pairB的储备 (pairB: 1A = 1300B, 即 1:1300 的比例)
        // 设置为 1000000 A 和 1300000000 B (比例为 1:1300)
        tokenA.mint(address(poolB), 1000000);
        tokenB.mint(address(poolB), 1300000000);
        poolB.setReserves(1000000, 1300000000);

        // 部署FlashSwapTestable合约
        flashSwap = new FlashSwap();

        // 设置模拟的工厂和路由器地址
        flashSwap.setUniswapAddresses(address(factory), address(router));

        // 将FlashSwapTestable合约的owner设置为测试合约（当前this）
        // flashSwap合约的当前owner是部署合约时的msg.sender（也就是FlashSwapTest合约）
        // 因此owner变量应该设置为FlashSwapTest合约的地址
        owner = address(this);
    }

    function testFlashSwapArbitrage() public {
        // 测试用例：验证FlashSwap套利交易逻辑
        // 场景：pairA中1A=1000B， pairB中1A=1300B
        // 从pairA借出来100个A，在pairB中用100个A兑换B代币，再在pairA中将B换成A还回去

        // 记录初始状态
        uint256 initialTokenABalance = tokenA.balanceOf(owner);
        uint256 initialTokenBBalance = tokenB.balanceOf(owner);

        console.log("Initial A Balance:", initialTokenABalance);
        console.log("Initial B Balance:", initialTokenBBalance);

        // 调用FlashSwap合约进行套利交易
        // 从poolA借A代币，在poolB中进行套利
        flashSwap.executeFlashSwap(
            address(poolA),     // 从poolA借A代币
            address(poolB),     // 在poolB中进行套利
            address(tokenA),    // 借贷的代币是A
            address(tokenB),    // 交换的目标代币是B
            100                 // 借贷数量是100
        );

        // 检查是否获利
        uint256 finalTokenABalance = tokenA.balanceOf(owner);
        uint256 finalTokenBBalance = tokenB.balanceOf(owner);

        console.log("Final A Balance:", finalTokenABalance);
        console.log("Final B Balance:", finalTokenBBalance);
        console.log("A Balance Change:", int(finalTokenABalance) - int(initialTokenABalance));
        console.log("B Balance Change:", int(finalTokenBBalance) - int(initialTokenBBalance));

        // 验证最终的B代币余额有所增加（套利获利）
        // 初始B代币余额应该加上最终收益等于最终B代币余额
        assertGt(finalTokenBBalance, initialTokenBBalance);

        // 输出日志显示获利结果
        console.log("B Token Profit:", finalTokenBBalance - initialTokenBBalance);
    }
}