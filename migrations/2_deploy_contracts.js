var SafeMath = artifacts.require('zeppelin-solidity/contracts/math/SafeMath.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');

module.exports = function(deployer) {
  var startTime = 1521115200;   // 15-03-2018 12:00 (UTC)
  var endTime = 1521547200;     // 20-03-2018 12:00 (UTC)
  var rate = 2;
  var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale, startTime, endTime, rate, wallet);
};

/* How to get ABI-encoded input arguments (for publishing on Etherscan)
> var abi = require('ethereumjs-abi')
> var parameterTypes = ["uint256", "uint256", "uint256", "address"];
> var parameterValues = [1521115200, 1521547200, 2, '0xa46a44c88c6bb62f41a723006a45506632f0c292'];
> var encoded = abi.rawEncode(parameterTypes, parameterValues);
> console.log(encoded.toString('hex'));
000000000000000000000000000000000000000000000000000000005aaa6040000000000000000000000000000000000000000000000000000000005ab0f7c00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a46a44c88c6bb62f41a723006a45506632f0c292
*/
