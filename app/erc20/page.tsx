'use client';

import { useCallback, useEffect, useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, formatEther, type Address } from 'viem';
import MyERC20_ABI from '@/abis/MyERC20.json';

// MyERC20 合约地址
const MY_ERC20_ADDRESS = '0x4826533B4897376654Bb4d4AD88B7faFD0C98528';

export default function ERC20Page() {
  const [toAddress, setToAddress] = useState('');
  const [amount, setAmount] = useState('');
  const [callbackData, setCallbackData] = useState('0x');
  const [approveSpender, setApproveSpender] = useState('');
  const [approveAmount, setApproveAmount] = useState('');
  const [fromAddress, setFromAddress] = useState('');
  const [transferFromAmount, setTransferFromAmount] = useState('');
  const [txHash, setTxHash] = useState('');
  const [activeTab, setActiveTab] = useState('transfer');

  const { address, isConnected } = useAccount();

  // 读取代币信息
  const { data: name } = useReadContract({
    address: MY_ERC20_ADDRESS,
    abi: MyERC20_ABI,
    functionName: 'name',
  });

  const { data: symbol } = useReadContract({
    address: MY_ERC20_ADDRESS,
    abi: MyERC20_ABI,
    functionName: 'symbol',
  });

  const { data: decimals } = useReadContract({
    address: MY_ERC20_ADDRESS,
    abi: MyERC20_ABI,
    functionName: 'decimals',
  });

  const { data: totalSupply } = useReadContract({
    address: MY_ERC20_ADDRESS,
    abi: MyERC20_ABI,
    functionName: 'totalSupply',
  });

  // 读取余额
  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: MY_ERC20_ADDRESS,
    abi: MyERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // 读取授权额度
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: MY_ERC20_ADDRESS,
    abi: MyERC20_ABI,
    functionName: 'allowance',
    args: address && approveSpender ? [address, approveSpender as Address] : undefined,
    query: {
      enabled: !!address && !!approveSpender,
    },
  });

  // 写入合约操作
  const { writeContractAsync, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash as `0x${string}`,
  });

  // 转账操作
  const handleTransfer = async () => {
    if (!address || !toAddress || !amount) return;

    try {
      const hash = await writeContractAsync({
        address: MY_ERC20_ADDRESS,
        abi: MyERC20_ABI,
        functionName: 'transfer',
        args: [toAddress as Address, parseEther(amount)],
      });
      setTxHash(hash);
      console.log('转账交易已发送:', hash);
    } catch (error) {
      console.error('转账失败:', error);
    }
  };

  // 带回调的转账操作
  const handleTransferWithCallback = async () => {
    if (!address || !toAddress || !amount) return;

    try {
      const hash = await writeContractAsync({
        address: MY_ERC20_ADDRESS,
        abi: MyERC20_ABI,
        functionName: 'transferWithCallback',
        args: [toAddress as Address, parseEther(amount), callbackData as `0x${string}`],
      });
      setTxHash(hash);
      console.log('带回调转账交易已发送:', hash);
    } catch (error) {
      console.error('带回调转账失败:', error);
    }
  };

  // 授权操作
  const handleApprove = async () => {
    if (!address || !approveSpender || !approveAmount) return;

    try {
      const hash = await writeContractAsync({
        address: MY_ERC20_ADDRESS,
        abi: MyERC20_ABI,
        functionName: 'approve',
        args: [approveSpender as Address, parseEther(approveAmount)],
      });
      setTxHash(hash);
      console.log('授权交易已发送:', hash);
    } catch (error) {
      console.error('授权失败:', error);
    }
  };

  // 从某地址转账（需要授权）
  const handleTransferFrom = async () => {
    if (!fromAddress || !toAddress || !transferFromAmount) return;

    try {
      const hash = await writeContractAsync({
        address: MY_ERC20_ADDRESS,
        abi: MyERC20_ABI,
        functionName: 'transferFrom',
        args: [fromAddress as Address, toAddress as Address, parseEther(transferFromAmount)],
      });
      setTxHash(hash);
      console.log('transferFrom交易已发送:', hash);
    } catch (error) {
      console.error('transferFrom失败:', error);
    }
  };

  // 刷新数据
  const refreshData = useCallback(() => {
    refetchBalance();
    if (approveSpender) {
      refetchAllowance();
    }
  }, [refetchBalance, refetchAllowance, approveSpender]);

  // 自动刷新数据
  useEffect(() => {
    refreshData();
  }, [isConfirmed, refreshData]);

  // 根据连接状态显示UI
  if (!isConnected) {
    return (
      <div className='flex min-h-screen flex-col items-center justify-center p-24'>
        <h1 className='text-4xl font-bold mb-8'>MyERC20 代币交互</h1>
        <p className='text-xl'>请先连接钱包</p>
      </div>
    );
  }

  return (
    <div className='flex min-h-screen flex-col items-center justify-center p-8'>
      <h1 className='text-3xl font-bold mb-6'>MyERC20 代币交互</h1>

      {/* 代币信息 */}
      <div className='w-full max-w-2xl bg-white p-6 rounded-lg shadow-md mb-6'>
        <h2 className='text-xl font-semibold mb-4'>代币信息</h2>
        <div className='grid grid-cols-2 gap-4'>
          <div>
            <p className='text-gray-600'>名称:</p>
            <p className='font-medium'>{(name as string) || '加载中...'}</p>
          </div>
          <div>
            <p className='text-gray-600'>符号:</p>
            <p className='font-medium'>{(symbol as string) || '加载中...'}</p>
          </div>
          <div>
            <p className='text-gray-600'>小数位:</p>
            <p className='font-medium'>{decimals ? decimals.toString() : '加载中...'}</p>
          </div>
          <div>
            <p className='text-gray-600'>总供应量:</p>
            <p className='font-medium'>{totalSupply && decimals ? formatEther(totalSupply as bigint) : '加载中...'}</p>
          </div>
        </div>
      </div>

      {/* 账户信息 */}
      <div className='w-full max-w-2xl bg-white p-6 rounded-lg shadow-md mb-6'>
        <h2 className='text-xl font-semibold mb-4'>账户信息</h2>
        <div className='grid grid-cols-2 gap-4'>
          <div>
            <p className='text-gray-600'>钱包地址:</p>
            <p className='font-mono break-all'>{address}</p>
          </div>
          <div>
            <p className='text-gray-600'>余额:</p>
            <p className='font-medium'>
              {balance && decimals ? formatEther(balance as bigint) : '0'} {(symbol as string) || 'TOKEN'}
              <button onClick={refreshData} className='ml-2 text-blue-500 hover:text-blue-700'>
                🔄
              </button>
            </p>
          </div>
        </div>
      </div>

      {/* 操作选项卡 */}
      <div className='w-full max-w-2xl bg-white p-6 rounded-lg shadow-md'>
        <div className='flex border-b mb-4'>
          <button
            className={`px-4 py-2 font-medium ${activeTab === 'transfer' ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500'}`}
            onClick={() => setActiveTab('transfer')}
          >
            转账
          </button>
          <button
            className={`px-4 py-2 font-medium ${activeTab === 'callback' ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500'}`}
            onClick={() => setActiveTab('callback')}
          >
            带回调转账
          </button>
          <button
            className={`px-4 py-2 font-medium ${activeTab === 'approve' ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500'}`}
            onClick={() => setActiveTab('approve')}
          >
            授权
          </button>
          <button
            className={`px-4 py-2 font-medium ${activeTab === 'transferFrom' ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500'}`}
            onClick={() => setActiveTab('transferFrom')}
          >
            代付转账
          </button>
        </div>

        {/* 转账面板 */}
        {activeTab === 'transfer' && (
          <div className='space-y-4'>
            <h3 className='text-lg font-medium'>转账</h3>
            <div className='space-y-3'>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>接收地址</label>
                <input
                  type='text'
                  value={toAddress}
                  onChange={e => setToAddress(e.target.value as Address)}
                  placeholder='0x...'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>转账金额</label>
                <input
                  type='number'
                  value={amount}
                  onChange={e => setAmount(e.target.value)}
                  placeholder='0.0'
                  className='w-full p-2 border rounded'
                />
              </div>
              <button
                onClick={handleTransfer}
                disabled={isPending || !toAddress || !amount}
                className='w-full bg-blue-500 text-white py-2 px-4 rounded hover:bg-blue-600 disabled:bg-gray-300'
              >
                {isPending ? '处理中...' : '转账'}
              </button>
            </div>
          </div>
        )}

        {/* 带回调转账面板 */}
        {activeTab === 'callback' && (
          <div className='space-y-4'>
            <h3 className='text-lg font-medium'>带回调转账</h3>
            <div className='space-y-3'>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>接收地址</label>
                <input
                  type='text'
                  value={toAddress}
                  onChange={e => setToAddress(e.target.value as Address)}
                  placeholder='0x...'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>转账金额</label>
                <input
                  type='number'
                  value={amount}
                  onChange={e => setAmount(e.target.value)}
                  placeholder='0.0'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>回调数据 (可选)</label>
                <input
                  type='text'
                  value={callbackData}
                  onChange={e => setCallbackData(e.target.value)}
                  placeholder='0x...'
                  className='w-full p-2 border rounded'
                />
              </div>
              <button
                onClick={handleTransferWithCallback}
                disabled={isPending || !toAddress || !amount}
                className='w-full bg-green-500 text-white py-2 px-4 rounded hover:bg-green-600 disabled:bg-gray-300'
              >
                {isPending ? '处理中...' : '带回调转账'}
              </button>
            </div>
          </div>
        )}

        {/* 授权面板 */}
        {activeTab === 'approve' && (
          <div className='space-y-4'>
            <h3 className='text-lg font-medium'>授权</h3>
            <div className='space-y-3'>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>授权给 (spender)</label>
                <input
                  type='text'
                  value={approveSpender}
                  onChange={e => setApproveSpender(e.target.value as Address)}
                  placeholder='0x...'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>授权金额</label>
                <input
                  type='number'
                  value={approveAmount}
                  onChange={e => setApproveAmount(e.target.value)}
                  placeholder='0.0'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div className='text-sm text-gray-500'>
                当前授权额度: {allowance && decimals ? formatEther(allowance as bigint) : '0'} {symbol as string}
              </div>
              <button
                onClick={handleApprove}
                disabled={isPending || !approveSpender || !approveAmount}
                className='w-full bg-yellow-500 text-white py-2 px-4 rounded hover:bg-yellow-600 disabled:bg-gray-300'
              >
                {isPending ? '处理中...' : '授权'}
              </button>
            </div>
          </div>
        )}

        {/* 代付转账面板 */}
        {activeTab === 'transferFrom' && (
          <div className='space-y-4'>
            <h3 className='text-lg font-medium'>代付转账 (Transfer From)</h3>
            <div className='space-y-3'>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>发送地址 (from)</label>
                <input
                  type='text'
                  value={fromAddress}
                  onChange={e => setFromAddress(e.target.value as Address)}
                  placeholder='0x...'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>接收地址 (to)</label>
                <input
                  type='text'
                  value={toAddress}
                  onChange={e => setToAddress(e.target.value as Address)}
                  placeholder='0x...'
                  className='w-full p-2 border rounded'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>转账金额</label>
                <input
                  type='number'
                  value={transferFromAmount}
                  onChange={e => setTransferFromAmount(e.target.value)}
                  placeholder='0.0'
                  className='w-full p-2 border rounded'
                />
              </div>
              <button
                onClick={handleTransferFrom}
                disabled={isPending || !fromAddress || !toAddress || !transferFromAmount}
                className='w-full bg-purple-500 text-white py-2 px-4 rounded hover:bg-purple-600 disabled:bg-gray-300'
              >
                {isPending ? '处理中...' : '代付转账'}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* 交易状态显示 */}
      {(isConfirming || isConfirmed) && (
        <div className='w-full max-w-2xl mt-6 p-4 bg-gray-100 rounded-lg'>
          <h3 className='font-medium'>交易状态</h3>
          {isConfirming && <p>等待确认: {txHash}</p>}
          {isConfirmed && (
            <div>
              <p className='text-green-600'>交易成功!</p>
              <p className='text-sm text-gray-500 break-all'>交易哈希: {txHash}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
