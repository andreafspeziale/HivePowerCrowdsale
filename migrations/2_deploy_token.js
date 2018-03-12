var HVT = artifacts.require('./HVT.sol');

module.exports = function (deployer, network, accounts) {
  deployer.deploy(HVT);
};
