// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Uniswap V2 Router 接口定义
interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    /// @dev 添加两种 ERC20 代币的流动性
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    /// @dev 添加 ETH 与 ERC20 代币的流动性
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    /// @dev 根据输入数量获取兑换路径的输出数量
    function getAmountsOut(uint amountIn, address[] calldata path) external pure returns (uint[] memory amounts);
}

/// @dev Uniswap V2 Router V02 版本，增加对转账手续费代币的支持
interface IUniswapV2Router02 is IUniswapV2Router01 {
    /// @dev 支持费用代币的 ETH 兑换（防止 _transferFeeToken 攻击）
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

/**
 * @title MemeTokenV2
 * @dev 基于 ERC20Upgradeable 的 Meme 代币实现（V2 版本）
 *      支持通过工厂合约铸造代币，以及为流动性池铸造代币
 */
contract MemeTokenV2 is Initializable, ERC20Upgradeable {
    /// @dev 代币创建者地址
    address public memeCreator;
    /// @dev 工厂合约地址
    address public factory;
    /// @dev 代币总供应量
    uint256 public totalSupply_;
    /// @dev 每次铸造的数量（刻字模式）
    uint256 public perMint;
    /// @dev 每个代币的价格（wei）
    uint256 public price;
    /// @dev 已铸造的代币总量
    uint256 public mintedAmount;

    /**
     * @dev 初始化 Meme 代币
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _totalSupply 总供应量
     * @param _perMint 每次铸造的数量
     * @param _price 每个代币的价格（wei）
     * @param _creator 创建者地址
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) external initializer {
        require(memeCreator == address(0), "Already initialized");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint must be less than or equal to total supply");

        __ERC20_init(_name, _symbol);
        totalSupply_ = _totalSupply;
        perMint = _perMint;
        price = _price;
        memeCreator = _creator;
        factory = msg.sender;
        mintedAmount = 0;
    }

    /**
     * @dev 铸造新的代币（用户购买时调用）
     * @param to 接收者地址
     * @return 是否成功
     */
    function mint(address to) external returns (bool) {
        require(msg.sender == factory, "Only factory can mint");
        require(mintedAmount + perMint <= totalSupply_, "Exceeds total supply");

        mintedAmount += perMint;
        _mint(to, perMint);
        return true;
    }

    /**
     * @dev 为添加流动性铸造代币
     * @param to 接收者地址
     * @param amount 铸造数量
     */
    function mintForLiquidity(address to, uint256 amount) external returns (bool) {
        require(msg.sender == factory, "Only factory can mint");
        require(mintedAmount + amount <= totalSupply_, "Exceeds total supply");

        mintedAmount += amount;
        _mint(to, amount);
        return true;
    }
}

/**
 * @title MemeFactoryV2
 * @dev Meme 代币工厂合约 V2 版本
 *      在 V1 基础上增加了：
 *      1. 自动为代币添加 Uniswap 流动性
 *      2. 支持通过 DEX 购买代币（buyMeme 函数）
 *      3. 费用比例调整为 5%（用于添加流动性）
 *
 * @notice 首次铸造时，5% 费用用于添加流动性，95% 给创建者
 */
contract MemeFactoryV2 is Ownable {
    using Clones for address;

    /// @dev 项目方地址
    address public projectOwner;
    /// @dev 项目方费用比例（5%，用于添加流动性）
    uint256 public constant PROJECT_FEE_PERCENT = 5;
    /// @dev 基础代币实现合约地址
    address public implementation;
    /// @dev 记录已部署的代币
    mapping(address => bool) public deployedTokens;
    /// @dev 记录是否已添加流动性
    mapping(address => bool) public liquidityAdded;
    /// @dev Uniswap V2 Router 地址
    IUniswapV2Router02 public uniswapRouter;

    /// @dev 新代币部署事件
    event MemeDeployed(address indexed tokenAddress, address indexed creator, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    /// @dev 代币铸造事件
    event MemeMinted(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 paid);
    /// @dev 流动性添加事件
    event LiquidityAdded(address indexed tokenAddress, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    /// @dev 代币购买事件
    event MemeBought(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 paid);

    /**
     * @dev 构造函数
     * @param _projectOwner 项目方地址
     * @param _uniswapRouter Uniswap V2 Router 地址
     */
    constructor(address _projectOwner, address _uniswapRouter) Ownable(msg.sender) {
        require(_projectOwner != address(0), "Invalid project owner");
        require(_uniswapRouter != address(0), "Invalid uniswap router");
        projectOwner = _projectOwner;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        // 部署基础代币实现
        implementation = address(new MemeTokenV2());
    }

    /**
     * @dev 部署新的 Meme 代币
     * @param name 代币名称
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造的数量
     * @param price 每个代币的价格（wei）
     * @return tokenAddr 新部署的代币地址
     */
    function deployInscription(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address tokenAddr) {
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint must be less than or equal to total supply");

        // 使用 Clones 库创建最小代理
        tokenAddr = implementation.clone();

        // 初始化代币
        MemeTokenV2(tokenAddr).initialize(name, symbol, totalSupply, perMint, price, msg.sender);

        // 记录已部署的代币
        deployedTokens[tokenAddr] = true;

        emit MemeDeployed(tokenAddr, msg.sender, symbol, totalSupply, perMint, price);

        return tokenAddr;
    }

    /**
     * @dev 铸造 Meme 代币（购买刻字）
     * @param tokenAddr 代币地址
     * @notice 首次铸造时，5% 费用自动用于添加 Uniswap 流动性
     */
    function mintInscription(address tokenAddr) external payable {
        require(deployedTokens[tokenAddr], "Token not deployed by this factory");

        MemeTokenV2 token = MemeTokenV2(tokenAddr);

        // 检查是否超过总供应量
        require(token.mintedAmount() + token.perMint() <= token.totalSupply_(), "Exceeds total supply");

        // 检查支付金额
        uint256 requiredAmount = token.price() * token.perMint() / 1e18;
        require(msg.value >= requiredAmount, "Insufficient payment");

        // 计算费用分配 - 5%用于添加流动性
        uint256 liquidityFee = (requiredAmount * PROJECT_FEE_PERCENT) / 100;
        uint256 creatorFee = requiredAmount - liquidityFee;

        // 转给创建者的费用
        (bool creatorSuccess,) = payable(token.memeCreator()).call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");

        // 铸造代币给买家
        token.mint(msg.sender);

        // 如果还未添加流动性，则添加流动性
        if (!liquidityAdded[tokenAddr] && address(this).balance >= liquidityFee) {
            _addInitialLiquidity(tokenAddr, liquidityFee);
        }

        // 退还多余的 ETH
        if (msg.value > requiredAmount) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - requiredAmount}("");
            require(refundSuccess, "Refund failed");
        }

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), requiredAmount);
    }

    /**
     * @dev 通过 Uniswap 购买 Meme 代币
     * @param tokenAddr 代币地址
     * @param minTokenAmount 最小代币数量
     * @notice 需要先添加流动性才能使用此功能
     * @dev 只有当 DEX 价格优于初始价格时才允许购买
     */
    function buyMeme(address tokenAddr, uint256 minTokenAmount) external payable {
        require(deployedTokens[tokenAddr], "Token not deployed by this factory");
        require(liquidityAdded[tokenAddr], "Liquidity not added yet");
        require(msg.value > 0, "Must send ETH");

        MemeTokenV2 token = MemeTokenV2(tokenAddr);

        // 检查Uniswap价格是否优于初始价格
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        uint256[] memory amounts = uniswapRouter.getAmountsOut(msg.value, path);
        uint256 expectedTokens = amounts[1];

        // 计算初始价格能买到的代币数量
        uint256 tokensAtInitialPrice = (msg.value * 1e18) / token.price();

        // 确保Uniswap价格更优（能买到更多代币）
        require(expectedTokens > tokensAtInitialPrice, "Uniswap price not favorable");
        require(expectedTokens >= minTokenAmount, "Insufficient output amount");

        // 通过Uniswap购买代币
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            minTokenAmount,
            path,
            msg.sender,
            block.timestamp + 300
        );

        emit MemeBought(tokenAddr, msg.sender, expectedTokens, msg.value);
    }

    /**
     * @dev 添加初始流动性
     * @param tokenAddr 代币地址
     * @param ethAmount 用于添加流动性的 ETH 数量
     * @notice 使用初始价格计算代币数量，流动性代币归项目方所有
     */
    function _addInitialLiquidity(address tokenAddr, uint256 ethAmount) internal {
        MemeTokenV2 token = MemeTokenV2(tokenAddr);

        // 根据初始价格计算需要铸造的代币数量
        uint256 tokenAmount = (ethAmount * 1e18) / token.price();

        // 为流动性铸造代币
        token.mintForLiquidity(address(this), tokenAmount);

        // 批准代币给Uniswap Router
        token.approve(address(uniswapRouter), tokenAmount);

        // 添加流动性
        (, , uint256 liquidity) = uniswapRouter.addLiquidityETH{value: ethAmount}(
            tokenAddr,
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            projectOwner, // LP tokens 发给项目方
            block.timestamp + 300
        );

        liquidityAdded[tokenAddr] = true;

        emit LiquidityAdded(tokenAddr, tokenAmount, ethAmount, liquidity);
    }

    /**
     * @dev 更新项目方地址
     * @param _newProjectOwner 新的项目方地址
     */
    function updateProjectOwner(address _newProjectOwner) external onlyOwner {
        require(_newProjectOwner != address(0), "Invalid project owner");
        projectOwner = _newProjectOwner;
    }

    /**
     * @dev 更新 Uniswap Router 地址
     * @param _newRouter 新的 Uniswap Router 地址
     */
    function updateUniswapRouter(address _newRouter) external onlyOwner {
        require(_newRouter != address(0), "Invalid router address");
        uniswapRouter = IUniswapV2Router02(_newRouter);
    }

    /// @dev 允许合约接收 ETH
    receive() external payable {}
}