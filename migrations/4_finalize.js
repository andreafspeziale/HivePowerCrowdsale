var HVT = artifacts.require('./HVT.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer, network, accounts) {
  deployer.then(() => {
    Promise.all([HVT.deployed(), HivePowerCrowdsale.deployed()]).then(results => {
      var hvt = results[0]
      var tokenSale = results[1]
      hvt.transferOwnership(HivePowerCrowdsale.address)
      tokenSale.preallocate()
    })
  })
};
