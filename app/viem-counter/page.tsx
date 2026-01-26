'use client';

import { useState, useEffect, useCallback } from 'react';
import { createPublicClient, createWalletClient, http, formatEther, getContract, custom, publicActions } from 'viem';
import { foundry, sepolia } from 'viem/chains';
import Counter_ABI from '@/abis/Counter.json';

// 支持的链
const SUPPORTED_CHAINS = [foundry, sepolia] as const;

// Counter 合约地址
const COUNTER_ADDRESS_FOUNDRY = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const COUNTER_ADDRESS_SEPOLIA = '0x7B6781B15b4f3eF8476af20Ed45Cf6d09e0Ef55F';

function getCounterAddress(chainId: number) {
  return chainId === foundry.id ? COUNTER_ADDRESS_FOUNDRY : COUNTER_ADDRESS_SEPOLIA;
}

function getPublicClient(chainId: number) {
  const chain = SUPPORTED_CHAINS.find(c => c.id === chainId) ?? foundry;
  return createPublicClient({
    chain,
    transport: http(),
  }).extend(publicActions);
}

export default function Home() {
  const [balance, setBalance] = useState<string>('0');
  const [counterNumber, setCounterNumber] = useState<string>('0');
  const [address, setAddress] = useState<`0x${string}` | undefined>();
  const [isConnected, setIsConnected] = useState(false);
  const [chainId, setChainId] = useState<number | undefined>();
  const [isLoading, setIsLoading] = useState(false);

  const currentChain = SUPPORTED_CHAINS.find(c => c.id === chainId);

  // 创建 walletClient（只在需要签名时创建）
  const getWalletClient = useCallback(() => {
    if (!window.ethereum || !chainId || !address) return null;
    const chain = SUPPORTED_CHAINS.find(c => c.id === chainId) ?? foundry;
    return createWalletClient({
      account: address,
      chain,
      transport: custom(window.ethereum),
    }).extend(publicActions);
  }, [address, chainId]);

  // 获取 Counter 合约的数值
  const fetchCounterNumber = useCallback(async () => {
    if (!chainId) return;
    try {
      const client = getPublicClient(chainId);
      const contract = getContract({
        address: getCounterAddress(chainId),
        abi: Counter_ABI,
        client,
      });
      const num = (await contract.read.number()) as bigint;
      setCounterNumber(num.toString());
    } catch (err) {
      console.error('读取 Counter 失败', err);
    }
  }, [chainId]);

  // 读取余额
  const fetchBalance = useCallback(async () => {
    if (!address || !chainId) return;
    try {
      const client = getPublicClient(chainId);
      const bal = await client.getBalance({ address });
      setBalance(formatEther(bal));
    } catch (err) {
      console.error('读取余额失败', err);
    }
  }, [address, chainId]);

  // 连接钱包
  const connectWallet = async () => {
    if (typeof window.ethereum === 'undefined') {
      alert('请安装 MetaMask');
      return;
    }
    try {
      setIsLoading(true);
      const [address] = await window.ethereum.request({ method: 'eth_requestAccounts' });
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      setAddress(address as `0x${string}`);
      setChainId(Number(chainId));
      setIsConnected(true);
    } catch (error) {
      console.error('连接钱包失败:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // 断开连接
  const disconnectWallet = useCallback(async () => {
    if (!address || !window.ethereum || !chainId) return;
    setIsConnected(false);
    setAddress(undefined);
    setChainId(undefined);
    setBalance('0');
    setCounterNumber('0');
    try {
      // 对于 MetaMask 10.28+
      await window.ethereum.request({
        method: 'wallet_revokePermissions',
        params: [{ eth_accounts: {} }],
      });
      // 老版本 MM 会抛 4200 错误，捕获即可
    } catch (e: unknown) {
      if (typeof e === 'object' && e !== null && 'code' in e && (e as { code: unknown }).code === 4200) {
        alert('请手动在钱包里断开本次连接');
      }
    }
  }, [address, chainId]);

  // 调用 increment 函数
  const handleIncrement = async () => {
    if (!address || !window.ethereum || !chainId) return;
    const walletClient = getWalletClient();
    if (!walletClient) return alert('钱包未连接');
    try {
      setIsLoading(true);
      const hash = await walletClient.writeContract({
        address: getCounterAddress(chainId),
        abi: Counter_ABI,
        functionName: 'increment',
        account: address,
      });
      console.log('Transaction hash:', hash);

      const receipt = await walletClient.waitForTransactionReceipt({ hash: hash });
      console.log(`交易状态: ${receipt.status === 'success' ? '成功' : '失败'}`);

      // 更新数值显示
      await fetchCounterNumber();
    } catch (error) {
      console.error('调用 increment 失败:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // 全局监听（只添加一次）
  useEffect(() => {
    if (!window.ethereum) return;

    const handleAccountsChanged = (accounts: string[]) => {
      console.log('账户变化', accounts);
      if (accounts.length === 0) {
        disconnectWallet().catch(console.error);
      } else {
        setAddress(accounts[0] as `0x${string}`);
      }
    };

    const handleChainChanged = (chainIdHex: string) => {
      console.log('网络变化', chainIdHex);
      setChainId(Number(chainIdHex));
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);

    return () => {
      window.ethereum?.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum?.removeListener('chainChanged', handleChainChanged);
    };
  }, [address, disconnectWallet, fetchBalance, fetchCounterNumber]);

  // 连接后自动读取数据
  useEffect(() => {
    if (address && chainId) {
      console.log('连接后自动读取数据:', address);
      fetchBalance().catch(console.error);
      fetchCounterNumber().catch(console.error);
    }
  }, [address, chainId, fetchBalance, fetchCounterNumber]);

  return (
    <div className='min-h-screen flex flex-col items-center justify-center p-8'>
      <h1 className='text-3xl font-bold mb-8'>Simple Viem Demo</h1>

      <div className='bg-white p-6 rounded-lg shadow-lg w-full max-w-2xl'>
        {!isConnected ? (
          <button
            onClick={connectWallet}
            disabled={isLoading}
            className='w-full bg-blue-500 text-white py-2 px-4 rounded hover:bg-blue-600 transition-colors'
          >
            {isLoading ? '连接中...' : '连接 MetaMask'}
          </button>
        ) : (
          <div className='space-y-4'>
            <div className='text-center'>
              <p className='text-gray-600'>钱包地址:</p>
              <p className='font-mono break-all'>{address}</p>
            </div>
            <div className='text-center'>
              <p className='text-gray-600'>当前网络:</p>
              <p className='font-mono'>
                {currentChain?.name || '未知网络'} (Chain ID: {chainId})
              </p>
            </div>
            <div className='text-center'>
              <p className='text-gray-600'>余额:</p>
              <p className='font-mono'>{balance} ETH</p>
            </div>
            <div className='text-center'>
              <p className='text-gray-600'>Counter 数值:</p>
              <p className='font-mono'>{counterNumber}</p>
              <button
                onClick={handleIncrement}
                disabled={isLoading}
                className='mt-2 w-full bg-green-500 text-white py-2 px-4 rounded hover:bg-green-600 transition-colors'
              >
                {isLoading ? '交易进行中...' : '增加计数'}
              </button>
            </div>
            <button
              onClick={disconnectWallet}
              className='w-full bg-red-500 text-white py-2 px-4 rounded hover:bg-red-600 transition-colors'
            >
              断开连接
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
