import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';

const privateKey = generatePrivateKey();
console.log('私钥:', privateKey, '长度:', privateKey.length - 2, '字节:', (privateKey.length - 2) / 2);

const account = privateKeyToAccount(privateKey);
console.log('地址:', account.address, '长度:', account.address.length - 2, '字节:', (account.address.length - 2) / 2);
console.log('公钥（未压缩）:', account.publicKey);
