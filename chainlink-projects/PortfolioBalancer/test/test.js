const hre = require('hardhat');
const assert = require('chai').assert;

describe('PortfolioBalancer', () => {
  let PortfolioBalancer;

  beforeEach(async function () {
    const contractName = 'PortfolioBalancer';
    await hre.run("compile");
    const smartContract = await hre.ethers.getContractFactory(contractName);
    PortfolioBalancer = await smartContract.deploy();
    await PortfolioBalancer.deployed();
    console.log(`${contractName} deployed to: ${PortfolioBalancer.address}`);
  });

  it('Should return zero DAI balance', async () => {
    const daiBalance = await PortfolioBalancer.getDaiBalance();
    assert.equal(daiBalance,0);
  });

  it('Should Rebalance The Portfolio ', async () => {
    const accounts = await hre.ethers.getSigners();
    const owner = accounts[0];
    console.log('Transfering ETH From Owner Address', owner.address);
    await owner.sendTransaction({
      to: PortfolioBalancer.address,
      value: ethers.utils.parseEther('0.01'),
    });
    await PortfolioBalancer.wrapETH();
    await PortfolioBalancer.updateEthPriceUniswap();
    await PortfolioBalancer.rebalance();
    const daiBalance = await PortfolioBalancer.getDaiBalance();
    console.log('Rebalanced DAI Balance',daiBalance);
    assert.isAbove(daiBalance,0);
  });

});