var SafeMath = artifacts.require('zeppelin-solidity/contracts/math/SafeMath.sol');
var HVT = artifacts.require('./HVT.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer, network, accounts) {

  /* In these tests: 1 HVT = 0.25 USD = 1 ETH
   * - 1 ETH = 1000 USD
   * - 1 HVT = 0.25 USD = 1 USD / 4
   * - 1 HVT = 1 USD / 4 = 1 ETH / 4000 = 0.00025 * ETH
   */

  if (network == 'development') {
    // Wallet
    var wallet = accounts[1];

    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (60 * 1);
    var startTime = initialDelay; // ICO starting 1 hour after the initial deployment
    var endTime = startTime + (3600 * 2); // ICO end
    var ratePhase1 = parseInt(4000 * (1 + 0.3)); // Token = rate * wei
    var ratePhase2 = parseInt(4000 * (1 + 0.1)); // Token = rate * wei
    var ratePhase3 = parseInt(4000); // Token = rate * wei

    var capPhase1 = 10e6; // Maximum cap (token)
    var capPhase2 = 25e6; // Maximum cap (token)
    var capPhase3 = 50e6; // Maximum cap (token)

    var etherPriceUSD = 1000000; //1 million dollars ;-)

    var rate1 = parseInt((etherPriceUSD / 0.25) * 1.3);
    var rate2 = parseInt((etherPriceUSD / 0.25) * 1.1);
    var rate3 = parseInt((etherPriceUSD / 0.25) * 1.0);

    var cap1 = 10 * 1e6 * 1e18;
    var cap2 = 25 * 1e6 * 1e18;
    var cap3 = 50 * 1e6 * 1e18;

    var foundersTokens = 10 * 1e6 * 1e18;
    var stepLockedToken = 86400 * 30 * 6;
    var additionalTokens = 40 * 1e6 * 1e18;
    var goal = parseInt(1000000 / etherPriceUSD);

    var overshoot = web3.toWei(3, 'ether');

    //kyc signers
    var kycSigners = [accounts[2], accounts[3]];

  } else if (network == 'ropsten') {
    // Wallet
    var wallet = accounts[1];

    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (3600 * 1);

    var startTime = initialDelay; // ICO starting 1 hour after the initial deployment
    var endTime = startTime + (3600 * 2); // ICO end
    var ratePhase1 = parseInt(4000 * (1 + 0.3)); // Token = rate * wei
    var ratePhase2 = parseInt(4000 * (1 + 0.1)); // Token = rate * wei
    var ratePhase3 = parseInt(4000); // Token = rate * wei

    var capPhase1 = 10e6; // Maximum cap (token)
    var capPhase2 = 25e6; // Maximum cap (token)
    var capPhase3 = 50e6; // Maximum cap (token)

    var etherPriceUSD = 1000000; //1 million dollars ;-)

    var rate1 = parseInt((etherPriceUSD / 0.25) * 1.3);
    var rate2 = parseInt((etherPriceUSD / 0.25) * 1.1);
    var rate3 = parseInt((etherPriceUSD / 0.25) * 1.0);

    var cap1 = 10 * 1e6 * 1e18;
    var cap2 = 25 * 1e6 * 1e18;
    var cap3 = 50 * 1e6 * 1e18;

    var foundersTokens = 10 * 1e6 * 1e18;
    var stepLockedToken = 86400 * 30 * 6;
    var additionalTokens = 40 * 1e6 * 1e18;
    var goal = parseInt(1000000 / etherPriceUSD);

    var overshoot = web3.toWei(3, 'ether');
    //kyc signers
    var kycSigners = [accounts[2], accounts[3]];
  }

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale,
    kycSigners,
    HVT.address,
    wallet,
    startTime,
    endTime, [rate1, rate2, rate3], [cap1, cap2, cap3],
    goal,
    additionalTokens,
    foundersTokens,
    stepLockedToken,
    overshoot);
};
