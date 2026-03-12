// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";

/**
 * @title MemeFactoryTest
 * @dev MemeFactory 合约的测试套件
 *      测试工厂合约的基本功能：代币部署、铸造、费用分配等
 */
contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectOwner;
    address public creator;
    address public buyer;

    // 测试参数
    string constant SYMBOL = "MEME";
    uint256 constant TOTAL_SUPPLY = 1000000 * 10 ** 18; // 1,000,000 tokens
    uint256 constant PER_MINT = 1000 * 10 ** 18;       // 1,000 tokens per mint
    uint256 constant PRICE = 0.0001 ether;              // 0.0001 ETH per token

    /// @dev 测试前置设置
    function setUp() public {
        projectOwner = makeAddr("projectOwner");
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");

        // 给测试账户一些 ETH
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);

        // 部署工厂合约
        factory = new MemeFactory(projectOwner);
    }

    /// @dev 测试代币部署功能
    function testDeployInscription() public {
        vm.startPrank(creator);

        address tokenAddr = factory.deployInscription(
            SYMBOL, // name - 使用符号作为名称
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        vm.stopPrank();

        // 验证代币部署成功
        assertTrue(factory.deployedTokens(tokenAddr), "Token not deployed");

        // 验证代币参数
        MemeToken deployToken = MemeToken(tokenAddr);
        assertEq(deployToken.totalSupply_(), TOTAL_SUPPLY, "Incorrect total supply");
        assertEq(deployToken.perMint(), PER_MINT, "Incorrect per mint amount");
        assertEq(deployToken.price(), PRICE, "Incorrect price");
        assertEq(deployToken.memeCreator(), creator, "Incorrect creator");
    }

    /// @dev 测试代币铸造和费用分配功能
    function testMintInscription() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            SYMBOL, // name - 使用符号作为名称
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 记录初始余额
        uint256 initialProjectBalance = projectOwner.balance;
        uint256 initialCreatorBalance = creator.balance;

        // 计算所需支付金额
        uint256 requiredAmount = PER_MINT * PRICE / 10 ** 18;

        // 买家铸造代币
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();

        // 验证代币铸造成功
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer), PER_MINT, "Incorrect minted amount");
        assertEq(token.mintedAmount(), PER_MINT, "Incorrect total minted amount");

        // 验证费用分配：项目方 1%，创建者 99%
        uint256 projectFee = (requiredAmount * factory.PROJECT_FEE_PERCENT()) / 100;
        uint256 creatorFee = requiredAmount - projectFee;

        assertEq(projectOwner.balance, initialProjectBalance + projectFee, "Incorrect project fee");
        assertEq(creator.balance, initialCreatorBalance + creatorFee, "Incorrect creator fee");
    }

    /// @dev 测试多次铸造功能
    function testMintMultipleTimes() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            SYMBOL, // name - 使用符号作为名称
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();

        // 计算所需支付金额
        uint256 requiredAmount = PER_MINT * PRICE / 10 ** 18;

        // 多次铸造，但限制次数以避免超过总供应量
        // 由于 TOTAL_SUPPLY = 1,000,000 * 10**18 且 PER_MINT = 1,000 * 10**18
        // 理论上最多可以铸造 1000 次，但为安全起见，我们只铸造几次进行测试
        uint256 testMints = 5; // 只测试铸造 5 次，避免测试耗时过长

        for (uint256 i = 0; i < testMints; i++) {
            vm.startPrank(buyer);
            factory.mintInscription{value: requiredAmount}(tokenAddr);
            vm.stopPrank();

            // 验证铸造数量
            MemeToken mintToken = MemeToken(tokenAddr);
            assertEq(mintToken.mintedAmount(), PER_MINT * (i + 1), "Incorrect total minted amount");
        }

        // 验证可以继续铸造（因为我们只铸造了少量代币）
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();

        // 验证铸造后的总量
        MemeToken finalToken = MemeToken(tokenAddr);
        assertEq(finalToken.mintedAmount(), PER_MINT * (testMints + 1), "Incorrect final minted amount");
    }

    /// @dev 测试部署多个不同代币的功能
    function testDeployMultipleDifferentTokens() public {
        // 定义三个不同的代币参数
        string memory name1 = "DogeKing";
        string memory symbol1 = "DOGEK";
        uint256 totalSupply1 = 500_000 * 10 ** 18;
        uint256 perMint1 = 500 * 10 ** 18;
        uint256 price1 = 0.0002 ether;

        string memory name2 = "ShibaQueen";
        string memory symbol2 = "SHIBQ";
        uint256 totalSupply2 = 2_000_000 * 10 ** 18;
        uint256 perMint2 = 2000 * 10 ** 18;
        uint256 price2 = 0.00005 ether;

        string memory name3 = "PepeMoon";
        string memory symbol3 = "PEPEM";
        uint256 totalSupply3 = 10_000_000 * 10 ** 18;
        uint256 perMint3 = 10_000 * 10 ** 18;
        uint256 price3 = 0.00001 ether;

        address creator1 = makeAddr("creator1");
        address creator2 = makeAddr("creator2");
        address creator3 = makeAddr("creator3");

        // 给每个 creator 一些 ETH（可选，deploy 不需要 ETH）
        vm.deal(creator1, 5 ether);
        vm.deal(creator2, 5 ether);
        vm.deal(creator3, 5 ether);

        address token1;
        address token2;
        address token3;

        // Creator1 部署第一个代币
        vm.startPrank(creator1);
        token1 = factory.deployInscription(name1, symbol1, totalSupply1, perMint1, price1);
        vm.stopPrank();

        // Creator2 部署第二个代币
        vm.startPrank(creator2);
        token2 = factory.deployInscription(name2, symbol2, totalSupply2, perMint2, price2);
        vm.stopPrank();

        // Creator3 部署第三个代币
        vm.startPrank(creator3);
        token3 = factory.deployInscription(name3, symbol3, totalSupply3, perMint3, price3);
        vm.stopPrank();

        // 验证三个代币地址都不相同
        assertTrue(token1 != token2, "Token1 and Token2 should have different addresses");
        assertTrue(token1 != token3, "Token1 and Token3 should have different addresses");
        assertTrue(token2 != token3, "Token2 and Token3 should have different addresses");

        // 验证工厂正确记录了三个代币
        assertTrue(factory.deployedTokens(token1), "Token1 should be marked as deployed");
        assertTrue(factory.deployedTokens(token2), "Token2 should be marked as deployed");
        assertTrue(factory.deployedTokens(token3), "Token3 should be marked as deployed");

        // 验证每个代币的参数正确初始化
        MemeToken t1 = MemeToken(token1);
        assertEq(t1.name(), name1, "Token1 name mismatch");
        assertEq(t1.symbol(), symbol1, "Token1 symbol mismatch");
        assertEq(t1.totalSupply_(), totalSupply1, "Token1 totalSupply mismatch");
        assertEq(t1.perMint(), perMint1, "Token1 perMint mismatch");
        assertEq(t1.price(), price1, "Token1 price mismatch");
        assertEq(t1.memeCreator(), creator1, "Token1 creator mismatch");

        MemeToken t2 = MemeToken(token2);
        assertEq(t2.name(), name2, "Token2 name mismatch");
        assertEq(t2.symbol(), symbol2, "Token2 symbol mismatch");
        assertEq(t2.totalSupply_(), totalSupply2, "Token2 totalSupply mismatch");
        assertEq(t2.perMint(), perMint2, "Token2 perMint mismatch");
        assertEq(t2.price(), price2, "Token2 price mismatch");
        assertEq(t2.memeCreator(), creator2, "Token2 creator mismatch");

        MemeToken t3 = MemeToken(token3);
        assertEq(t3.name(), name3, "Token3 name mismatch");
        assertEq(t3.symbol(), symbol3, "Token3 symbol mismatch");
        assertEq(t3.totalSupply_(), totalSupply3, "Token3 totalSupply mismatch");
        assertEq(t3.perMint(), perMint3, "Token3 perMint mismatch");
        assertEq(t3.price(), price3, "Token3 price mismatch");
        assertEq(t3.memeCreator(), creator3, "Token3 creator mismatch");
    }
}