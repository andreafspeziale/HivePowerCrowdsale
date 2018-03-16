var HVT = artifacts.require('./HVT.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer, network, accounts) {
  deployer.then(() => {
    HVT.deployed().then(function(hvt) {
      return hvt.transferOwnership(HivePowerCrowdsale.address).then(function() {
        return HivePowerCrowdsale.deployed().then(function(crowdsale) {
          return crowdsale.preallocate();
        });
      });
    })
  })
};
