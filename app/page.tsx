'use client';

import Link from 'next/link';

const demoList = [
  { href: '/viem-counter', title: 'viem 读写 Counter 合约' },
  { href: '/tokenbank', title: 'viem 读写 TokenBank 合约' },
  { href: '/appkit-demo', title: 'AppKit 登录演示' },
  { href: '/tokenbank-permit', title: 'TokenBank Permit 离线签名' },
  { href: '/wagmi-eip712', title: 'wagmi EIP-712 签名验证' },
  { href: '/viem-eip712', title: 'viem EIP-712 签名验证' },
  { href: '/siwe', title: 'SIWE 登录演示' },
  { href: '/erc20', title: 'ERC20 代币交互' },
  { href: '/scan-transfer', title: '查询 ERC20 转账记录' },
  { href: '/nft-market', title: 'NFT 交易市场' },
];

export default function Home() {
  return (
    <div
      className='min-h-screen flex flex-col items-center justify-center p-4'
      style={{
        background: 'linear-gradient(135deg, #f5f7fa 0%, #e4edf5 100%)',
      }}
    >
      <div className='max-w-7xl w-full px-1'>
        <div className='text-center mb-12'>
          <h1 className='text-4xl md:text-5xl font-bold bg-gradient-to-r from-purple-600 to-blue-500 bg-clip-text text-transparent mb-4'>
            开始区块链学习之旅
          </h1>
          <p className='text-lg text-gray-600 max-w-md mx-auto'>探索 Web3 技术，从基础到高级应用</p>
        </div>

        <div className='grid grid-cols-4 gap-5'>
          {demoList.map((demo, index) => (
            <Link key={demo.href} href={demo.href} target='_blank' rel='noopener noreferrer' className='block'>
              <div
                className={`
                bg-white rounded-xl shadow-md p-6 transition-all duration-300
                hover:shadow-lg hover:-translate-y-1 border border-gray-100
                hover:border-purple-200 group flex flex-col h-32
              `}
              >
                <div className='flex items-start flex-grow'>
                  <div
                    className={`
                    flex-shrink-0 w-10 h-10 rounded-lg bg-gradient-to-br
                    from-purple-500 to-blue-500 flex items-center
                    justify-center text-white font-bold mr-4 mt-0.5
                  `}
                  >
                    {index + 1}
                  </div>
                  <div className='flex-grow min-w-0'>
                    <h3 className='text-lg font-semibold text-gray-800 group-hover:text-purple-600 transition-colors'>
                      {demo.title}
                    </h3>
                  </div>
                </div>
                <div className='mt-auto  flex items-center justify-end space-x-1'>
                  <p className='text-sm text-gray-500'>点击进入演示</p>
                  <div className='text-purple-500 group-hover:translate-x-1 transition-transform'>→</div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
