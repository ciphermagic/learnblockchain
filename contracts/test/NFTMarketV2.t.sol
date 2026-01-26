// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC1363 is ERC1363 {
    constructor() ERC20("Payment Token", "PTK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTMarketV2Test is Test {
    NFTMarketV2 public nftMarket;
    MockERC1363 public paymentToken;
    MockNFT public mockNFT;
    uint256 public deadline;

    address public owner = address(this);
    address public seller = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant SELLER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public relayer = makeAddr("relayer");

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant PRICE = 100 ether;

    function setUp() public {
        paymentToken = new MockERC1363();

        // 部署 V2 实现 + 代理
        address impl = address(new NFTMarketV2());
        bytes memory initData = abi.encodeWithSelector(
            NFTMarketV2.initialize.selector,
            address(paymentToken)
        );
        nftMarket = NFTMarketV2(address(new ERC1967Proxy(impl, initData)));

        mockNFT = new MockNFT();

        // 铸造 NFT 给 seller
        vm.prank(seller);
        mockNFT.mint(seller, TOKEN_ID);

        // seller 一次性授权市场合约操作其所有 NFT（listWithSignature 要求）
        vm.prank(seller);
        mockNFT.setApprovalForAll(address(nftMarket), true);

        deadline = block.timestamp + 1 days;
    }

    // 生成签名消息哈希（与合约内 getListingMessageHash 一致）
    function _getMessageHash(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                address(nftMarket),
                nftContract,
                tokenId,
                price,
                deadline
            )
        );
    }

    // 生成 EIP-712 风格的 eth-signed message hash 并签名
    function _signMessage(bytes32 messageHash, uint256 privateKey) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }

    function testListWithSignatureSuccess() public {
        // 生成消息哈希
        bytes32 messageHash = nftMarket.getListingMessageHash(address(mockNFT), TOKEN_ID, PRICE, deadline);
//        bytes32 messageHash = _getMessageHash(address(mockNFT), TOKEN_ID, PRICE, deadline);
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // seller 签名
        bytes memory signature = _signMessage(ethSignedHash, SELLER_PK);

        // 事件检查
        vm.expectEmit(true, true, true, true);
        emit NFTMarketV2.NFTListed(0, seller, address(mockNFT), TOKEN_ID, PRICE);

        // relayer 调用 listWithSignature（任何人可调用）
        vm.prank(relayer);
        uint256 listingId = nftMarket.listWithSignature(
            address(mockNFT),
            TOKEN_ID,
            PRICE,
            deadline,
            signature
        );

        // 验证 listing 创建成功
        assertEq(listingId, 0);
        (address listedSeller, address listedNft, uint256 listedTokenId, uint256 listedPrice, bool active) =
                            nftMarket.listings(listingId);
        assertEq(listedSeller, seller);
        assertEq(listedNft, address(mockNFT));
        assertEq(listedTokenId, TOKEN_ID);
        assertEq(listedPrice, PRICE);
        assertTrue(active);

        // 验证签名已被标记为已使用
        assertTrue(nftMarket.usedSignatures(ethSignedHash));
    }

    function testListWithSignatureExpiredReverts() public {
        uint256 expiredDeadline = block.timestamp - 1; // 已过期

        bytes32 messageHash = _getMessageHash(address(mockNFT), TOKEN_ID, PRICE, expiredDeadline);
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        bytes memory signature = _signMessage(ethSignedHash, SELLER_PK);

        vm.expectRevert("NFTMarket: signature expired");
        nftMarket.listWithSignature(
            address(mockNFT),
            TOKEN_ID,
            PRICE,
            expiredDeadline,
            signature
        );
    }

    function testListWithSignatureInvalidSignerReverts() public {
        // 用错误的私钥签名（不是 seller）
        uint256 wrongPk = 0xB0B;
        bytes32 messageHash = _getMessageHash(address(mockNFT), TOKEN_ID, PRICE, deadline   );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        bytes memory wrongSignature = _signMessage(ethSignedHash, wrongPk);

        vm.expectRevert("NFTMarket: invalid signature");
        nftMarket.listWithSignature(
            address(mockNFT),
            TOKEN_ID,
            PRICE,
            deadline,
            wrongSignature
        );
    }

    function testListWithSignatureReplayReverts() public {
        bytes32 messageHash = _getMessageHash(address(mockNFT), TOKEN_ID, PRICE, deadline);
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        bytes memory signature = _signMessage(ethSignedHash, SELLER_PK);

        // 第一次成功
        vm.prank(relayer);
        nftMarket.listWithSignature(address(mockNFT), TOKEN_ID, PRICE, deadline, signature);

        // 第二次应该 revert
        vm.expectRevert("NFTMarket: signature already used");
        vm.prank(relayer);
        nftMarket.listWithSignature(address(mockNFT), TOKEN_ID, PRICE, deadline, signature);
    }

    function testListWithSignatureNotApprovedReverts() public {
        // 撤销授权
        vm.prank(seller);
        mockNFT.setApprovalForAll(address(nftMarket), false);

        bytes32 messageHash = _getMessageHash(address(mockNFT), TOKEN_ID, PRICE, deadline);
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        bytes memory signature = _signMessage(ethSignedHash, SELLER_PK);

        vm.expectRevert("NFTMarket: market not approved");
        nftMarket.listWithSignature(
            address(mockNFT),
            TOKEN_ID,
            PRICE,
            deadline,
            signature
        );
    }

    function testGetListingMessageHashCorrect() public  view {
        bytes32 expected = keccak256(
            abi.encodePacked(
                address(nftMarket),
                address(mockNFT),
                TOKEN_ID,
                PRICE,
                deadline
            )
        );

        bytes32 actual = nftMarket.getListingMessageHash(
            address(mockNFT),
            TOKEN_ID,
            PRICE,
            deadline
        );

        assertEq(actual, expected);
    }
}