'use client';

import { NFTContract } from '../types';

interface DeployContractProps {
  nftName: string;
  setNftName: (name: string) => void;
  handleDeployContract: () => Promise<void>;
  handleRemoveDeployedNft: (nftAddress: `0x${string}`) => void;
  isWritePending: boolean;
  isLoading: boolean;
  deployedNfts: NFTContract[];
}

export default function DeployContract({
  nftName,
  setNftName,
  handleDeployContract,
  handleRemoveDeployedNft,
  isWritePending,
  isLoading,
  deployedNfts,
}: DeployContractProps) {
  return (
    <div className="max-w-2xl mx-auto">
      <h2 className="text-xl font-semibold mb-4">Deploy New NFT Contract</h2>
      <div className="bg-white shadow rounded-lg p-6">
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">NFT Name</label>
          <input
            type="text"
            value={nftName}
            onChange={(e) => setNftName(e.target.value)}
            className="w-full border rounded px-3 py-2"
            placeholder="e.g., My NFT Collection"
          />
        </div>
        <button
          onClick={handleDeployContract}
          disabled={isWritePending || isLoading}
          className={`w-full py-2 px-4 rounded ${
            isWritePending || isLoading
              ? 'bg-gray-400 cursor-not-allowed'
              : 'bg-indigo-600 hover:bg-indigo-700 text-white'
          }`}
        >
          {isWritePending || isLoading ? 'Deploying...' : 'Deploy NFT Contract'}
        </button>

        {deployedNfts.length > 0 && (
          <div className="mt-6">
            <h3 className="text-lg font-medium mb-2">Deployed Contracts</h3>
            <div className="space-y-2">
              {deployedNfts.map((nft) => (
                <div key={nft.address} className="border rounded p-3 flex justify-between items-start">
                  <div>
                    <div className="font-medium">{nft.name}</div>
                    <div className="text-sm text-gray-600">{nft.address}</div>
                  </div>
                  <button
                    onClick={() => handleRemoveDeployedNft(nft.address)}
                    className="text-red-600 hover:text-red-800 text-sm px-2 py-1 rounded border border-red-300 hover:border-red-500"
                  >
                    Remove
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}