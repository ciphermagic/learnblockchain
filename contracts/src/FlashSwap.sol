// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IUniswapV2Pair {
  function token0() external view returns (address);

  function token1() external view returns (address);

  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IUniswapV2Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);

  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
}

// 测试版本的FlashSwap合约，允许设置工厂和路由器地址
contract FlashSwap {
  address public uniswapV2Factory;
  address public uniswapV2Router;

  address public owner;

  event FlashSwapExecuted(
    address indexed poolA,
    address indexed poolB,
    address tokenA,
    address tokenB,
    uint256 amountBorrowed,
    uint256 profit
  );

  modifier onlyOwner() {
    require(msg.sender == owner, 'Not owner');
    _;
  }

  constructor() {
    // 默认地址（主网地址）
    uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    owner = msg.sender;
  }

  // 新增：允许测试时设置工厂和路由器地址
  function setUniswapAddresses(address factory, address router) external onlyOwner {
    uniswapV2Factory = factory;
    uniswapV2Router = router;
  }

  // 执行闪电兑换套利
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

    uint256 amount0Out = tokenA == token0 ? amountToBorrow : 0;
    uint256 amount1Out = tokenA == token1 ? amountToBorrow : 0;

    // 编码数据传递给回调函数
    bytes memory data = abi.encode(poolB, tokenA, tokenB, amountToBorrow);

    // 执行闪电贷
    pair.swap(amount0Out, amount1Out, address(this), data);
  }

  // Uniswap V2 回调函数
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
    uint256 amountReceived = amount0 > 0 ? amount0 : amount1;

    // 在 poolB 中将 tokenA 兑换为 tokenB
    _swapOnPool(poolB, _tokenA, _tokenB, amountReceived);

    // 计算需要还款的数量（包含手续费）
    uint256 amountToRepay = _calculateRepayAmount(amountBorrowed);

    // 从amountOut中拿出一部分用于还款
    // 这里我们计算需要多少_tokenB来偿还所需的_tokenA（计算输出需要偿还的amountToRepay个A，需要输入多少个B）
    uint256 amountToSwapBack = _calculateAmountToSwapBack(msg.sender, _tokenB, amountToRepay);

    // 检查我们是否有足够多的_tokenB用于偿还_tokenA
    uint256 balanceOfTokenB = IERC20(_tokenB).balanceOf(address(this));
    require(balanceOfTokenB >= amountToSwapBack, 'Insufficient tokenB for repayment');

    // 转移_tokenB给配对合约（msg.sender 是 poolA）
    IERC20(_tokenB).transfer(msg.sender, amountToSwapBack);

    // 现在我们已经把需要的_tokenB发送给配对合约，配对合约会将其与它持有的_tokenA进行交换
    // 这里不再直接调用swap，而是通过配对合约在swap结束时自动完成交换
    // 配对合约会验证我们是否返回了足够的_tokenA

    // 由于我们已经发送了正确的amountToSwapBack到配对合约
    // 并且我们计算了所需的还款金额，所以合约应该能验证通过

    // 计算利润
    uint256 remainingTokenB = IERC20(_tokenB).balanceOf(address(this));

    // 将剩余代币转给 owner
    if (remainingTokenB > 0) {
      IERC20(_tokenB).transfer(owner, remainingTokenB);
    }

    emit FlashSwapExecuted(msg.sender, poolB, _tokenA, _tokenB, amountBorrowed, remainingTokenB);
  }

  // 执行交换
  function _swapOnPool(address pool, address tokenIn, address tokenOut, uint256 amountIn) internal {
    IUniswapV2Pair pair = IUniswapV2Pair(pool);
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

    address _token0 = pair.token0();

    bool token0IsTokenIn = tokenIn == _token0;

    (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? (reserve0, reserve1) : (reserve1, reserve0);

    // 计算输出数量
    uint256 amountOut = IUniswapV2Router02(uniswapV2Router).getAmountOut(amountIn, reserveIn, reserveOut);

    // 转移代币到配对合约
    IERC20(tokenIn).transfer(pool, amountIn);

    // 执行交换 - 根据tokenIn是token0还是token1来确定输出方向
    uint256 amount0Out = tokenOut == _token0 ? amountOut : 0;
    uint256 amount1Out = tokenOut == _token0 ? 0 : amountOut;

    pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
  }

  // 计算需要交换回去的数量
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

  // 计算还款数量（包含 0.3% 手续费）
  function _calculateRepayAmount(uint256 amountBorrowed) internal pure returns (uint256) {
    // Uniswap V2 手续费是 0.3%
    return (amountBorrowed * 1000) / 997 + 1;
  }

  // 紧急提取函数
  function emergencyWithdraw(address token) external onlyOwner {
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      IERC20(token).transfer(owner, balance);
    }
  }
}
