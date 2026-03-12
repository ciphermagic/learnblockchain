// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "forge-std/console.sol";

/// @dev Uniswap V2 配对合约接口
interface IUniswapV2Pair {
  function token0() external view returns (address);

  function token1() external view returns (address);

  /// @dev 闪电贷回调函数
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

/// @dev Uniswap V2 工厂合约接口
interface IUniswapV2Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/// @dev Uniswap V2 路由合约接口
interface IUniswapV2Router02 {
  /// @dev 根据输入数量和储备计算输出数量
  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);

  /// @dev 根据输出数量和储备计算所需输入数量
  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
}

/**
 * @title FlashSwap
 * @dev 闪电兑换套利合约
 *      利用不同 DEX 池子间的价格差异进行套利
 *      通过闪电贷（Flash Loan）模式借款，无需抵押物
 *
 * 套利流程：
 * 1. 从 poolA 闪电贷出代币 A
 * 2. 在 poolB 中将 A 兑换为 B
 * 3. 在 poolA 中将部分 B 兑换为 A 用于还款
 * 4. 剩余的 B 即为套利利润
 *
 * @notice 该合约仅用于演示和学习，实际使用需自行承担风险
 */
contract FlashSwap {
  /// @dev Uniswap V2 工厂合约地址
  address public uniswapV2Factory;
  /// @dev Uniswap V2 路由合约地址
  address public uniswapV2Router;

  /// @dev 合约所有者地址
  address public owner;

  /// @dev 闪电兑换执行完成事件
  event FlashSwapExecuted(
    address indexed poolA,
    address indexed poolB,
    address tokenA,
    address tokenB,
    uint256 amountBorrowed,
    uint256 profit
  );

  /// @dev 仅所有者修饰符
  modifier onlyOwner() {
    require(msg.sender == owner, 'Not owner');
    _;
  }

  /// @dev 构造函数
  constructor() {
    // 设置默认的 Uniswap V2 主网地址（可用于主网测试）
    uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    owner = msg.sender;
  }

  /**
   * @dev 设置 Uniswap 工厂和路由合约地址
   * @param factory 工厂合约地址
   * @param router 路由合约地址
   * @notice 仅用于测试环境设置 Mock 地址
   */
  function setUniswapAddresses(address factory, address router) external onlyOwner {
    uniswapV2Factory = factory;
    uniswapV2Router = router;
  }

  /**
   * @dev 执行闪电兑换套利
   * @param poolA 价格较低的池子（从这里借款）
   * @param poolB 价格较高的池子（在这里套利）
   * @param tokenA 要借贷的代币
   * @param tokenB 要交换的目标代币
   * @param amountToBorrow 借贷数量
   * @notice 调用此函数会触发闪电贷，在 uniswapV2Call 回调中完成套利
   */
  function executeFlashSwap(
    address poolA, // 价格较低的池子
    address poolB, // 价格较高的池子
    address tokenA, // 要借贷的代币
    address tokenB, // 要交换的代币
    uint256 amountToBorrow // 借贷数量
  ) external onlyOwner {
    // 验证池子地址
    require(poolA != address(0) && poolB != address(0), 'Invalid pool addresses');

    // 从 poolA 开始闪电贷
    IUniswapV2Pair pair = IUniswapV2Pair(poolA);
    address token0 = pair.token0();
    address token1 = pair.token1();

    // 确定输出方向
    uint256 amount0Out = tokenA == token0 ? amountToBorrow : 0;
    uint256 amount1Out = tokenA == token1 ? amountToBorrow : 0;

    // 编码数据传递给回调函数（poolB、tokenA、tokenB、amountToBorrow）
    bytes memory data = abi.encode(poolB, tokenA, tokenB, amountToBorrow);

    // 执行闪电贷（触发 uniswapV2Call 回调）
    pair.swap(amount0Out, amount1Out, address(this), data);
  }

  /**
   * @dev Uniswap V2 回调函数
   * @param sender 调用 swap 的地址（本合约）
   * @param amount0 输出的 token0 数量
   * @param amount1 输出的 token1 数量
   * @param data 附加数据（包含 poolB 信息）
   * @notice 这是套利的核心逻辑：借款 -> 兑换 -> 还款 -> 获利
   */
  function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
    // 验证调用者是合法的 Uniswap V2 配对合约
    address token0 = IUniswapV2Pair(msg.sender).token0();
    address token1 = IUniswapV2Pair(msg.sender).token1();
    address pair = IUniswapV2Factory(uniswapV2Factory).getPair(token0, token1);
    require(msg.sender == pair, 'Invalid pair');
    require(sender == address(this), 'Invalid sender');

    // 解码数据
    (address poolB, address _tokenA, address _tokenB, uint256 amountBorrowed) = abi.decode(
      data,
      (address, address, address, uint256)
    );

    // 获取借到的代币数量
    console.log(">>>>>>>>>>>>>>>>> Borrowed tokenA", amountBorrowed);
    uint256 amountReceived = amount0 > 0 ? amount0 : amount1;
    console.log(">>>>>>>>>>>>>>>>> Expected TokenA:", amountReceived);
    console.log(">>>>>>>>>>>>>>>>> Received TokenA:", IERC20(_tokenA).balanceOf(address(this)));


    // 在 poolB 中将 tokenA 兑换为 tokenB（套利步骤）
    console.log(">>>>>>>>>>>>>>>>> In poolB, exchange tokenA to tokenB");
    _swapOnPool(poolB, _tokenA, _tokenB, amountReceived);
    console.log(">>>>>>>>>>>>>>>>> Received TokenB:", IERC20(_tokenB).balanceOf(address(this)));

    // 计算需要还款的数量（包含 0.3% 手续费）
    uint256 amountToRepay = _calculateRepayAmount(amountBorrowed);
    console.log(">>>>>>>>>>>>>>>>> Need repay TokenA:", amountToRepay);

    // 计算需要多少 tokenB 才能换回所需的 tokenA 用于还款
    uint256 amountToSwapBack = _calculateAmountToSwapBack(msg.sender, _tokenB, amountToRepay);
    console.log(">>>>>>>>>>>>>>>>> Need repay TokenB for TokenA in poolA:", amountToSwapBack);

    // 检查我们是否有足够多的 tokenB 用于偿还 tokenA
    uint256 balanceOfTokenB = IERC20(_tokenB).balanceOf(address(this));
    require(balanceOfTokenB >= amountToSwapBack, 'Insufficient tokenB for repayment');
    console.log(">>>>>>>>>>>>>>>>> balanceOfTokenB:", IERC20(_tokenB).balanceOf(address(this)));

    // 将 tokenB 转给配对合约 poolA 用于还款
    // 配对合约会将其与持有的 tokenA 进行交换，验证还款是否成功
    IERC20(_tokenB).transfer(msg.sender, amountToSwapBack);

    // 计算利润（剩余的 tokenB）
    uint256 remainingTokenB = IERC20(_tokenB).balanceOf(address(this));
    console.log(">>>>>>>>>>>>>>>>> Remaining TokenB:", remainingTokenB);

    // 将剩余代币转给 owner（套利利润）
    if (remainingTokenB > 0) {
      IERC20(_tokenB).transfer(owner, remainingTokenB);
    }

    emit FlashSwapExecuted(msg.sender, poolB, _tokenA, _tokenB, amountBorrowed, remainingTokenB);
  }

  /**
   * @dev 在指定池子执行兑换
   * @param pool 池子地址
   * @param tokenIn 输入代币地址
   * @param tokenOut 输出代币地址
   * @param amountIn 输入数量
   */
  function _swapOnPool(address pool, address tokenIn, address tokenOut, uint256 amountIn) internal {
    IUniswapV2Pair pair = IUniswapV2Pair(pool);
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

    address _token0 = pair.token0();

    bool token0IsTokenIn = tokenIn == _token0;

    // 确定储备方向
    (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? (reserve0, reserve1) : (reserve1, reserve0);

    // 计算输出数量
    uint256 amountOut = IUniswapV2Router02(uniswapV2Router).getAmountOut(amountIn, reserveIn, reserveOut);
    console.log(">>>>>>>>>>>>>>>>> Expected TokenB:", amountOut);

    // 转移代币到配对合约
    IERC20(tokenIn).transfer(pool, amountIn);

    // 执行交换
    uint256 amount0Out = tokenOut == _token0 ? amountOut : 0;
    uint256 amount1Out = tokenOut == _token0 ? 0 : amountOut;

    pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
  }

  /**
   * @dev 计算需要交换回去的数量（反向计算）
   * @param pool 池子地址
   * @param tokenIn 输入代币地址
   * @param amountOutNeeded 需要的输出数量
   * @return amountIn 需要的输入数量
   */
  function _calculateAmountToSwapBack(
    address pool,
    address tokenIn,
    uint256 amountOutNeeded
  ) internal view returns (uint256 amountIn) {
    IUniswapV2Pair pair = IUniswapV2Pair(pool);
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

    address _token0 = pair.token0();
    bool token0IsTokenIn = tokenIn == _token0;

    (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? (reserve0, reserve1) : (reserve1, reserve0);

    amountIn = IUniswapV2Router02(uniswapV2Router).getAmountIn(amountOutNeeded, reserveIn, reserveOut);
  }

  /**
   * @dev 计算还款数量（包含 0.3% 手续费）
   * @param amountBorrowed 借款数量
   * @return 需要归还的数量
   * @notice Uniswap V2 收取 0.3% 手续费，公式：amount * 1000 / 997
   */
  function _calculateRepayAmount(uint256 amountBorrowed) internal pure returns (uint256) {
    // Uniswap V2 手续费是 0.3%
    return (amountBorrowed * 1000) / 997 + 1;
  }

  /**
   * @dev 紧急提取函数
   * @param token 要提取的代币地址
   * @notice 仅合约所有者可调用，用于提取误转入的代币
   */
  function emergencyWithdraw(address token) external onlyOwner {
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      IERC20(token).transfer(owner, balance);
    }
  }
}
