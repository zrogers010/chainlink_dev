## Automated Portfolio Rebalancer

#### Balances between WETH and the DAI stablecoin, attempting to maintain a 50:50 ratio.

- Built with Hardhat and uses Chainlink oracle data feeds to update token prices.

- This contract is deployed on the Rinkeby network [here](https://rinkeby.etherscan.io/address/0x0387706dE56BE773614B0eF7c1E4005d6f3Be57c)

> Add a .env file with your key details to deploy the contract.

> npx hardhat run scripts/deploy.js --network rinkeby

- Credit: https://jamesbachini.com/intermediate-solidity-tutorial/