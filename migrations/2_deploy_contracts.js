var SafeMath = artifacts.require('./SafeMath.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer) {
  var startBlock = 3000 * 1000;
  var endBlock = 3100 * 1000;
  var rate = 2;
  var tokenStartBlock = 3020 * 1000;;
  var tokenLockEndBlock = 4000 * 1000;;
  var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale, startBlock, endBlock, rate, tokenStartBlock, tokenLockEndBlock, wallet);
};

/* How to get ABI-encoded input arguments (for publishing on Etherscan)
> var abi = require('ethereumjs-abi')
> var parameterTypes = ["uint256", "uint256", "uint256", "uint256", "uint256", "address"];
> var parameterValues = [3000 * 1000, 3100 * 1000, 2, 3020 * 1000,  4000 * 1000, '0xa46a44c88c6bb62f41a723006a45506632f0c292'];
> var encoded = abi.rawEncode(parameterTypes, parameterValues);
> console.log(encoded.toString('hex'));
*/
