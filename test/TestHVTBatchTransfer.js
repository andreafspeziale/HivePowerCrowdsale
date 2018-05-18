/*
 * Utilities functions
 */

const EVMRevert = 'revert';
const BigNumber = web3.BigNumber;

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

function getSum(total, num) {
  return total + num;
}

function fillArray(value, len) {
  var arr = [];
  for (var i = 0; i < len; i++) {
    arr.push(value);
  }
  return arr;
}

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const HVT = artifacts.require('HVT');

// HVT contract
contract('HVT', function([owner, investor1, investor2, investor3]) {

  const TOTAL_TOKENS = 1000;
  const TOKEN_TRANSFER_SINGLE = 10;
  const TOKEN_TRANSFER_SINGLE_TOO_MUCH = 334;
  const TOKEN_TRANSFER_MULTI = [100, 200, 300];
  const TOKEN_TRANSFER_MULTI_TOO_MUCH = [400, 500, 600];

  const LONG_ADDRESS = fillArray(investor1, 100);
  const LONG_TOKEN_TRANSFER_SINGLE = 10;
  const LONG_TOKEN_TRANSFER_MULTI = fillArray(10, 100);

  var gasUsed = 0;
  var receipt;

  before(async function() {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  // Create the HivePowerCrowdsale object
  beforeEach(async function() {
    this.token = await HVT.new();
    await this.token.mint(owner, TOTAL_TOKENS);
    await this.token.enableTokenTransfers();
    gasUsed = 0;
  });

  describe('HVT tranfer tests:', function() {
    it('should create HVT contract and make HVT transferable', async function() {
      this.token.should.exist;
      (await this.token.enableTransfers()).should.be.true;
      (await this.token.balanceOf(owner)).should.be.bignumber.equal(TOTAL_TOKENS);
    });

    it('test successful normal transfer', async function() {
      await this.token.transfer(investor1, TOKEN_TRANSFER_SINGLE);
      await this.token.transfer(investor2, TOKEN_TRANSFER_SINGLE);
      await this.token.transfer(investor3, TOKEN_TRANSFER_SINGLE);

      (await this.token.balanceOf(owner)).should.be.bignumber.equal(TOTAL_TOKENS - TOKEN_TRANSFER_SINGLE * 3);
      (await this.token.balanceOf(investor1)).should.be.bignumber.equal(TOKEN_TRANSFER_SINGLE);
      (await this.token.balanceOf(investor2)).should.be.bignumber.equal(TOKEN_TRANSFER_SINGLE);
      (await this.token.balanceOf(investor3)).should.be.bignumber.equal(TOKEN_TRANSFER_SINGLE);
    });

    it('test unsuccessful normal transfer', async function() {
      await this.token.transfer(investor1, TOTAL_TOKENS + 1).should.be.rejectedWith(EVMRevert);
    });

    it('test successful batch transfer with same amount for everyone', async function() {
      await this.token.batchTransferSame([investor1, investor2, investor3], TOKEN_TRANSFER_SINGLE);
      (await this.token.balanceOf(owner)).should.be.bignumber.equal(TOTAL_TOKENS - TOKEN_TRANSFER_SINGLE * 3);
      (await this.token.balanceOf(investor1)).should.be.bignumber.equal(TOKEN_TRANSFER_SINGLE);
      (await this.token.balanceOf(investor2)).should.be.bignumber.equal(TOKEN_TRANSFER_SINGLE);
      (await this.token.balanceOf(investor3)).should.be.bignumber.equal(TOKEN_TRANSFER_SINGLE);
    });

    it('test unsuccessful batch transfer with same amount for everyone', async function() {
      await this.token.batchTransferSame([investor1, investor2, investor3], TOKEN_TRANSFER_SINGLE_TOO_MUCH).should.be.rejectedWith(EVMRevert);
    });

    it('test successful batch transfer with different amounts for everyone', async function() {
      await this.token.batchTransferDiff([investor1, investor2, investor3], TOKEN_TRANSFER_MULTI);
      (await this.token.balanceOf(owner)).should.be.bignumber.equal(TOTAL_TOKENS - (TOKEN_TRANSFER_MULTI.reduce(getSum)));
      (await this.token.balanceOf(investor1)).should.be.bignumber.equal(TOKEN_TRANSFER_MULTI[0]);
      (await this.token.balanceOf(investor2)).should.be.bignumber.equal(TOKEN_TRANSFER_MULTI[1]);
      (await this.token.balanceOf(investor3)).should.be.bignumber.equal(TOKEN_TRANSFER_MULTI[2]);
    });

    it('test unsuccessful batch transfer with different amount for everyone', async function() {
      await this.token.batchTransferDiff([investor1, investor2, investor3], TOKEN_TRANSFER_MULTI_TOO_MUCH).should.be.rejectedWith(EVMRevert);
    });
  });

  describe('HVT gas measurements:', function() {
    // it('test successful normal transfer', async function() {
    //   for (var i = 0; i < LONG_ADDRESS.length; i++) {
    //     receipt = await this.token.transfer(LONG_ADDRESS[i], LONG_TOKEN_TRANSFER_SINGLE);
    //     gasUsed += receipt.receipt.gasUsed;
    //   }
    //   console.log('GasUsed:' + gasUsed);
    //   (await this.token.balanceOf(owner)).should.be.zero;
    // });

    it('test successful batch transfer with same amount for everyone', async function() {
      receipt = await this.token.batchTransferSame(LONG_ADDRESS, LONG_TOKEN_TRANSFER_SINGLE);
      gasUsed = receipt.receipt.gasUsed;
      console.log('GasUsed:' + gasUsed);
      (await this.token.balanceOf(owner)).should.be.zero;
    });

    it('test successful batch transfer with different amounts for everyone', async function() {
      receipt = await this.token.batchTransferDiff(LONG_ADDRESS, LONG_TOKEN_TRANSFER_MULTI);
      gasUsed = receipt.receipt.gasUsed;
      console.log('GasUsed:' + gasUsed);
      (await this.token.balanceOf(owner)).should.be.zero;
    });
  });
});
