/*
 * Utilities functions
 */

// Ethers
function ether (n) {
  return new web3.BigNumber(web3.toWei(n, 'ether'));
}

// Latest time
function latestTime () {
  return web3.eth.getBlock('latest').timestamp;
}

const EVMRevert = 'revert';

// Advances the block number so that the last mined block is `number`
function advanceBlock () {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_mine',
      id: Date.now(),
    }, (err, res) => {
      return err ? reject(err) : resolve(res);
    });
  });
}

// Increase time

function increaseTime (duration) {
  const id = Date.now();

  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [duration],
      id: id,
    }, err1 => {
      if (err1) return reject(err1);

      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: id + 1,
      }, (err2, res) => {
        return err2 ? reject(err2) : resolve(res);
      });
    });
  });
}

function increaseTimeTo (target) {
  let now = latestTime();
  if (target < now) throw Error(`Cannot increase current time(${now}) to a moment in the past(${target})`);
  let diff = target - now;
  return increaseTime(diff);
}

const duration = {
  seconds: function (val) { return val; },
  minutes: function (val) { return val * this.seconds(60); },
  hours: function (val) { return val * this.minutes(60); },
  days: function (val) { return val * this.hours(24); },
  weeks: function (val) { return val * this.days(7); },
  years: function (val) { return val * this.days(365); },
};

const BigNumber = web3.BigNumber;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const HivePowerCrowdsale = artifacts.require('HivePowerCrowdsale');
const HVT = artifacts.require('HVT');

//  https://github.com/AdExBlockchain/adex-token/blob/master/contracts/ADXToken.sol
contract('HivePowerCrowdsale', function ([_, investor, wallet, purchaser]) {
  // HVT has 18 decimals => all is multiplied by 1e18
  const RATE_BATCH1 =  4000 * 1e18;            // 1 ETH = 1000 USD = 4000 HVT => 1 HVT = 1/4000 ETH = 0.00025 ETH = 0.00025 * 1e18 wei
  const RATE_BATCH2A = 4000 * 1e18;            // 1 ETH = 1000 USD = 4000 HVT => 1 HVT = 1/4000 ETH = 0.00025 ETH = 0.00025 * 1e18 wei
  const RATE_BATCH2B = 4000 * 1e18;            // 1 ETH = 1000 USD = 4000 HVT => 1 HVT = 1/4000 ETH = 0.00025 ETH = 0.00025 * 1e18 wei
  const CAP_BATCH1 = 10 * 1e6 * 1e18;
  const CAP_BATCH2 = 40 * 1e6 * 1e18;
  const FOUNDERS_TOKENS = 10 * 1e6 * 1e18;
  const STEP_LOCKED_TOKENS = 3600 * 1;
  const ADDITIONAL_TOKENS = 40 * 1e6 * 1e18;
  const GOAL = ether(1000);

  // const value = ether(1);
  const value = 1e0;

  before(async function () {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  // Create the HivePowerCrowdsale object
  beforeEach(async function () {
    this.startTimeBatch1 = latestTime() + duration.minutes(1);
    this.endTimeBatch1 = this.startTimeBatch1 + duration.minutes(2);
    this.afterEndTimeBatch1 = this.endTimeBatch1 + duration.seconds(1);

    this.startTimeBatch2 = this.endTimeBatch1 + duration.minutes(1);
    this.endTimeBatch2 = this.startTimeBatch2 + duration.minutes(2);

    this.afterEndTimeBatch2 = this.endTimeBatch2 + duration.seconds(1);

    this.token = await HVT.new();
    this.crowdsale = await HivePowerCrowdsale.new(
      this.startTimeBatch1,
      this.endTimeBatch1,
      this.startTimeBatch2,
      this.endTimeBatch2,
      RATE_BATCH1,
      RATE_BATCH2A,
      RATE_BATCH2B,
      CAP_BATCH1,
      CAP_BATCH2,
      FOUNDERS_TOKENS,
      STEP_LOCKED_TOKENS,
      ADDITIONAL_TOKENS,
      GOAL,
      wallet
    );
    await this.token.transferOwnership(this.crowdsale.address);
  });

  describe('Initial tests:', function () {
    it('should create crowdsale with correct parameters', async function () {
      this.crowdsale.should.exist;
      this.token.should.exist;

      const startTimeBatch1 = await this.crowdsale.startTimeBatch1();
      const endTimeBatch1 = await this.crowdsale.endTimeBatch1();
      const startTimeBatch2 = await this.crowdsale.startTimeBatch2();
      const endTimeBatch2 = await this.crowdsale.endTimeBatch2();
      const rateBatch1 = await this.crowdsale.rateBatch1();
      const rateBatch2a = await this.crowdsale.rateBatch2a();
      const rateBatch2b = await this.crowdsale.rateBatch2b();
      const walletAddress = await this.crowdsale.wallet();
      const goal = await this.crowdsale.goal();
      const capBatch1 = await this.crowdsale.capBatch1();
      const capBatch2 = await this.crowdsale.capBatch2();

      startTimeBatch1.should.be.bignumber.equal(this.startTimeBatch1);
      endTimeBatch1.should.be.bignumber.equal(this.endTimeBatch1);
      startTimeBatch2.should.be.bignumber.equal(this.startTimeBatch2);
      endTimeBatch2.should.be.bignumber.equal(this.endTimeBatch2);
      rateBatch1.should.be.bignumber.equal(RATE_BATCH1);
      rateBatch2a.should.be.bignumber.equal(RATE_BATCH2A);
      rateBatch2b.should.be.bignumber.equal(RATE_BATCH2B);
      capBatch1.should.be.bignumber.equal(CAP_BATCH1);
      capBatch2.should.be.bignumber.equal(CAP_BATCH2);
      walletAddress.should.be.equal(wallet);
      goal.should.be.bignumber.equal(GOAL);
    });

    it('should be token owner', async function () {
      const owner = await this.token.owner();
      owner.should.equal(this.crowdsale.address);
    });

    it('should be ended only after end', async function () {
      let ended = await this.crowdsale.hasEnded();
      ended.should.equal(false);
      await increaseTimeTo(this.afterEndTimeBatch2);
      ended = await this.crowdsale.hasEnded();
      ended.should.equal(true);
    });
  });

  describe('Payments tests Batch1:', function () {
    it('should reject payments before start', async function () {
      await this.crowdsale.send(value).should.be.rejectedWith(EVMRevert);
      await this.crowdsale.buyTokens(investor, { from: purchaser, value: value }).should.be.rejectedWith(EVMRevert);
    });

    it('should accept payments after start', async function () {
      await increaseTimeTo(this.startTimeBatch1);

      const status = await this.crowdsale.isBatch1Running();

      status.should.be.all.equal(true);
      await this.crowdsale.send(value).should.be.fulfilled;
      await this.crowdsale.buyTokens(investor, { from: purchaser, value: value }).should.be.fulfilled;

      // const wei = await this.crowdsale.weiRaised();
      // console.log('wei = ' + wei.toNumber().toExponential());
      //
      // const tokensB1 = await this.crowdsale.tokenRaisedBatch1();
      // console.log('TokenB1 = ' + tokensB1.toNumber().toExponential());
      //
      // const tknCapB1 = await this.token.MAX_BATCH1();
      // console.log('TokenCapB1 = ' + tknCapB1.toNumber().toExponential());
      //
      // const tokens = await this.token.totalSupply();
      // console.log('Token supply = ' + tokens.toNumber().toExponential());
    });

    it('should reject payments after end', async function () {
      await increaseTimeTo(this.afterEndTimeBatch1);
      await this.crowdsale.send(value).should.be.rejectedWith(EVMRevert);
      await this.crowdsale.buyTokens(investor, { from: purchaser, value: value }).should.be.rejectedWith(EVMRevert);
    });
  });

  describe('Payments tests Batch2:', function () {
    it('should reject payments before start', async function () {
      await this.crowdsale.send(value).should.be.rejectedWith(EVMRevert);
      await this.crowdsale.buyTokens(investor, { from: purchaser, value: value }).should.be.rejectedWith(EVMRevert);
    });

    it('should accept payments after start', async function () {
      await increaseTimeTo(this.startTimeBatch2);

      const status = await this.crowdsale.isBatch2Running();

      status.should.be.all.equal(true);
      await this.crowdsale.send(value).should.be.fulfilled;
      await this.crowdsale.buyTokens(investor, { from: purchaser, value: value }).should.be.fulfilled;
    });

    it('should reject payments after end', async function () {
      await increaseTimeTo(this.afterEndTimeBatch2);
      await this.crowdsale.send(value).should.be.rejectedWith(EVMRevert);
      await this.crowdsale.buyTokens(investor, { from: purchaser, value: value }).should.be.rejectedWith(EVMRevert);
    });
  });

});
