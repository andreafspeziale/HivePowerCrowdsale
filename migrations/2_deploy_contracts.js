var SafeMath = artifacts.require('zeppelin-solidity/contracts/math/SafeMath.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer, network, accounts) {

  if (network == 'development')
  {
    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (60 * 1);
    // PreSale phase
    var startTimePreSale = initialDelay;                    // PreSale starting 1 minute after the initial deployment
    var endTimePreSale = startTimePreSale + (60 * 5);      // PreSale duration
    var ratePreSale = 2;                                    // Token = wei * rate
    var capPreSale = 5 * 1e18;                             // Data in ETH (1e18 = 1000000000000000000)

    // Sale phase
    var startTimeSale = endTimePreSale + (60 * 2);          // Sale starting 5 minutes after PreSale maximum end
    var endTimeSale = startTimeSale + (60 * 5);             // Sale duration
    var rateSale = 4;                                       // Token = wei * rate
    var capSale = 20 * 1e18;                                // Data in ETH (1e18 = 1000000000000000000)

    // Wallet
    var wallet = accounts[0];
  }
  else if (network == 'ropsten')
  {
    // PreSale phase
    var startTimePreSale = 1521115200;   // 15-03-2018 12:00 (UTC)
    var endTimePreSale = 1521547200;     // 20-03-2018 12:00 (UTC)
    var ratePreSale = 2;                 // Token = wei * rate
    var capPreSale = 1000 * 1e18;        // Data in ETH (1e18 = 1000000000000000000)

    // Sale phase
    var startTimeSale = 1521979200;      // 25-03-2018 12:00 (UTC)
    var endTimeSale = 1522411200;        // 30-03-2018 12:00 (UTC)
    var rateSale = 4;                    // Token = wei * rate
    var capSale = 4000 * 1e18;           // Data in ETH (1e18 = 1000000000000000000)

    // Wallet
    var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';
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
                  wallet);
};
