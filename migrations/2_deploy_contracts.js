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
    // Batch1 phase
    var startTimeBatch1 = initialDelay;                      // Batch1 starting 1 minute after the initial deployment
    var endTimeBatch1 = startTimeBatch1 + (60 * 1);         // Batch1 end
    var rateBatch1 = 4;                                      // Token = wei * rate (1 HVT = 4 ETH)
    var capBatch1 = 5 * 1e18;                                // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Batch2 phase
    var startTimeBatch2 = endTimeBatch1 + (60 * 1);            // Batch2 waits some minutes before starting
    var endTimeBatch2 = startTimeBatch2 + (60 * 1);               // Batch2 end
    var rateBatch2 = 1;                                         // Token = wei * rate (1 HVT = 1 ETH)
    var capBatch2 = 20 * 1e18;                                  // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Wallet
    var wallet = accounts[0];

    // Founders tokens
    var foundersTokens = 5 * 1e18;
    var releaseTimeTokenLock1 = startTimeBatch2 + (60 * 1);
    var releaseTimeTokenLock2 = startTimeBatch2 + (60 * 2);
    var releaseTimeTokenLock3 = startTimeBatch2 + (60 * 2);
    var releaseTimeTokenLock4 = startTimeBatch2 + (60 * 4);

    // Additional tokens
    var additionalTokens = 4 * 1e18;

    // Goal
    var goal = 4 * 1e18;
  }
  else if (network == 'ropsten')
  {
    // Batch1 phase
    var startTimeBatch1 = 1518588000;                           // 14-02-2018 06:00 (UTC)
    var endTimeBatch1 = startTimeBatch1 + (3600 * 2);           // Batch1 end
    var rateBatch1 = parseInt(0.00025 * 1e18 / (1 - 0.3));      // Token = wei * rate
    var capBatch1 = 3500 * 1e18;                                // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Batch2 phase
    var startTimeBatch2 = endTimeBatch1 + (3600 * 1);           // Batch2 waits some hours before starting
    var endTimeBatch2 = startTimeBatch2 + (3600 * 2);           // Batch2 end
    var rateBatch2 = parseInt(0.00025 * 1e18 / (1 - 0.05));     // Token = wei * rate
    var capBatch2 = 7125 * 1e18;                                // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Wallet
    var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';

    // Founders tokens
    var foundersTokens = 60000000;
    var stepReleaseLockedToken = (3600 * 1);                   // First release after 1 hour, second after 2, etc..

    // Additional tokens
    var additionalTokens = 50000000;

    // Goal
    var goal = 1000 * 1e18;
  }

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale,
                  startTimeBatch1,
                  endTimeBatch1,
                  startTimeBatch2,
                  endTimeBatch2,
                  rateBatch1,
                  rateBatch2,
                  capBatch1,
                  capBatch2,
                  foundersTokens,
                  stepReleaseLockedToken,
                  additionalTokens,
                  goal,
                  wallet);
};
