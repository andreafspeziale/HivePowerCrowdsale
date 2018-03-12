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

    var startTime = initialDelay; // ICO starting 1 minute after the initial deployment
    var endTime = startTime + (60 * 1); // ICO end

    var ratePhase1 = 4; // Token = rate * wei (1 ETH => 4 HVT)
    var ratePhase2 = 2; // Token = rate * wei (1 ETH => 2 HVT)
    var ratePhase3 = 1; // Token = wei * rate (1 ETH => 1 HVT)

    var capPhase1 = 1 * 1e18; // Maximum cap (wei) (1e18 = 1000000000000000000)
    var capPhase2 = 4 * 1e18; // Maximum cap (wei) (1e18 = 1000000000000000000)
    var capPhase3 = 8 * 1e18; // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Founders tokens
    var foundersTokens = 10e6;
    var stepLockedToken = (3600 * 1); // First release after stepReleaseLockedToken seconds, second after 2*stepReleaseLockedToken, etc..

    // Additional tokens
    var additionalTokens = 40e6;

    // Goal
    var goal = 4 * 1e18;

    //kyc signers
    var kycSigners = [accounts[2], accounts[3]];

  } else if (network == 'ropsten') {
    // Wallet
    var wallet = accounts[1];

    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (3600 * 1);

    var startTime = initialDelay; // ICO starting 1 hour after the initial deployment
    var endTime = startTime + (3600 * 2); // ICO end
    var ratePhase1 = parseInt(0.00025 * 1e18 * (1 + 0.3)); // Token = rate * wei
    var ratePhase2 = parseInt(0.00025 * 1e18 * (1 + 0.1)); // Token = rate * wei
    var ratePhase3 = parseInt(0.00025 * 1e18); // Token = rate * wei

    var capPhase1 = 10e6; // Maximum cap (token)
    var capPhase2 = 25e6; // Maximum cap (token)
    var capPhase3 = 50e6; // Maximum cap (token)

    // Founders tokens
    var foundersTokens = 10e6;
    var stepLockedToken = (3600 * 1); // First release after stepReleaseLockedToken seconds, second after 2*stepReleaseLockedToken, etc..

    // Additional tokens
    var additionalTokens = 40e6;

    // Goal
    var goal = 1000 * 1e18;

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
    endTime,
    [ratePhase1, ratePhase2, ratePhase3],
    [capPhase1, capPhase2, capPhase3],
    goal,
    additionalTokens,
    foundersTokens,
    stepLockedToken);
};
