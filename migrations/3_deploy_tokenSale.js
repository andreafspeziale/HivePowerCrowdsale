var SafeMath = artifacts.require('./SafeMath.sol');
var HVT = artifacts.require('./HVT.sol');
var HivePowerCrowdsale = artifacts.require('./HivePowerCrowdsale.sol');
const moment = require('moment');

const stagingKYCSigners = ['0x890d4c6b94e6f54bdbb58530f425c2a5a3033361', '0xc5fdf4076b8f3a5357c5e395ab970b5b54098fef']

module.exports = function(deployer, network, accounts) {

  if (network == 'development') {
    // Wallet
    var wallet = accounts[1];

    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (60 * 1);
    var startTime = initialDelay; // ICO starting 1 hour after the initial deployment
    var endTime = startTime + (3600 * 1); // ICO end

    var etherPriceUSD = 1000000; // 1 million dollars ;-)
    var rate1 = parseInt((etherPriceUSD / 0.25) * 1.3);
    var rate2 = parseInt((etherPriceUSD / 0.25) * 1.1);
    var rate3 = parseInt((etherPriceUSD / 0.25) * 1.0);

    var cap1 = 10 * 1e6 * 1e18;
    var cap2 = 25 * 1e6 * 1e18;
    var cap3 = 50 * 1e6 * 1e18;

    var foundersTokens = 10 * 1e6 * 1e18;
    var stepLockedToken = 86400 * 30 * 6;
    var additionalTokens = 40 * 1e6 * 1e18;
    var goal = parseInt(1000000 / etherPriceUSD * 1e18);

    var overshoot = web3.toWei(5, 'ether');

    //kyc signers
    var kycSigners = [accounts[2], accounts[3]];
  } else if (network == 'eidoo') {
    // Wallet
    var wallet = accounts[1];

    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (3600 * 1);

    var startTime = initialDelay; // ICO starting 1 hour after the initial deployment
    var endTime = startTime + (3600 * 2); // ICO end

    var etherPriceUSD = 500;
    var rate1 = parseInt((etherPriceUSD / 0.25) * 1.3);
    var rate2 = parseInt((etherPriceUSD / 0.25) * 1.1);
    var rate3 = parseInt((etherPriceUSD / 0.25) * 1.0);

    var cap1 = 10 * 1e6 * 1e18;
    var cap2 = 25 * 1e6 * 1e18;
    var cap3 = 50 * 1e6 * 1e18;

    var foundersTokens = 10 * 1e6 * 1e18;
    var stepLockedToken = 86400 * 30 * 6;
    var additionalTokens = 40 * 1e6 * 1e18;
    var goal = parseInt(1000000 / etherPriceUSD * 1e18);

    var overshoot = web3.toWei(5, 'ether');

    //kyc signers
    var kycSigners = [stagingKYCSigners[0], stagingKYCSigners[1]];
  } else if (network == 'ropsten') {
    // Wallet
    var wallet = accounts[1];

    var initialDelay = web3.eth.getBlock(web3.eth.blockNumber).timestamp + (3600 * 1);

    var startTime = initialDelay; // ICO starting 1 hour after the initial deployment
    var endTime = startTime + (3600 * 2); // ICO end

    var etherPriceUSD = 500;
    var rate1 = parseInt((etherPriceUSD / 0.25) * 1.3);
    var rate2 = parseInt((etherPriceUSD / 0.25) * 1.1);
    var rate3 = parseInt((etherPriceUSD / 0.25) * 1.0);

    var cap1 = 10 * 1e6 * 1e18;
    var cap2 = 25 * 1e6 * 1e18;
    var cap3 = 50 * 1e6 * 1e18;

    var foundersTokens = 10 * 1e6 * 1e18;
    var stepLockedToken = 86400 * 30 * 6;
    var additionalTokens = 40 * 1e6 * 1e18;
    var goal = parseInt(1000000 / etherPriceUSD * 1e18);

    var overshoot = web3.toWei(5, 'ether');

    //kyc signers
    var kycSigners = [accounts[2], accounts[3]];
  } else if (network == 'mainnet') {
    // Wallet
    var wallet = '0xde5f3719d0ab1a308c1d66fda248f8497bcd42d8';

    var startTime = moment.utc('2018-04-23 00:00').toDate().getTime() / 1000;
    var endTime = moment.utc('2018-05-15 00:00').toDate().getTime() / 1000;

    var etherPriceUSD = 500; //TBD before the start of the crodwsale
    var rate1 = parseInt((etherPriceUSD / 0.25) * 1.3);
    var rate2 = parseInt((etherPriceUSD / 0.25) * 1.1);
    var rate3 = parseInt((etherPriceUSD / 0.25) * 1.0);

    var cap1 = 10 * 1e6 * 1e18;
    var cap2 = 25 * 1e6 * 1e18;
    var cap3 = 50 * 1e6 * 1e18;

    var foundersTokens = 10 * 1e6 * 1e18;
    var stepLockedToken = 86400 * 30 * 6;
    var additionalTokens = 40 * 1e6 * 1e18;
    var goal = parseInt(1000000 / etherPriceUSD * 1e18);

    var overshoot = web3.toWei(5, 'ether');

    //kyc signers
    var kycSigners = [accounts[2], accounts[3]]; //TDB before the start of the crodwsale
  }

  deployer.deploy(SafeMath);
  deployer.link(SafeMath, HivePowerCrowdsale);
  deployer.deploy(HivePowerCrowdsale,
    kycSigners,
    HVT.address,
    wallet,
    startTime,
    endTime, [rate1, rate2, rate3], [cap1, cap2, cap3],
    goal,
    additionalTokens,
    foundersTokens,
    stepLockedToken,
    overshoot);
};
