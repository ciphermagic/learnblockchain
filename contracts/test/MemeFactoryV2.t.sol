// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MemeFactoryV2.sol";

/**
 * @title MockUniswapV2Router
 * @dev 用于测试的 Mock Uniswap V2 Router 合约
 */
contract MockUniswapV2Router is IUniswapV2Router02 {
    address private _weth;
    mapping(address => mapping(address => address)) public pairs;

    constructor(address _wethAddr) {
        _weth = _wethAddr;
    }

    function WETH() external pure override returns (address) {
        return 0x1234567890AbcdEF1234567890aBcdef12345678; // Mock WETH address
    }

    function factory() external pure override returns (address) {
        return address(0); // Mock factory address
    }

    /// @dev Mock 添加 ETH 流动性
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable override returns (uint amountToken, uint amountETH, uint liquidity) {
        console.log("token", token);
        console.log("amountTokenMin", amountTokenMin);
        console.log("amountETHMin", amountETHMin);
        console.log("to", to);
        console.log("deadline", deadline);
        // Mock 实现 - 直接返回输入值
        return (amountTokenDesired, msg.value, msg.value + amountTokenDesired);
    }

    /// @dev Mock 添加流动性
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external pure override returns (uint amountA, uint amountB, uint liquidity) {
        console.log("tokenA", tokenA);
        console.log("tokenB", tokenB);
        console.log("amountAMin", amountAMin);
        console.log("amountBMin", amountBMin);
        console.log("to", to);
        console.log("deadline", deadline);
        return (amountADesired, amountBDesired, amountADesired + amountBDesired);
    }

    /// @dev Mock 获取兑换金额
    function getAmountsOut(uint amountIn, address[] calldata path)
    external pure override returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        // Mock: 假设 1 ETH = 20000 tokens（优于初始价格）
        if (path.length == 2) {
            amounts[1] = amountIn * 20000;
        }
    }

    /// @dev Mock 支持费用代币的兑换
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override {
        // Mock 实现
    }
}

/**
 * @title MockWETH
 * @dev 用于测试的 Mock WETH 合约
 */
contract MockWETH {
    mapping(address => uint256) public balanceOf;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}

/**
 * @title MemeFactoryV2Test
 * @dev MemeFactoryV2 合约的测试套件
 *      测试 V2 版本的工厂合约：代币部署、铸造、流动性添加、购买等
 */
contract MemeFactoryV2Test is Test {
    MemeFactoryV2 public factory;
    MockUniswapV2Router public mockRouter;
    MockWETH public mockWETH;
    address public projectOwner;
    address public creator;
    address public buyer;

    // 测试参数
    string public constant NAME = "MEME";
    string public constant SYMBOL = "MEME";
    uint256 public constant TOTAL_SUPPLY = 1000000 * 10 ** 18; // 1,000,000 tokens
    uint256 public constant PER_MINT = 1000 * 10 ** 18;       // 1,000 tokens per mint
    uint256 public constant PRICE = 0.0001 ether;           // 0.0001 ETH per token

    function setUp() public {
        projectOwner = makeAddr("projectOwner");
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");

        // 给测试账户一些 ETH
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);

        // 部署mock合约
        mockWETH = new MockWETH();
        mockRouter = new MockUniswapV2Router(address(mockWETH));

        // 部署工厂合约
        factory = new MemeFactoryV2(projectOwner, address(mockRouter));
    }

    function testDeployInscription() public {
        vm.startPrank(creator);

        address tokenAddr = factory.deployInscription(
            NAME,
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        vm.stopPrank();

        // 验证代币部署成功
        assertTrue(factory.deployedTokens(tokenAddr), "Token not deployed");

        // 验证代币参数
        MemeTokenV2 token = MemeTokenV2(tokenAddr);
        assertEq(token.totalSupply_(), TOTAL_SUPPLY, "Incorrect total supply");
        assertEq(token.perMint(), PER_MINT, "Incorrect per mint amount");
        assertEq(token.price(), PRICE, "Incorrect price");
        assertEq(token.memeCreator(), creator, "Incorrect creator");

        // 验证流动性状态
        assertFalse(factory.liquidityAdded(tokenAddr), "Liquidity should not be added yet");
    }

    function testMintInscriptionWithLiquidity() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            NAME,
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 记录初始余额
        uint256 initialCreatorBalance = creator.balance;

        // 计算所需支付金额
        uint256 requiredAmount = PER_MINT * PRICE / 10 ** 18;

        // 买家铸造代币
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();

        // 验证代币铸造成功
        MemeTokenV2 token = MemeTokenV2(tokenAddr);
        assertEq(token.balanceOf(buyer), PER_MINT, "Incorrect minted amount");
        // 注意：总铸造量包括给买家的代币 + 添加流动性的代币
        uint256 liquidityFee = (requiredAmount * factory.PROJECT_FEE_PERCENT()) / 100;
        uint256 liquidityTokens = (liquidityFee * 1e18) / token.price();
        assertEq(token.mintedAmount(), PER_MINT + liquidityTokens, "Incorrect total minted amount");

        // 验证费用分配 - 5%用于流动性，95%给创建者
        uint256 creatorFee = requiredAmount - liquidityFee;

        assertEq(creator.balance, initialCreatorBalance + creatorFee, "Incorrect creator fee");

        // 验证流动性已添加
        assertTrue(factory.liquidityAdded(tokenAddr), "Liquidity should be added");
    }

    function testMintMultipleTimes() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            NAME,
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 计算所需支付金额
        uint256 requiredAmount = PER_MINT * PRICE / 10 ** 18;

        // 第一次铸造（会添加流动性）
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();

        // 验证流动性已添加
        assertTrue(factory.liquidityAdded(tokenAddr), "Liquidity should be added after first mint");

        // 多次铸造测试
        uint256 testMints = 3;

        for (uint256 i = 0; i < testMints; i++) {
            vm.startPrank(buyer);
            factory.mintInscription{value: requiredAmount}(tokenAddr);
            vm.stopPrank();

            // 验证铸造数量（考虑流动性代币）
            MemeTokenV2 token = MemeTokenV2(tokenAddr);
            uint256 expectedMintedAmount = PER_MINT * (i + 2); // 用户铸造的代币
            if (factory.liquidityAdded(tokenAddr)) {
                // 如果已添加流动性，还要加上流动性代币
                uint256 firstMintRequired = PER_MINT * PRICE / 10 ** 18;
                uint256 firstLiquidityFee = (firstMintRequired * factory.PROJECT_FEE_PERCENT()) / 100;
                uint256 firstLiquidityTokens = (firstLiquidityFee * 1e18) / token.price();
                expectedMintedAmount += firstLiquidityTokens;
            }
            assertEq(token.mintedAmount(), expectedMintedAmount, "Incorrect total minted amount");
        }
    }

    function testBuyMemeFailsWithoutLiquidity() public {
        // 部署代币但不铸造（不添加流动性）
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            NAME,
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 尝试通过buyMeme购买应该失败
        vm.startPrank(buyer);
        vm.expectRevert("Liquidity not added yet");
        factory.buyMeme{value: 0.1 ether}(tokenAddr, 0);
        vm.stopPrank();
    }

    function testBuyMemeWithMockFavorablePrice() public {
        // 部署代币并添加流动性
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            NAME,
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 首先铸造以添加流动性
        uint256 requiredAmount = PER_MINT * PRICE / 10 ** 18;
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();

        // 现在测试buyMeme
        MemeTokenV2 token = MemeTokenV2(tokenAddr);
        uint256 buyAmount = 0.1 ether;

        // 计算期望的代币数量（基于mock router的20000倍率）
        uint256 expectedTokensFromUniswap = buyAmount * 20000;
        uint256 tokensAtInitialPrice = (buyAmount * 1e18) / token.price();

        // 确保mock价格更优
        assertTrue(expectedTokensFromUniswap > tokensAtInitialPrice, "Mock price should be favorable");

        // 记录初始余额（在mock实现中不实际转移代币）
        // uint256 initialBalance = token.balanceOf(buyer);

        // 通过buyMeme购买
        vm.startPrank(buyer);
        factory.buyMeme{value: buyAmount}(tokenAddr, expectedTokensFromUniswap);
        vm.stopPrank();

        // 注意：在mock实现中，我们没有实际转移代币，所以这里只验证事件
        // 在真实环境中，这里会验证代币余额的变化
    }

    function testUpdateProjectOwner() public {
        address newProjectOwner = makeAddr("newProjectOwner");

        // 只有合约所有者可以更新
        vm.startPrank(factory.owner());
        factory.updateProjectOwner(newProjectOwner);
        vm.stopPrank();

        assertEq(factory.projectOwner(), newProjectOwner, "Project owner not updated");
    }

    function testUpdateUniswapRouter() public {
        address newRouter = makeAddr("newRouter");

        // 只有合约所有者可以更新
        vm.startPrank(factory.owner());
        factory.updateUniswapRouter(newRouter);
        vm.stopPrank();

        assertEq(address(factory.uniswapRouter()), newRouter, "Router not updated");
    }

    function testInvalidDeploymentParameters() public {
        vm.startPrank(creator);

        // 测试总供应量为0
        vm.expectRevert("Total supply must be greater than 0");
        factory.deployInscription(NAME, SYMBOL, 0, PER_MINT, PRICE);

        // 测试每次铸造数量为0
        vm.expectRevert("Per mint must be greater than 0");
        factory.deployInscription(NAME, SYMBOL, TOTAL_SUPPLY, 0, PRICE);

        // 测试每次铸造数量大于总供应量
        vm.expectRevert("Per mint must be less than or equal to total supply");
        factory.deployInscription(NAME, SYMBOL, PER_MINT, TOTAL_SUPPLY, PRICE);

        vm.stopPrank();
    }

    function testInsufficientPayment() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            NAME,
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 尝试支付不足的金额
        uint256 requiredAmount = PER_MINT * PRICE / 10 ** 18;
        uint256 insufficientAmount = requiredAmount - 1;

        vm.startPrank(buyer);
        vm.expectRevert("Insufficient payment");
        factory.mintInscription{value: insufficientAmount}(tokenAddr);
        vm.stopPrank();
    }
}