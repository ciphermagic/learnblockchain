'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  useDisconnect,
  useConnect,
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useWalletClient,
} from 'wagmi';
import { parseEther, encodeAbiParameters } from 'viem';

import { Listing, NFTContract, NFTToken } from './types';
import { calculateDeadline, publicClient } from './utils/signature';
import MarketListings from './components/MarketListings';
import MyNFTs from './components/MyNFTs';
import DeployContract from './components/DeployContract';
import MintNFT from './components/MintNFT';
import { waitForTransactionReceipt } from 'viem/actions';

// 合约地址配置
const CONTRACTS = {
  NFT_MARKET_V2: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' as `0x${string}`,
  ERC1363_TOKEN: '0x5FbDB2315678afecb367f032d93F642f64180aa3' as `0x${string}`,
  CHAIN_ID: 31337,
} as const;

// ABI定义
import ERC1363_ABI from '@/abis/MyERC1363Token.json';
import NFT_MARKET_V2_ABI from '@/abis/NFTMarketV2.json';
import MINIMAL_ERC721_ABI from '@/abis/MinimalERC721.json';

// MinimalERC721 合约字节码(forge inspect MinimalERC721 bytecode)
const MINIMAL_ERC721_BYTECODE =
  '0x60806040523461030b576112da803803806100198161030f565b92833981019060408183031261030b5780516001600160401b03811161030b5782610045918301610334565b60208201519092906001600160401b03811161030b576100659201610334565b81516001600160401b038111610221575f54600181811c91168015610301575b602082101461020357601f811161029f575b50602092601f821160011461024057928192935f92610235575b50508160011b915f199060031b1c1916175f555b80516001600160401b03811161022157600154600181811c91168015610217575b602082101461020357601f81116101a0575b50602091601f8211600114610140579181925f92610135575b50508160011b915f199060031b1c1916176001555b604051610f5490816103868239f35b015190505f80610111565b601f1982169260015f52805f20915f5b85811061018857508360019510610170575b505050811b01600155610126565b01515f1960f88460031b161c191690555f8080610162565b91926020600181928685015181550194019201610150565b60015f527fb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6601f830160051c810191602084106101f9575b601f0160051c01905b8181106101ee57506100f8565b5f81556001016101e1565b90915081906101d8565b634e487b7160e01b5f52602260045260245ffd5b90607f16906100e6565b634e487b7160e01b5f52604160045260245ffd5b015190505f806100b1565b601f198216935f8052805f20915f5b868110610287575083600195961061026f575b505050811b015f556100c5565b01515f1960f88460031b161c191690555f8080610262565b9192602060018192868501518155019401920161024f565b5f80527f290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563601f830160051c810191602084106102f7575b601f0160051c01905b8181106102ec5750610097565b5f81556001016102df565b90915081906102d6565b90607f1690610085565b5f80fd5b6040519190601f01601f191682016001600160401b0381118382101761022157604052565b81601f8201121561030b578051906001600160401b03821161022157610363601f8301601f191660200161030f565b928284526020838301011161030b57815f9260208093018386015e830101529056fe6080806040526004361015610012575f80fd5b5f905f3560e01c90816301ffc9a7146109785750806306fdde03146108c0578063081812fc14610884578063095ea7b31461079a57806318160ddd1461077d57806323b872dd146107665780632f745c59146106f457806342842e0e146106cb5780634f6ccce71461067d5780636352211e1461064d5780636a627842146103e857806370a08231146103bd57806395d89b41146102b5578063a22cb4651461021a578063b88d4fde14610190578063c87b56dd146101335763e985e9c5146100d9575f80fd5b346101305760403660031901126101305760406100f4610a21565b916100fd610a37565b9260018060a01b031681526005602052209060018060a01b03165f52602052602060ff60405f2054166040519015158152f35b80fd5b3461018c57602036600319011261018c5761014f600435610eea565b505f60405161015f602082610a87565b52610188604051610171602082610a87565b5f81526040519182916020835260208301906109fd565b0390f35b5f80fd5b3461018c57608036600319011261018c576101a9610a21565b6101b1610a37565b6064359167ffffffffffffffff831161018c573660238401121561018c578260040135916101de83610aa9565b926101ec6040519485610a87565b808452366024828701011161018c576020815f9260246102189801838801378501015260443591610daa565b005b3461018c57604036600319011261018c57610233610a21565b6024359081151580920361018c576001600160a01b03169081156102a257335f52600560205260405f20825f5260205260405f2060ff1981541660ff83161790556040519081527f17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c3160203392a3005b50630b61174360e31b5f5260045260245ffd5b3461018c575f36600319011261018c576040515f6001548060011c906001811680156103b3575b60208310811461039f5782855290811561037b575060011461031d575b6101888361030981850382610a87565b6040519182916020835260208301906109fd565b91905060015f527fb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6915f905b808210610361575090915081016020016103096102f9565b919260018160209254838588010152019101909291610349565b60ff191660208086019190915291151560051b8401909101915061030990506102f9565b634e487b7160e01b5f52602260045260245ffd5b91607f16916102dc565b3461018c57602036600319011261018c5760206103e06103db610a21565b610d79565b604051908152f35b3461018c57602036600319011261018c57610401610a21565b600a54905f1982146105625760018201600a556001600160a01b038116801561063a575f838152600260205260409020546001600160a01b031680158015939192919084610607575b825f52600360205260405f2060018154019055855f52600260205260405f20836bffffffffffffffffffffffff60a01b8254161790558583857fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef5f80a41561058a57600854855f5260096020528060405f2055600160401b81101561057657856104dd8260016104f59401600855610d4d565b90919082549060031b91821b915f19901b1916179055565b818303610522575b50505061050f57602090604051908152f35b6339e3563760e11b5f525f60045260245ffd5b61052b90610d79565b5f19810191908211610562575f52600660205260405f20815f526020528360405f2055835f52600760205260405f205583806104fd565b634e487b7160e01b5f52601160045260245ffd5b634e487b7160e01b5f52604160045260245ffd5b8282146104f55761059a83610d79565b855f52600760205260405f205490845f52600660205260405f20918181036105dc575b50865f5260076020525f60408120555f526020525f60408120556104f5565b815f528260205260405f2054815f52836020528060405f20555f52600760205260405f2055876105bd565b5f86815260046020526040902080546001600160a01b0319169055835f52600360205260405f205f19815401905561044a565b633250574960e11b5f525f60045260245ffd5b3461018c57602036600319011261018c57602061066b600435610eea565b6040516001600160a01b039091168152f35b3461018c57602036600319011261018c576004356008548110156106b5576106a6602091610d4d565b90549060031b1c604051908152f35b63295f44f760e21b5f525f60045260245260445ffd5b3461018c576102186106dc36610a4d565b90604051926106ec602085610a87565b5f8452610daa565b3461018c57604036600319011261018c5761070d610a21565b6024359061071a81610d79565b8210156107495760018060a01b03165f52600660205260405f20905f52602052602060405f2054604051908152f35b63295f44f760e21b5f5260018060a01b031660045260245260445ffd5b3461018c5761021861077736610a4d565b91610ac5565b3461018c575f36600319011261018c576020600854604051908152f35b3461018c57604036600319011261018c576107b3610a21565b6024356107bf81610eea565b33151580610871575b80610844575b6108315781906001600160a01b0384811691167f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9255f80a45f90815260046020526040902080546001600160a01b0319166001600160a01b03909216919091179055005b63a9fbf51f60e01b5f523360045260245ffd5b506001600160a01b0381165f90815260056020908152604080832033845290915290205460ff16156107ce565b506001600160a01b0381163314156107c8565b3461018c57602036600319011261018c576004356108a181610eea565b505f526004602052602060018060a01b0360405f205416604051908152f35b3461018c575f36600319011261018c576040515f5f548060011c9060018116801561096e575b60208310811461039f5782855290811561037b5750600114610912576101888361030981850382610a87565b5f8080527f290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563939250905b808210610954575090915081016020016103096102f9565b91926001816020925483858801015201910190929161093c565b91607f16916108e6565b3461018c57602036600319011261018c576004359063ffffffff60e01b821680920361018c5760209163780e9d6360e01b81149081156109ba575b5015158152f35b6380ac58cd60e01b8114915081156109ec575b81156109db575b50836109b3565b6301ffc9a760e01b149050836109d4565b635b5e139f60e01b811491506109cd565b805180835260209291819084018484015e5f828201840152601f01601f1916010190565b600435906001600160a01b038216820361018c57565b602435906001600160a01b038216820361018c57565b606090600319011261018c576004356001600160a01b038116810361018c57906024356001600160a01b038116810361018c579060443590565b90601f8019910116810190811067ffffffffffffffff82111761057657604052565b67ffffffffffffffff811161057657601f01601f191660200190565b9091906001600160a01b038316801561063a575f838152600260205260409020546001600160a01b03169333151580610cbd575b5084158015610c8a575b825f52600360205260405f2060018154019055845f52600260205260405f20836bffffffffffffffffffffffff60a01b8254161790558483877fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef5f80a415610c0d57600854845f5260096020528060405f2055600160401b81101561057657846104dd826001610b969401600855610d4d565b818503610bcd575b50506001600160a01b0316808303610bb557505050565b6364283d7b60e01b5f5260045260245260445260645ffd5b610bd690610d79565b5f19810191908211610562575f52600660205260405f20815f526020528260405f2055825f52600760205260405f20555f80610b9e565b848214610b9657610c1d85610d79565b845f52600760205260405f205490865f52600660205260405f2091818103610c5f575b50855f5260076020525f60408120555f526020525f6040812055610b96565b815f528260205260405f2054815f52836020528060405f20555f52600760205260405f20555f610c40565b5f85815260046020526040902080546001600160a01b0319169055855f52600360205260405f205f198154019055610b03565b80610cfc575b15610cce575f610af9565b8385610ce657637e27328960e01b5f5260045260245ffd5b63177e802f60e01b5f523360045260245260445ffd5b503385148015610d2b575b80610cc357505f848152600460205260409020546001600160a01b03163314610cc3565b505f85815260056020908152604080832033845290915290205460ff16610d07565b600854811015610d655760085f5260205f2001905f90565b634e487b7160e01b5f52603260045260245ffd5b6001600160a01b03168015610d97575f52600360205260405f205490565b6322718ad960e21b5f525f60045260245ffd5b9291610db7818386610ac5565b813b610dc4575b50505050565b604051630a85bd0160e11b81523360048201526001600160a01b0394851660248201526044810191909152608060648201529216919060209082908190610e0f9060848301906109fd565b03815f865af15f9181610ea5575b50610e7257503d15610e6b573d610e3381610aa9565b90610e416040519283610a87565b81523d5f602083013e5b80519081610e665782633250574960e11b5f5260045260245ffd5b602001fd5b6060610e4b565b6001600160e01b03191663757a42ff60e11b01610e9357505f808080610dbe565b633250574960e11b5f5260045260245ffd5b9091506020813d602011610ee2575b81610ec160209383610a87565b8101031261018c57516001600160e01b03198116810361018c57905f610e1d565b3d9150610eb4565b5f818152600260205260409020546001600160a01b0316908115610f0c575090565b637e27328960e01b5f5260045260245ffdfea264697066735822122063131dcbf3ce6432bfe683483af6349518e5086140d8debd588b5c00198d941f64736f6c634300081e0033';

export default function NFTMarket() {
  const [isMounted, setIsMounted] = useState(false);
  const [activeTab, setActiveTab] = useState<'deploy' | 'mint' | 'listings' | 'my-nfts'>('listings');
  const [nftName, setNftName] = useState('');
  const [mintTo, setMintTo] = useState('');
  const [nftUri, setNftUri] = useState('');
  const [selectedNftContract, setSelectedNftContract] = useState<`0x${string}` | null>(null);
  const [nftPrice, setNftPrice] = useState('');
  const [deployedNfts, setDeployedNfts] = useState<NFTContract[]>([]);
  const [listings, setListings] = useState<Listing[]>([]);
  const [userNfts, setUserNfts] = useState<NFTToken[]>([]);
  const [paymentTokenBalance, setPaymentTokenBalance] = useState<bigint>(0n);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [nextListingId, setNextListingId] = useState<bigint>(0n);

  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { data: walletClient } = useWalletClient();

  const { writeContract, isPending: isWritePending, data: hash } = useWriteContract();
  // 监听交易结果并显示相应消息

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  useEffect(() => {
    setIsMounted(true);
  }, []);

  // 删除已部署的NFT合约
  const handleRemoveDeployedNft = (nftAddress: `0x${string}`) => {
    const updated = deployedNfts.filter(nft => nft.address !== nftAddress);
    localStorage.setItem(`deployedNfts_${address}`, JSON.stringify(updated));
    setDeployedNfts(updated);
    showMessage(`Removed NFT contract: ${nftAddress}`);
  };

  // 获取用户支付代币余额
  const { data: tokenBalance, error: tokenBalanceError } = useReadContract({
    address: CONTRACTS.ERC1363_TOKEN,
    abi: ERC1363_ABI,
    functionName: 'balanceOf',
    args: [address],
  });

  if (tokenBalanceError) {
    console.error('Error fetching token balance:', tokenBalanceError);
  }

  useEffect(() => {
    if (tokenBalance !== undefined) {
      setPaymentTokenBalance(tokenBalance as bigint);
    }
  }, [tokenBalance]);

  // 获取 nextListingId
  const { data: nextId, error: nextIdError } = useReadContract({
    address: CONTRACTS.NFT_MARKET_V2,
    abi: NFT_MARKET_V2_ABI,
    functionName: 'nextListingId',
  });

  if (nextIdError) {
    console.error('Error fetching nextListingId:', nextIdError);
  }

  useEffect(() => {
    if (nextId !== undefined) {
      setNextListingId(nextId as bigint);
    }
  }, [nextId]);

  const fetchDeployedNfts = useCallback(async () => {
    // 从 localStorage 获取已部署的 NFT
    const stored = localStorage.getItem(`deployedNfts_${address}`);
    setDeployedNfts(stored ? JSON.parse(stored) : []);
  }, [address]);

  // 加载本地存储的已部署合约
  useEffect(() => {
    if (address) {
      fetchDeployedNfts().catch((error: any) => console.error('Error fetching deployed NFTs:', error));
    }
  }, [address, fetchDeployedNfts]);

  // 获取所有上架的 NFT
  const fetchListings = useCallback(async () => {
    const listingsArray: Listing[] = [];
    for (let i = 0n; i < nextListingId; i++) {
      try {
        const listing = await publicClient.readContract({
          address: CONTRACTS.NFT_MARKET_V2,
          abi: NFT_MARKET_V2_ABI,
          functionName: 'listings',
          args: [i],
        });
        console.log(`Listing ${i}:`, listing);
        if (listing) {
          const [seller, nftContract, tokenId, price, isActive] = listing as [string, string, bigint, bigint, boolean];
          if (isActive) {
            listingsArray.push({
              id: i,
              seller: seller as `0x${string}`,
              nftContract: nftContract as `0x${string}`,
              tokenId,
              price,
              isActive,
            });
          }
        }
      } catch (error) {
        console.error(`Error fetching listing ${i}:`, error);
        // 继续处理其他列表项
      }
    }
    setListings(listingsArray);
  }, [nextListingId]);

  // 获取用户拥有的 NFT
  const fetchUserNFTs = useCallback(async () => {
    const nfts: NFTToken[] = [];
    for (const contract of deployedNfts) {
      try {
        const balance = await publicClient.readContract({
          address: contract.address as `0x${string}`,
          abi: MINIMAL_ERC721_ABI,
          functionName: 'balanceOf',
          args: [address],
        });
        const bal = Number(balance as bigint);
        console.log(`${contract.name} has ${bal} NFTs`);
        for (let index = 0; index < bal; index++) {
          const tokenId = await publicClient.readContract({
            address: contract.address as `0x${string}`,
            abi: MINIMAL_ERC721_ABI,
            functionName: 'tokenOfOwnerByIndex',
            args: [address, BigInt(index)],
          });
          const owner = await publicClient.readContract({
            address: contract.address as `0x${string}`,
            abi: MINIMAL_ERC721_ABI,
            functionName: 'ownerOf',
            args: [tokenId],
          });
          nfts.push({ contractAddress: contract.address, tokenId: tokenId as bigint, owner: owner as `0x${string}` });
        }
      } catch (error) {
        console.error(`Error fetching NFTs from contract ${contract.address}:`, error);
        // 继续处理其他合约
      }
    }
    setUserNfts(nfts);
  }, [deployedNfts, address]);

  useEffect(() => {
    if (isConnected) {
      fetchListings().catch((error: any) => console.error('Error fetching listings:', error));
      fetchUserNFTs().catch((error: any) => console.error('Error fetching user NFTs:', error));
    }
  }, [isConnected, fetchListings, fetchUserNFTs]);

  // 消息显示函数
  const showMessage = (message: string, isError: boolean = false) => {
    if (isError) {
      setErrorMessage(message);
      setSuccessMessage(null);
    } else {
      setSuccessMessage(message);
      setErrorMessage(null);
    }
    setTimeout(() => {
      setErrorMessage(null);
      setSuccessMessage(null);
    }, 5000);
  };

  // 部署 NFT 合约
  const handleDeployContract = async () => {
    if (!nftName) {
      showMessage('Please fill in NFT name', true);
      return;
    }
    if (!address) {
      showMessage('Please connect your wallet first', true);
      return;
    }
    if (!walletClient) {
      showMessage('Wallet client not available. Please check your wallet connection.', true);
      return;
    }

    setIsLoading(true);
    try {
      const hash = await walletClient.deployContract({
        abi: MINIMAL_ERC721_ABI,
        bytecode: MINIMAL_ERC721_BYTECODE as `0x${string}`,
        args: [nftName, nftName.substring(0, 3).toUpperCase()], // name and symbol
      });

      showMessage(`Transaction submitted: ${hash}`);

      // 手动等待收据
      const receipt = await waitForTransactionReceipt(walletClient, { hash });

      if (!receipt.contractAddress) {
        showMessage('No contract address in receipt', true);
        return;
      }

      const nftAddress = receipt.contractAddress as `0x${string}`;

      // 存储到 localStorage
      const newNft: NFTContract = {
        address: nftAddress,
        name: nftName,
        owner: address,
      };

      // 自动授权市场合约操作这个新 NFT 合约的所有 NFT
      const approveHash = await walletClient.writeContract({
        address: nftAddress,
        abi: MINIMAL_ERC721_ABI,
        functionName: 'setApprovalForAll',
        args: [CONTRACTS.NFT_MARKET_V2, true], // 授权市场合约
      });

      // 等待授权交易确认
      await waitForTransactionReceipt(walletClient, { hash: approveHash });

      const updated = [...deployedNfts, newNft];
      localStorage.setItem(`deployedNfts_${address}`, JSON.stringify(updated));
      setDeployedNfts(updated);
      showMessage(`Deployed successfully: ${nftAddress}`);
    } catch (error) {
      showMessage((error as Error).message, true);
    } finally {
      setIsLoading(false);
    }
  };

  // 铸造 NFT
  const handleMintNFT = () => {
    if (!selectedNftContract || !mintTo) {
      showMessage('Please select contract and fill in mint to address', true);
      return;
    }

    writeContract({
      address: selectedNftContract,
      abi: MINIMAL_ERC721_ABI,
      functionName: 'mint',
      args: [mintTo as `0x${string}`],
    });
  };

  // 使用签名上架 NFT
  const handleListWithSignature = async (contractAddress: string, nftTokenId: bigint, nftPrice: string) => {
    if (!walletClient) {
      showMessage('Wallet client not available. Please check your wallet connection.', true);
      return;
    }

    if (!address) {
      showMessage('Please connect your wallet first', true);
      return;
    }

    try {
      // 计算截止时间（从 utils 中导入的函数）
      const deadlineNum = await calculateDeadline();
      const price = parseEther(nftPrice);

      // 根据合约规则生成消息哈希（使用修复后的函数）
      const messageHash = (await publicClient.readContract({
        address: CONTRACTS.NFT_MARKET_V2,
        abi: NFT_MARKET_V2_ABI,
        functionName: 'getListingMessageHash',
        args: [contractAddress, nftTokenId, price, deadlineNum],
      })) as `0x${string}`;
      console.log('messageHash', messageHash);

      // 对原始消息进行签名（重要：直接对messageHash进行签名，而不是对eth签名格式进行签名）
      const signature = await walletClient.signMessage({
        account: address as `0x${string}`,
        message: { raw: messageHash },
      });

      console.log('contractAddress', contractAddress);
      console.log('nftTokenId', nftTokenId);
      console.log('price', price);
      console.log('deadlineNum', deadlineNum);
      console.log('signature', signature);

      writeContract({
        address: CONTRACTS.NFT_MARKET_V2,
        abi: NFT_MARKET_V2_ABI,
        functionName: 'listWithSignature',
        args: [contractAddress, nftTokenId, price, deadlineNum, signature],
      });
    } catch (error: any) {
      console.error('Error listing with signature:', error);
      showMessage((error as Error).message, true);
    }
  };

  // 取消上架
  const handleCancelListing = (listingId: bigint) => {
    writeContract({
      address: CONTRACTS.NFT_MARKET_V2,
      abi: NFT_MARKET_V2_ABI,
      functionName: 'cancelListing',
      args: [listingId],
      gas: 300000n,
    });
  };

  // 购买 NFT
  const handleBuyNFT = (listingId: bigint, price: bigint) => {
    console.log('listingId', listingId);
    const data = encodeAbiParameters([{ type: 'uint256' }], [listingId]);
    writeContract({
      address: CONTRACTS.ERC1363_TOKEN,
      abi: ERC1363_ABI,
      functionName: 'transferAndCall',
      args: [CONTRACTS.NFT_MARKET_V2, price, data],
      gas: 500000n,
    });
  };

  // 根据交易状态显示消息
  useEffect(() => {
    if (isConfirmed) {
      showMessage('Transaction completed successfully');
      // 重新获取列表信息以更新UI
      fetchListings().catch((error: any) => console.error('Error fetching listings:', error));
      fetchUserNFTs().catch((error: any) => console.error('Error fetching user NFTs:', error));
    }
  }, [isConfirmed, fetchListings, fetchUserNFTs]);

  useEffect(() => {
    if (hash && !isConfirming && !isConfirmed) {
      // 交易失败
      showMessage('Transaction failed', true);
    }
  }, [hash, isConfirming, isConfirmed]);

  if (!isMounted) {
    return <div>Loading wallet connection...</div>; // SSR 时显示占位
  }

  return (
    <div className='min-h-screen bg-gray-50'>
      <header className='bg-white shadow'>
        <div className='max-w-7xl mx-auto px-4 py-4 flex justify-between items-center'>
          <h1 className='text-2xl font-bold text-gray-900'>NFT Market</h1>
          <div className='flex items-center space-x-4'>
            {isConnected ? (
              <div className='text-sm'>
                Token Balance: {Number(paymentTokenBalance) / 1e18} PTK
                <button
                  onClick={() => disconnect()}
                  className='ml-4 px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600'
                >
                  Disconnect
                </button>
              </div>
            ) : (
              <div>
                {connectors.map(connector => (
                  <button
                    className='bg-blue-500 hover:bg-blue-700 text-white py-2 px-4 rounded'
                    key={connector.id}
                    onClick={() => connect({ connector })}
                  >
                    连接 {connector.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </header>

      <main className='max-w-7xl mx-auto px-4 py-8'>
        {errorMessage && <div className='bg-red-100 p-4 mb-4 rounded'>{errorMessage}</div>}
        {successMessage && <div className='bg-green-100 p-4 mb-4 rounded'>{successMessage}</div>}

        <div className='flex space-x-4 mb-8'>
          <button
            onClick={() => setActiveTab('listings')}
            className={`px-4 py-2 rounded ${activeTab === 'listings' ? 'bg-indigo-600 text-white' : 'bg-gray-200'}`}
          >
            Market Listings
          </button>
          <button
            onClick={async () => {
              setActiveTab('my-nfts');
              await fetchUserNFTs();
            }}
            className={`px-4 py-2 rounded ${activeTab === 'my-nfts' ? 'bg-indigo-600 text-white' : 'bg-gray-200'}`}
          >
            My NFTs
          </button>
          <button
            onClick={() => setActiveTab('deploy')}
            className={`px-4 py-2 rounded ${activeTab === 'deploy' ? 'bg-indigo-600 text-white' : 'bg-gray-200'}`}
          >
            Deploy NFT Contract
          </button>
          <button
            onClick={() => setActiveTab('mint')}
            className={`px-4 py-2 rounded ${activeTab === 'mint' ? 'bg-indigo-600 text-white' : 'bg-gray-200'}`}
          >
            Mint NFT
          </button>
        </div>

        {activeTab === 'listings' && (
          <MarketListings
            listings={listings}
            isLoading={isLoading}
            handleBuyNFT={handleBuyNFT}
            handleCancelListing={handleCancelListing}
            showMessage={showMessage}
          />
        )}

        {activeTab === 'my-nfts' && (
          <MyNFTs
            userNfts={userNfts}
            isLoading={isLoading}
            nftPrice={nftPrice}
            setNftPrice={setNftPrice}
            handleListWithSignature={handleListWithSignature}
          />
        )}

        {activeTab === 'deploy' && (
          <DeployContract
            nftName={nftName}
            setNftName={setNftName}
            handleDeployContract={handleDeployContract}
            handleRemoveDeployedNft={handleRemoveDeployedNft}
            isWritePending={isWritePending}
            isLoading={isLoading}
            deployedNfts={deployedNfts}
          />
        )}

        {activeTab === 'mint' && (
          <MintNFT
            selectedNftContract={selectedNftContract}
            setSelectedNftContract={setSelectedNftContract}
            mintTo={mintTo}
            setMintTo={setMintTo}
            nftUri={nftUri}
            setNftUri={setNftUri}
            handleMintNFT={handleMintNFT}
            handleRemoveDeployedNft={handleRemoveDeployedNft}
            isWritePending={isWritePending}
            isLoading={isLoading}
            deployedNfts={deployedNfts}
          />
        )}
      </main>
    </div>
  );
}
