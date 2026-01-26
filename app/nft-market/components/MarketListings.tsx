'use client';

import { Listing } from '../types';
import { formatEther } from 'viem';
import { useAccount } from 'wagmi';

interface MarketListingsProps {
  listings: Listing[];
  isLoading: boolean;
  handleBuyNFT: (listingId: bigint, price: bigint) => void;
  handleCancelListing: (listingId: bigint) => void;
  showMessage: (message: string, isError?: boolean) => void;
}

export default function MarketListings({
  listings,
  isLoading,
  handleBuyNFT,
  handleCancelListing,
  showMessage,
}: MarketListingsProps) {
  const { address } = useAccount();

  return (
    <div>
      <h2 className='text-xl font-semibold mb-4'>Market Listings</h2>
      {listings.length === 0 ? (
        <p className='text-gray-600'>No listings available.</p>
      ) : (
        <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'>
          {listings.map(listing => (
            <div key={Number(listing.tokenId)} className='bg-white shadow rounded-lg p-4'>
              <h3 className='font-medium'>NFT #{Number(listing.tokenId)}</h3>
              <p className='text-sm text-gray-600'>
                Contract: {listing.nftContract.slice(0, 6)}...{listing.nftContract.slice(-4)}
              </p>
              <p className='text-sm text-gray-600'>
                Seller: {listing.seller.slice(0, 6)}...{listing.seller.slice(-4)}
              </p>
              <p className='font-bold'>Price: {formatEther(listing.price)} PTK</p>
              <button
                onClick={() => handleBuyNFT(listing.id, listing.price)}
                disabled={isLoading}
                className='mt-2 bg-indigo-600 text-white py-1 px-3 rounded hover:bg-indigo-700 disabled:opacity-50'
              >
                Buy
              </button>
              {listing.seller === address && (
                <button
                  onClick={() => handleCancelListing(listing.id)}
                  disabled={isLoading}
                  className='mt-2 ml-2 bg-red-600 text-white py-1 px-3 rounded hover:bg-red-700 disabled:opacity-50'
                >
                  Cancel
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
