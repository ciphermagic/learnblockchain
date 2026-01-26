'use client';

import { NFTToken } from '../types';
import { useAccount } from 'wagmi';

interface MyNFTsProps {
  userNfts: NFTToken[];
  isLoading: boolean;
  nftPrice: string;
  setNftPrice: (price: string) => void;
  handleListWithSignature: (contractAddress: string, nftTokenId: bigint, nftPrice: string) => Promise<void>;
}

export default function MyNFTs({
  userNfts,
  isLoading,
  nftPrice,
  setNftPrice,
  handleListWithSignature,
}: MyNFTsProps) {
  const { address } = useAccount();

  return (
    <div>
      <h2 className="text-xl font-semibold mb-4">My NFTs</h2>
      {userNfts.length === 0 ? (
        <p className="text-gray-600">No NFTs found in your wallet.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {userNfts.map((nft) => (
            <div key={`${nft.contractAddress}-${nft.tokenId}`} className="bg-white shadow rounded-lg p-4">
              <h3 className="font-medium">NFT #{Number(nft.tokenId)}</h3>
              <p className="text-sm text-gray-600">
                Contract: {nft.contractAddress.slice(0, 6)}...{nft.contractAddress.slice(-4)}
              </p>
              <div className="mt-4">
                <input
                  type="text"
                  placeholder="Price in PTK"
                  value={nftPrice}
                  onChange={(e) => setNftPrice(e.target.value)}
                  className="w-full border rounded px-2 py-1 mb-2"
                />
                <button
                  onClick={() => handleListWithSignature(nft.contractAddress, nft.tokenId, nftPrice)}
                  disabled={isLoading}
                  className="w-full bg-indigo-600 text-white py-1 rounded hover:bg-indigo-700 disabled:opacity-50"
                >
                  List with Signature
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}