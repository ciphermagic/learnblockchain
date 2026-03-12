//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 简化版 AMM（自动做市商）池合约
// 灵感来源：https://github.com/monokh/looneyswap
// 实现类似 Uniswap V2 的 AMM 机制：x * y = k（常数乘积公式）

// 流动性代币（LP Token）分配示例：
// Tom: 1 MSP
// Bob: 2 MSP
// Alice: 3 MSP

// 初始储备示例：
// reserve0 = 10100 Token0
// reserve1 = 6060 Token1

/**
 * @title MiniSwapPool
 * @dev 简化版 AMM 流动性池合约
 *      用户可以存入两种代币来提供流动性，获得 LP 代币作为凭证
 *      交易者可以通过池子进行代币兑换（使用 x * y = k 公式）
 *      LP 代币持有者可以销毁代币来提取其对应的流动性份额
 */
contract MiniSwapPool is ERC20 {

    /// @dev 交易对中排序后的第一个代币地址
    address public token0;
    /// @dev 交易对中排序后的第二个代币地址
    address public token1;

    /// @dev 代币0的储备量
    uint public reserve0;

    /// @dev 代币1的储备量
    uint public reserve1;

    /// @dev 首次添加流动性时铸造的 LP 代币数量（固定值）
    uint public constant INITIAL_SUPPLY = 10 ** 5;

    /**
     * @dev 构造函数
     * @param _token0 第一个代币地址
     * @param _token1 第二个代币地址
     * @param name LP 代币名称
     * @param symbol LP 代币符号
     * @notice 代币地址按从小到大排序，确保与 Uniswap V2 一致
     */
    constructor(address _token0, address _token1, string memory name, string memory symbol) ERC20(name, symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 添加流动性
     * @param amount0 存入的代币0数量
     * @param amount1 存入的代币1数量
     * @notice 首次添加流动性时，铸造固定数量的 LP 代币（INITIAL_SUPPLY）
     *         后续添加时，按代币比例计算应得的 LP 代币数量
     *         使用两种代币中较少比例的那个，确保公平性
     */
    function addLiquidity(uint amount0, uint amount1) public {
        // 从用户转入代币到池子
        assert(IERC20(token0).transferFrom(msg.sender, address(this), amount0));
        assert(IERC20(token1).transferFrom(msg.sender, address(this), amount1));

        uint reserve0After = reserve0 + amount0;
        uint reserve1After = reserve1 + amount1;

        // 首次添加流动性：铸造固定数量的 LP 代币
        if (reserve0 == 0 && reserve1 == 0) {
            _mint(msg.sender, INITIAL_SUPPLY);
        } else {
            // 后续添加：按比例计算新 LP 代币
            uint currentSupply = totalSupply();

            // 按 token0 的增长比例计算 LP 代币数量
            // 新储备量0 × 当前LP总量 / 旧储备量0
            uint newSupplyGivenReserve0Ratio = reserve0After * currentSupply / reserve0;
            uint newSupplyGivenReserve1Ratio = reserve1After * currentSupply / reserve1;
            // 取两者的较小值，防止其中一种代币比例失衡
            uint newSupply = Math.min(newSupplyGivenReserve0Ratio, newSupplyGivenReserve1Ratio);
            _mint(msg.sender, newSupply - currentSupply);
        }

        reserve0 = reserve0After;
        reserve1 = reserve1After;
    }

    /**
     * @dev 移除流动性
     * @param liquidity 要销毁的 LP 代币数量
     * @notice 销毁 LP 代币，按比例提取对应的两种代币
     *         提取数量 = (liquidity / totalSupply) * reserve
     */
    function remove(uint liquidity) public {
        // 将 LP 代币转入本合约（用于销毁）
        assert(transfer(address(this), liquidity));

        uint currentSupply = totalSupply();

        // 计算可提取的代币数量（按比例）
        // 例如：10 LP / 总供应 100 = 10%
        uint amount0 = liquidity * reserve0 / currentSupply;
        uint amount1 = liquidity * reserve1 / currentSupply;

        // 销毁 LP 代币
        _burn(address(this), liquidity);

        // 转回代币给用户
        assert(IERC20(token0).transfer(msg.sender, amount0));
        assert(IERC20(token1).transfer(msg.sender, amount1));

        // 更新储备
        reserve0 = reserve0 - amount0;
        reserve1 = reserve1 - amount1;
    }

    /**
     * @dev 根据输入金额计算输出金额（使用常数乘积公式）
     * @param amountIn 输入代币数量
     * @param fromToken 输入代币地址
     * @return amountOut 预计获得的输出代币数量
     * @return _reserve0 计算后的代币0储备量
     * @return _reserve1 计算后的代币1储备量
     * @notice 使用 x * y = k 公式：输入代币增加导致输出代币减少
     *         公式推导：(reserve0 + amountIn) * (reserve1 - amountOut) = reserve0 * reserve1
     */
    function getAmountOut(uint amountIn, address fromToken) public view returns (uint amountOut, uint _reserve0, uint _reserve1) {
        uint newReserve0;
        uint newReserve1;
        uint k = reserve0 * reserve1;

        // x (reserve0) * y (reserve1) = k (常数)
        // (reserve0 + amountIn) * (reserve1 - amountOut) = k
        // (reserve1 - amountOut) = k / (reserve0 + amountIn)
        // newReserve1 = k / (newReserve0)
        // amountOut = newReserve1 - reserve1

        if (fromToken == token0) {
            newReserve0 = amountIn + reserve0;
            newReserve1 = k / newReserve0;
            amountOut = reserve1 - newReserve1;
        } else {
            newReserve1 = amountIn + reserve1;
            newReserve0 = k / newReserve1;
            amountOut = reserve0 - newReserve0;
        }

        _reserve0 = newReserve0;
        _reserve1 = newReserve1;
    }

    /**
     * @dev 执行代币兑换
     * @param amountIn 输入代币数量
     * @param minAmountOut 最低输出数量（防止滑点）
     * @param fromToken 输入代币地址
     * @param toToken 输出代币地址
     * @param to 接收输出代币的地址
     * @notice 使用 getAmountOut 计算输出数量，确保不低于最低输出
     */
    function swap(uint amountIn, uint minAmountOut, address fromToken, address toToken, address to) public {
        // 参数验证
        require(amountIn > 0 && minAmountOut > 0, "Amount invalid");
        require(fromToken == token0 || fromToken == token1, "From token invalid");
        require(toToken == token0 || toToken == token1, "To token invalid");
        require(fromToken != toToken, "From and to tokens should not match");

        // 计算输出金额
        (uint amountOut, uint newReserve0, uint newReserve1) = getAmountOut(amountIn, fromToken);

        // 滑点检查：确保输出不低于最低要求
        require(amountOut >= minAmountOut, "Slipped... on a banana");

        // 执行代币转账
        assert(IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn));
        assert(IERC20(toToken).transfer(to, amountOut));

        // 更新储备
        reserve0 = newReserve0;
        reserve1 = newReserve1;
    }
}