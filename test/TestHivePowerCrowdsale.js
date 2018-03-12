/*
 * Utilities functions
 */

// Ethers
function ether(n) {
  return new web3.BigNumber(web3.toWei(n, 'ether'));
}

// Latest time
function latestTime() {
  return web3.eth.getBlock('latest').timestamp;
}

const EVMRevert = 'revert';

// Advances the block number so that the last mined block is `number`
function advanceBlock() {
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

function increaseTime(duration) {
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

function increaseTimeTo(target) {
  let now = latestTime();
  if (target < now) throw Error(`Cannot increase current time(${now}) to a moment in the past(${target})`);
  let diff = target - now;
  return increaseTime(diff);
}

const duration = {
  seconds: function(val) {
    return val;
  },
  minutes: function(val) {
    return val * this.seconds(60);
  },
  hours: function(val) {
    return val * this.minutes(60);
  },
  days: function(val) {
    return val * this.hours(24);
  },
  weeks: function(val) {
    return val * this.days(7);
  },
  years: function(val) {
    return val * this.days(365);
  },
};

const BigNumber = web3.BigNumber;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();


const _ = require('lodash')
const {
  ecsign
} = require('ethereumjs-util')
const abi = require('ethereumjs-abi')
const BN = require('bn.js')

const SIGNER_PK = Buffer.from('c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3', 'hex')
const SIGNER_ADDR = '0x627306090abaB3A6e1400e9345bC60c78a8BEf57'.toLowerCase()
const OTHER_PK = Buffer.from('0dbbe8e4ae425a6d2687f1a7e3ba17bc98c673636790f1b8ad91193c05875ef1', 'hex')
const OTHER_ADDR = '0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef'.toLowerCase()
const MAX_AMOUNT = '1000000000000000000'

const getKycData = (userAddr, userid, icoAddr, pk) => {
  // sha256("Eidoo icoengine authorization", icoAddress, buyerAddress, buyerId, maxAmount);
  const hash = abi.soliditySHA256(
    ['string', 'address', 'address', 'uint64', 'uint'], ['Eidoo icoengine authorization', icoAddr, userAddr, new BN(userid), new BN(MAX_AMOUNT)]
  )
  const sig = ecsign(hash, pk)
  return {
    id: userid,
    max: MAX_AMOUNT,
    v: sig.v,
    r: '0x' + sig.r.toString('hex'),
    s: '0x' + sig.s.toString('hex')
  }
}

const expectEvent = (res, eventName) => {
  const ev = _.find(res.logs, {
    event: eventName
  })
  expect(ev).to.not.be.undefined
  return ev
}

const HivePowerCrowdsale = artifacts.require('HivePowerCrowdsale');
const HVT = artifacts.require('HVT');

//  https://github.com/AdExBlockchain/adex-token/blob/master/contracts/ADXToken.sol
contract('HivePowerCrowdsale', function([_, investor, wallet, purchaser]) {
  // HVT has 18 decimals => all is multiplied by 1e18
  const RATE_1 = 5200; // 1 ETH = 1000 USD = 4000 HVT => 1 HVT = 1/4000 ETH = 0.00025 ETH = 0.00025 * 1e18 wei
  const RATE_2 = 4400; // 1 ETH = 1000 USD = 4000 HVT => 1 HVT = 1/4000 ETH = 0.00025 ETH = 0.00025 * 1e18 wei
  const RATE_3 = 4000; // 1 ETH = 1000 USD = 4000 HVT => 1 HVT = 1/4000 ETH = 0.00025 ETH = 0.00025 * 1e18 wei
  const CAP_1 = 10 * 1e6 * 1e18;
  const CAP_2 = 25 * 1e6 * 1e18;
  const CAP_3 = 50 * 1e6 * 1e18;
  const FOUNDERS_TOKENS = 10 * 1e6 * 1e18;
  const STEP_LOCKED_TOKENS = 86400 * 30 * 6;
  const ADDITIONAL_TOKENS = 40 * 1e6 * 1e18;
  const GOAL = ether(1000);

  // const value = ether(1);
  const value = 1e0;

  before(async function() {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  // Create the HivePowerCrowdsale object
  beforeEach(async function() {
    this.startTime = latestTime() + duration.minutes(1);
    this.endTime = this.startTime + duration.minutes(2);
    this.afterEndTime = this.endTime + duration.seconds(1);
    this.token = await HVT.new();

    this.crowdsale = await HivePowerCrowdsale.new(
      [SIGNER_ADDR],
      this.token.address,
      wallet,
      this.startTime,
      this.endTime, [RATE_1, RATE_2, RATE_3], [CAP_1, CAP_2, CAP_3],
      GOAL,
      ADDITIONAL_TOKENS,
      FOUNDERS_TOKENS,
      STEP_LOCKED_TOKENS);

    await this.token.transferOwnership(this.crowdsale.address);
    await this.crowdsale.preallocate();
  });

  describe('Initial tests:', function() {
    it('should create crowdsale with correct parameters', async function() {
      this.crowdsale.should.exist;
      this.token.should.exist;

      const startTime = await this.crowdsale.startTime();
      const endTime = await this.crowdsale.endTime();
      const rate_1 = await this.crowdsale.prices(0);
      const rate_2 = await this.crowdsale.prices(1);
      const rate_3 = await this.crowdsale.prices(2);
      const walletAddress = await this.crowdsale.wallet();
      const goal = await this.crowdsale.goal();
      const cap_1 = await this.crowdsale.caps(0);
      const cap_2 = await this.crowdsale.caps(1);
      const cap_3 = await this.crowdsale.caps(2);

      startTime.should.be.bignumber.equal(this.startTime);
      endTime.should.be.bignumber.equal(this.endTime);
      rate_1.should.be.bignumber.equal(RATE_1);
      rate_2.should.be.bignumber.equal(RATE_2);
      rate_3.should.be.bignumber.equal(RATE_3);
      cap_1.should.be.bignumber.equal(CAP_1);
      cap_2.should.be.bignumber.equal(CAP_2);
      cap_3.should.be.bignumber.equal(CAP_3);
      walletAddress.should.be.equal(wallet);
      goal.should.be.bignumber.equal(GOAL);
    });

    it('should be token owner', async function() {
      const owner = await this.token.owner();
      owner.should.equal(this.crowdsale.address);
    });

    it('should fail the default callback', async function() {
      await this.crowdsale.sendTransaction({
        value: 100,
        from: investor
      }).should.be.rejectedWith(EVMRevert);
    });

    it('should not be allowed to call preallocate() twice', async function() {
      await this.crowdsale.preallocate().should.be.rejectedWith(EVMRevert);
    });

    it('should be ended only after end', async function() {
      let ended = await this.crowdsale.ended();
      ended.should.equal(false);
      await increaseTimeTo(this.afterEndTime);
      ended = await this.crowdsale.ended();
      ended.should.equal(true);
    });
  });

  describe('Payments tests', function() {
    it('should reject payments before start', async function() {
      const d = getKycData(investor, 1, this.crowdsale.address, SIGNER_PK);
      await this.crowdsale.buyTokens(d.id, d.max, d.v, d.r, d.s, {
        from: investor,
        value: MAX_AMOUNT
      }).should.be.rejectedWith(EVMRevert);
    });

    it('should accept valid payments after start', async function() {
      const d = getKycData(investor, 1, this.crowdsale.address, SIGNER_PK);
      await increaseTimeTo(this.startTime);
      const started = await this.crowdsale.started();
      started.should.be.all.equal(true);
      await this.crowdsale.buyTokens(d.id, d.max, d.v, d.r, d.s, {
        from: investor,
        value: MAX_AMOUNT
      }).should.be.fulfilled;
      const d2 = getKycData(investor, 1, this.crowdsale.address, OTHER_PK);
      await this.crowdsale.buyTokens(d2.id, d2.max, d2.v, d2.r, d2.s, {
        from: investor,
        value: MAX_AMOUNT
      }).should.be.rejectedWith(EVMRevert);
    });

    it('should reject payments after end', async function() {
      const d = getKycData(investor, 1, this.crowdsale.address, SIGNER_PK);
      await increaseTimeTo(this.endTime);
      const ended = await this.crowdsale.ended();
      ended.should.be.all.equal(true);
      await this.crowdsale.buyTokens(d.id, d.max, d.v, d.r, d.s, {
        from: investor,
        value: MAX_AMOUNT
      }).should.be.rejectedWith(EVMRevert);
    });
  });
});
