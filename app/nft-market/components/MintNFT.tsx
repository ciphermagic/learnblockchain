'use client';

import { NFTContract } from '../types';

interface MintNFTProps {
  selectedNftContract: `0x${string}` | null;
  setSelectedNftContract: (address: `0x${string}` | null) => void;
  mintTo: string;
  setMintTo: (address: string) => void;
  nftUri: string;
  setNftUri: (uri: string) => void;
  handleMintNFT: () => void;
  handleRemoveDeployedNft: (nftAddress: `0x${string}`) => void;
  isWritePending: boolean;
  isLoading: boolean;
  deployedNfts: NFTContract[];
}

export default function MintNFT({
  selectedNftContract,
  setSelectedNftContract,
  mintTo,
  setMintTo,
  nftUri,
  setNftUri,
  handleMintNFT,
  handleRemoveDeployedNft,
  isWritePending,
  isLoading,
  deployedNfts,
}: MintNFTProps) {
  return (
    <div className="max-w-2xl mx-auto">
      <h2 className="text-xl font-semibold mb-4">Mint New NFT</h2>
      <div className="bg-white shadow rounded-lg p-6">
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Select NFT Contract</label>
          <select
            value={selectedNftContract || ''}
            onChange={(e) => setSelectedNftContract(e.target.value as `0x${string}` || null)}
            className="w-full border rounded px-3 py-2"
          >
            <option value="">Select a deployed contract</option>
            {deployedNfts.map((nft) => (
              <option key={nft.address} value={nft.address}>
                {nft.name} ({nft.address.slice(0, 6)}...{nft.address.slice(-4)})
              </option>
            ))}
          </select>
        </div>
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Mint To</label>
          <input
            type="text"
            value={mintTo}
            onChange={(e) => setMintTo(e.target.value)}
            className="w-full border rounded px-3 py-2"
            placeholder="Recipient address"
          />
        </div>
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Token URI (Optional)</label>
          <input
            type="text"
            value={nftUri}
            onChange={(e) => setNftUri(e.target.value)}
            className="w-full border rounded px-3 py-2"
            placeholder="e.g., ipfs://Qm..."
          />
        </div>
        <button
          onClick={handleMintNFT}
          disabled={isWritePending || isLoading}
          className={`w-full bg-indigo-600 hover:bg-indigo-700 text-white py-2 px-4 rounded ${
            isWritePending || isLoading ? 'opacity-50 cursor-not-allowed' : ''
          }`}
        >
          {isWritePending || isLoading ? 'Minting...' : 'Mint NFT'}
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