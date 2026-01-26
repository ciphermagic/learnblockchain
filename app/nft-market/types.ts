// Type definitions
export type NFTContract = {
  address: `0x${string}`;
  name: string;
  owner: string;
};

export type Listing = {
  id: bigint;
  seller: `0x${string}`;
  nftContract: `0x${string}`;
  tokenId: bigint;
  price: bigint;
  isActive: boolean;
};

export type NFTToken = {
  contractAddress: `0x${string}`;
  tokenId: bigint;
  owner: `0x${string}`;
};
