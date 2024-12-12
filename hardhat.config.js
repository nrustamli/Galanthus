require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.27",
  networks: {
    hardhat: {
      chainId: 3337, 
      accounts: {
        count: 10, 
        accountsBalance: '100000000000000000000000', 
      },
      blockGasLimit: 200000000 // Increased block gas limit
    }
  }
};
