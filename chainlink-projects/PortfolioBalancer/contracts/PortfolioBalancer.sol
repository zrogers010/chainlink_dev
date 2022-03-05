// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';

// EACAggregatorProxy is used for chainlink oracle
interface EACAggregatorProxy {
  function latestAnswer() external view returns (int256);
}

// Uniswap v3 interface
interface IUniswapRouter is ISwapRouter {
  function refundETH() external payable;
}

// Add deposit function for WETH
interface DepositableERC20 is IERC20 {
  function deposit() external payable;
}

contract PortfolioBalancer {
  /* Kovan Addresses */
  address public daiAddress = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
  address public wethAddress = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
  address public uinswapV3QuoterAddress = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
  address public uinswapV3RouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
  address public chainLinkETHUSDAddress = 0x9326BFA02ADD2366b30bacB125260Af641031331;

  uint public ethPrice = 0;
  uint public usdTargetPercentage = 50;
  uint public usdDividendPercentage = 10; // 5% Annual Drawdown
  uint private dividendFrequency = 3 minutes; // change to 1 years for production
  uint public nextDividendTS;
  address public owner;

  using SafeERC20 for IERC20;
  using SafeERC20 for DepositableERC20;

  IERC20 daiToken = IERC20(daiAddress);
  DepositableERC20 wethToken = DepositableERC20(wethAddress);
  IQuoter quoter = IQuoter(uinswapV3QuoterAddress);
  IUniswapRouter uniswapRouter = IUniswapRouter (uinswapV3RouterAddress);

  event rebalanceEvent(string msg, uint ref);

  constructor() {
    console.log('Deploying PortfolioBalancer');
    nextDividendTS = block.timestamp + dividendFrequency;
    owner = msg.sender;
  }

  function getDaiBalance() public view returns(uint) {
    return daiToken.balanceOf(address(this));
  }

  function getWethBalance() public view returns(uint) {
    return wethToken.balanceOf(address(this));
  }

  function getTotalBalance() public view returns(uint) {
    require(ethPrice > 0, 'ETH price has not been set');
    uint daiBalance = getDaiBalance();
    uint wethBalance = getWethBalance();
    uint wethUSD = wethBalance * ethPrice; // assumes both assets have 18 decimals
    uint totalBalance = wethUSD + daiBalance;
    return totalBalance;
  }

  function updateEthPriceUniswap() public returns(uint) {
    uint ethPriceRaw = quoter.quoteExactOutputSingle(daiAddress,wethAddress,3000,100000,0);
    ethPrice = ethPriceRaw / 100000;
    return ethPrice;
  }

  function updateEthPriceChainlink() public returns(uint) {
    int256 chainLinkEthPrice = EACAggregatorProxy(chainLinkETHUSDAddress).latestAnswer();
    ethPrice = uint(chainLinkEthPrice / 100000000);
    return ethPrice;
  }

  function buyWeth(uint amountUSD) internal {
    uint256 deadline = block.timestamp + 15;
    uint24 fee = 3000;
    address recipient = address(this);
    uint256 amountIn = amountUSD; // includes 18 decimals
    uint256 amountOutMinimum = 0;
    uint160 sqrtPriceLimitX96 = 0;
    emit rebalanceEvent('amountIn', amountIn);
    require(daiToken.approve(address(uinswapV3RouterAddress), amountIn), 'DAI approve failed');
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
      daiAddress,
      wethAddress,
      fee,
      recipient,
      deadline,
      amountIn,
      amountOutMinimum,
      sqrtPriceLimitX96
    );
    uniswapRouter.exactInputSingle(params);
    uniswapRouter.refundETH();
  }

  function sellWeth(uint amountUSD) internal {
    uint256 deadline = block.timestamp + 15;
    uint24 fee = 3000;
    address recipient = address(this);
    uint256 amountOut = amountUSD; // includes 18 decimals
    uint256 amountInMaximum = 10 ** 28 ;
    uint160 sqrtPriceLimitX96 = 0;
    require(wethToken.approve(address(uinswapV3RouterAddress), amountOut), 'WETH approve failed');
    ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams(
      wethAddress,
      daiAddress,
      fee,
      recipient,
      deadline,
      amountOut,
      amountInMaximum,
      sqrtPriceLimitX96
    );
    uniswapRouter.exactOutputSingle(params);
    uniswapRouter.refundETH();
  }

  function rebalance() public {
    require(msg.sender == owner, "Only the owner can rebalance their account");
    uint usdBalance = getDaiBalance();
    uint totalBalance = getTotalBalance();
    uint usdBalancePercentage = 100 * usdBalance / totalBalance;
    emit rebalanceEvent('usdBalancePercentage', usdBalancePercentage);
    if (usdBalancePercentage < usdTargetPercentage) {
      uint amountToSell = totalBalance / 100 * (usdTargetPercentage - usdBalancePercentage);
      emit rebalanceEvent('amountToSell', amountToSell);
      require (amountToSell > 0, "Nothing to sell");
      sellWeth(amountToSell);
    } else {
      uint amountToBuy = totalBalance / 100 * (usdBalancePercentage - usdTargetPercentage);
      emit rebalanceEvent('amountToBuy', amountToBuy);
      require (amountToBuy > 0, "Nothing to buy");
      buyWeth(amountToBuy);
    }
  }

  function annualDividend() public {
    require(msg.sender == owner, "Only the owner can drawdown their account");
    require(block.timestamp > nextDividendTS, 'Dividend is not yet due');
    uint balance = getDaiBalance();
    uint amount = (balance * usdDividendPercentage) / 100;
    nextDividendTS = block.timestamp + dividendFrequency;
    daiToken.safeTransfer(owner, amount);
  }

  function closeAccount() public {
    require(msg.sender == owner, "Only the owner can close their account");
    uint daiBalance = getDaiBalance();
    if (daiBalance > 0) {
      daiToken.safeTransfer(owner, daiBalance);
    }
    uint wethBalance = getWethBalance();
    if (wethBalance > 0) {
      wethToken.safeTransfer(owner, wethBalance);
    }
  }

  receive() external payable {
    // accept ETH, do nothing as it would break the gas fee for a transaction
  }

  function wrapETH() public {
    require(msg.sender == owner, "Only the owner can convert ETH to WETH");
    uint ethBalance = address(this).balance;
    require(ethBalance > 0, "No ETH available to wrap");
    emit rebalanceEvent('wrapETH', ethBalance);
    wethToken.deposit{ value: ethBalance }();
  }
  
}