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
    var rateBatch2a = 2;                                         // Token = wei * rate (1 HVT = 1 ETH)
    var rateBatch2b = 1;                                         // Token = wei * rate (1 HVT = 1 ETH)
    var capBatch2 = 20 * 1e18;                                  // Maximum cap (wei) (1e18 = 1000000000000000000)

    // Wallet
    var wallet = accounts[0];

    // Founders tokens
    var foundersTokens = 10e6;
    var stepLockedToken = (60 * 1);                   // First release after stepReleaseLockedToken seconds, second after 2*stepReleaseLockedToken, etc..

    // Additional tokens
    var additionalTokens = 40e6;

    // Goal
    var goal = 4 * 1e18;
  }
  else if (network == 'ropsten')
  {
    // Batch1 phase
    var startTimeBatch1 = 1518760800;                           // 16-02-2018 06:00 (UTC)
    var endTimeBatch1 = startTimeBatch1 + (3600 * 2);           // Batch1 end
    var rateBatch1 = parseInt(0.00025 * 1e18 * (1 + 0.3));      // Token = wei * rate
    var capBatch1 = 10e6;                                // Maximum cap (token)

    // Batch2 phase
    var startTimeBatch2 = endTimeBatch1 + (3600 * 1);           // Batch2 waits some hours before starting
    var endTimeBatch2 = startTimeBatch2 + (3600 * 2);           // Batch2 end
    var rateBatch2a = parseInt(0.00025 * 1e18 * (1 + 0.1));     // Token = wei * rate
    var rateBatch2b = parseInt(0.00025 * 1e18);     // Token = wei * rate
    var capBatch2 = 40e6;                                // Maximum cap (token)

    // Wallet
    var wallet = '0xa46a44c88c6bb62f41a723006a45506632f0c292';

    // Founders tokens
    var foundersTokens = 10e6;
    var stepLockedToken = (3600 * 1);                   // First release after stepReleaseLockedToken seconds, second after 2*stepReleaseLockedToken, etc..

    // Additional tokens
    var additionalTokens = 40e6;

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
                  rateBatch2a,
                  rateBatch2b,
                  capBatch1,
                  capBatch2,
                  foundersTokens,
                  stepLockedToken,
                  additionalTokens,
                  goal,
                  wallet);
};
