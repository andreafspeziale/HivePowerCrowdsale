var SafeMath = artifacts.require('zeppelin-solidity/contracts/math/SafeMath.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer) {
  var startTimePreSale = 1521115200;   // 15-03-2018 12:00 (UTC)
  var endTimePreSale = 1521547200;     // 20-03-2018 12:00 (UTC)

  var startTimeSale = 1521979200;     // 25-03-2018 12:00 (UTC)
  var endTimeSale = 1522411200;       // 30-03-2018 12:00 (UTC)

  var ratePreSale = 2;
  var rateSale = 4;

  var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale,
                  startTimePreSale,
                  endTimePreSale,
                  startTimeSale,
                  endTimeSale,
                  ratePreSale,
                  rateSale,
                  wallet);
};
