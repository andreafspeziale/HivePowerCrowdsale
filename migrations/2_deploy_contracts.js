var SafeMath = artifacts.require('zeppelin-solidity/contracts/math/SafeMath.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer, network, accounts) {

  /* In these tests: 1 HVT = 0.25 USD = 1 ETH
   * - 1 ETH = 1000 USD
   * - 1 HVT = 0.25 USD = 1 USD / 4
   * - 1 HVT = 1 USD / 4 = 1 ETH / 4000 = 0.00025 * ETH
   */

  if (network == 'development')
  {
    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (60 * 1);
    // PreSale phase
    var startTimePreSale = initialDelay;                      // PreSale starting 1 minute after the initial deployment
    var endTimePreSale = startTimePreSale + (60 * 1);         // PreSale duration
    var ratePreSale = 4;                                      // Token = wei * rate (1 HVT = 4 ETH)
    var capPreSale = 5 * 1e18;                                // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Sale phase
    var startTimeSale = endTimePreSale + (60 * 1);            // Sale waits some minutes before starting
    var endTimeSale = startTimeSale + (60 * 1);               // Sale duration
    var rateSale = 1;                                         // Token = wei * rate (1 HVT = 1 ETH)
    var capSale = 20 * 1e18;                                  // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Wallet
    var wallet = accounts[0];

    // Wallet
    var additionalTokens = 4 * 1e18;
  }
  else if (network == 'ropsten')
  {
    // PreSale phase
    var startTimePreSale = 1518588000;                        // 14-02-2018 06:00 (UTC)
    var endTimePreSale = 1518602400;                          // 14-02-2018 10:00 (UTC)
    var ratePreSale = parseInt(0.00025 * 1e18 / (1 - 0.3));   // Token = wei * rate
    var capPreSale = 3500 * 1e18;                             // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Sale phase
    var startTimeSale = 1518609600;                           // 14-02-2018 12:00 (UTC)
    var endTimeSale = 1518620400;                             // 14-02-2018 17:00 (UTC)
    var rateSale = parseInt(0.00025 * 1e18 / (1 - 0.05));     // Token = wei * rate
    var capSale = 7125 * 1e18;                                // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Wallet
    var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';

    // Wallet
    var additionalTokens = 50000000;
  }

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale,
                  startTimePreSale,
                  endTimePreSale,
                  startTimeSale,
                  endTimeSale,
                  ratePreSale,
                  rateSale,
                  capPreSale,
                  capSale,
                  additionalTokens,
                  wallet);
};
