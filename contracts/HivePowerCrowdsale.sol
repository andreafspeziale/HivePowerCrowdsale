pragma solidity 0.4.19;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/crowdsale/RefundVault.sol';
import 'zeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol';
import './HVT.sol';

/*import './ICOEngineInterface.sol';*/
/*import './KYCBase.sol';*/

/**
 * @title HivePowerCrowdsale
 * @dev HivePowerCrowdsale is a contract for managing a token crowdsale taken referring to OpenZeppelin crowdsale contracts.
 * HivePowerCrowdsale is constituted by two different phases, following called Batch1 and Batch2).
 * Each phase has a start and end timestamp where investors can make token purchases and the contract will assign them
 * tokens basing on a token per ETH rate. Each phase has its maximum cap.
 * Funds collected are forwarded to a vault as they arrive.
 * If the ICO will be successful then the total fund is sent to a wallet, otherwise all will be refunded
 */
/*contract HivePowerCrowdsale is Ownable, ICOEngineInterface, KYCBase {*/
contract HivePowerCrowdsale is Ownable {
  using SafeMath for uint256;

  // The token being sold
  HVT public token;

  // start and end timestamps where investments are allowed (both inclusive) (Batch1 phase)
  uint256 public startTimeBatch1;
  uint256 public endTimeBatch1;

  // start and end timestamps where investments are allowed (both inclusive) (Batch2 phase)
  uint256 public startTimeBatch2;
  uint256 public endTimeBatch2;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per wei (Batch1 and Batch2 phases)
  uint256 public rateBatch1;
  uint256 public rateBatch2;

  // amount of raised money in wei
  uint256 public weiRaised;
  uint256 public weiRaisedBatch1;
  uint256 public weiRaisedBatch2;

  // caps
  uint256 public capBatch1;
  uint256 public capBatch2;

  // additional tokens (i.e. for private sales, airdrops, referrals, etc.)
  uint256 public additionalTokens;

  // is the ICO successfully(not) finalized
  bool public isFinalizedOK = false;
  bool public isFinalizedNOK = false;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;

  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // tokens assigned to the founders and timelocked
  uint256 public foundersTokens;

  // timelocks for founders token
  TokenTimelock [4] public timeLocks;

  // step for the token releasing (ex. every 6 months a slot is released, starting from crowdsale end)
  uint256 public stepLockedToken;
  bool public isLockedTokenDistributed = false;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  /* event for ICO successfully finalized */
  event FinalizedOK();

  /* event for ICO not successfully finalized */
  event FinalizedNOK();

  /* eventofor the creation of timelocks related to founders tokens */
  event CreatedTokenTimeLocks();

  /**
   * event for additional token minting
   * @param to who got the tokens
   * @param amount amount of tokens purchased
   */
  event MintedAdditionalTokens(address indexed to, uint256 amount);

  function HivePowerCrowdsale(uint256 _startTimeBatch1,       // start time of Batch1 phase
                              uint256 _endTimeBatch1,         // end time of Batch1 phase
                              uint256 _startTimeBatch2,       // start time of Batch2 phase
                              uint256 _endTimeBatch2,         // end time of Batch2 phase
                              uint256 _rateBatch1,            // rate of Batch1 phase
                              uint256 _rateBatch2,            // rate of Batch2 phase
                              uint256 _capBatch1,             // cap of Batch1 phase
                              uint256 _capBatch2,             // cap of Batch2 phase
                              uint256 _foundersTokens,        // founders tokens
                              uint256 _stepLockedToken,       // step for token timelock
                              uint256 _additionalTokens,      // additional tokens
                              uint256 _goal,                  // minimum goal to reach
                              address _wallet)                // wallet of the deployer
                              public {
    // initial checkings

    // timestamps checkings
    require(_startTimeBatch1 >= now);
    require(_endTimeBatch1 >= _startTimeBatch1);
    require(_startTimeBatch2 >= _endTimeBatch1);
    require(_endTimeBatch2 >= _startTimeBatch2);

    // rates must be >0
    require(_rateBatch1 > 0);
    require(_rateBatch2 > 0);

    // caps must be >0
    require(_capBatch1 > 0);
    require(_capBatch2 > 0);

    // goal must be smaller than the caps sum
    uint256 sumCaps = _capBatch1;
    sumCaps = sumCaps.add(_capBatch2);
    require(_goal < sumCaps);

    // wallet cannot be 0
    require(_wallet != address(0));

    // tokens for founders must be >0
    require(_foundersTokens > 0);

    // the timelocks for the founders tokens must have a duration
    require(_stepLockedToken > 0);

    // additional tokens must be >0
    require(_additionalTokens > 0);

    // Initialize variables
    token = createTokenContract();

    // periods
    startTimeBatch1 = _startTimeBatch1;
    endTimeBatch1 = _endTimeBatch1;
    startTimeBatch2 = _startTimeBatch2;
    endTimeBatch2 = _endTimeBatch2;

    // rates
    rateBatch1 = _rateBatch1;
    rateBatch2 = _rateBatch2;

    // caps
    capBatch1 = _capBatch1;
    capBatch2 = _capBatch2;

    // additional tokens (referrals, airdrops, etc.)
    additionalTokens = _additionalTokens;

    // minimum goal to reach
    goal = _goal;

    // wallet
    wallet = _wallet;

    // vault for eventual refunding
    vault = new RefundVault(wallet);

    // founders tokens
    foundersTokens = _foundersTokens;

    // delay in secs for the release of founders tokens
    stepLockedToken = _stepLockedToken;
    isLockedTokenDistributed = false;

    // variables related to ICO finalization
    isFinalizedOK = false;
    isFinalizedNOK = false;
  }

  /**
   * create token time locks (in the ICO stepReleaseLockedToken = 6 months)
   * - Slot n. 1 => 0.25 tokens released for founders since endTimeBatch2 + stepLockedToken*1 =>  6 month after ICO ends
   * - Slot n. 2 => 0.25 tokens released for founders since endTimeBatch2 + stepLockedToken*2 => 12 month after ICO ends
   * - Slot n. 3 => 0.25 tokens released for founders since endTimeBatch2 + stepLockedToken*3 => 18 month after ICO ends
   * - Slot n. 4 => 0.25 tokens released for founders since endTimeBatch2 + stepLockedToken*4 => 24 month after ICO ends
   */
  function createTokenTimeLocks() onlyOwner public {
    require(!isLockedTokenDistributed);

    uint256 releaseTime = endTimeBatch2;
    for(uint256 i=0; i < 4; i++)
    {
      // update releaseTime according to the step
      releaseTime = releaseTime.add(stepLockedToken);
      // create tokentimelock
      timeLocks[i] = new TokenTimelock(HVT(token), wallet, releaseTime);
      // mint tokens in tokentimelock
      token.mint(address(timeLocks[i]), foundersTokens.div(4));
    }
    // Set stepLockedToken to 0 to avoid further timelocks creations
    isLockedTokenDistributed  = true;
    CreatedTokenTimeLocks();
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
  /*function releaseTokensTo(address beneficiary) payable public returns(bool) {*/
    require(beneficiary != address(0));
    require(validPurchase());

    uint256 weiAmount = msg.value;
    uint256 tokens;

    // Batch1 phase running
    if(isBatch1Running())
    {
      // calculate token amount to be created and update state
      tokens = getTokenAmount(weiAmount, rateBatch1);
      weiRaisedBatch1 = weiRaisedBatch1.add(weiAmount);
      weiRaised = weiRaised.add(weiAmount);

      // mint tokens and transfer funds
      token.mint(beneficiary, tokens);
      TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
      forwardFunds();
    }

    // Batch2 phase running
    if(isBatch2Running())
    {
      // calculate token amount to be created and update state
      tokens = getTokenAmount(weiAmount, rateBatch2);
      weiRaisedBatch2 = weiRaisedBatch2.add(weiAmount);
      weiRaised = weiRaised.add(weiAmount);

      // mint tokens and transfer funds
      token.mint(beneficiary, tokens);
      TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
      forwardFunds();
    }
  }

  // @return true if crowdsale is in the init phase (before Batch1)
  function isInit() public view returns (bool) {
    return now < startTimeBatch1;
  }

  // @return true if crowdsale is running the Batch1 phase
  function isBatch1Running() public view returns (bool) {
    return now >= startTimeBatch1 && now <= endTimeBatch1 && weiRaisedBatch1 < capBatch1;
  }

  // @return true if crowdsale is the between Batch1 and Batch2 phases
  function isBetweenBatch1AndBatch2() public view returns (bool) {
    bool reachedBatch1Cap = now >= startTimeBatch1 && now <= endTimeBatch1 && weiRaisedBatch1 >= capBatch1;
    bool withinBetweenPeriod = now > endTimeBatch1 && now < startTimeBatch2;
    return withinBetweenPeriod || reachedBatch1Cap;
  }

  // @return true if crowdsale is running the Batch2 phase
  function isBatch2Running() public view returns (bool) {
    return now >= startTimeBatch2 && now <= endTimeBatch2 && weiRaisedBatch2 < capBatch2;
  }

  // @return true if the Batch1 phase cap is reached
  function isBatch1CapReached() public view returns (bool) {
    return weiRaisedBatch1 == capBatch1;
  }

  // @return true if the Batch2 phase cap is reached
  function isBatch2CapReached() public view returns (bool) {
    return weiRaisedBatch2 == capBatch2;
  }

  // @return true if crowdsale (presale + sale) event has ended (i.e. the second phase has ended)
  function hasEnded() public view returns (bool) {
    bool reachedBatch2Cap = weiRaisedBatch2 >= capBatch2;
    bool withinPeriod = now > endTimeBatch2;
    return reachedBatch2Cap || withinPeriod;
  }

  // @return HVT (Mintable Token) token instance
  function createTokenContract() internal returns (HVT) {
    return new HVT();
  }

  // @return token amount in dependency on a given rate
  function getTokenAmount(uint256 weiAmount, uint256 rate) internal pure returns(uint256) {
    return weiAmount.mul(rate);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriodBatch1 = now >= startTimeBatch1 && now <= endTimeBatch1 && weiRaisedBatch1.add(msg.value) <= capBatch1;
    bool withinPeriodBatch2 = now >= startTimeBatch2 && now <= endTimeBatch2 && weiRaisedBatch2.add(msg.value) <= capBatch2;
    bool withinPeriod = withinPeriodBatch1 || withinPeriodBatch2;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  /**
   * @dev finalize an ICO in dependency on the goal reaching:
   * 1) reached goal (successful ICO):
   * -> mint additional tokens (i.e. for airdrops, referrals, founders, etc.) and assign them to the owner
   * -> release sold token for the transfers
   * -> close the vault
   * -> close the ICO successfully
   * 2) not reached goal (not successful ICO):
   * -> call finalizeNOK()
   */
  function finalize() onlyOwner public {
    require(!isFinalizedOK);
    require(!isFinalizedNOK);
    require(hasEnded());

    // Check the goal reaching
    if(weiRaised >= goal) {
      // Mint additional tokens (referral, airdrops, etc.)
      token.mint(owner, additionalTokens);
      token.finishMinting();
      MintedAdditionalTokens(owner, additionalTokens);

      // Enabling token transfers
      token.enableTokenTransfers();

      // Close the vault
      vault.close();

      // ICO successfully finalised
      isFinalizedOK = true;
      FinalizedOK();
    }
    else {
      // ICO not successfully finalised
      finalizeNOK();
    }
  }

  /**
   * @dev finalize an unsuccessful ICO:
   * -> enable the refund
   * -> close the ICO not successfully
   */
   function finalizeNOK() onlyOwner public {
     require(!isFinalizedOK);
     require(!isFinalizedNOK);
     require(hasEnded());

     // enable the refunds
     vault.enableRefunds();

     // ICO not successfully finalised
     isFinalizedNOK = true;
     FinalizedNOK();
   }

   // if crowdsale is unsuccessful, investors can claim refunds here
   function claimRefund() public {
     require(isFinalizedNOK);

     vault.refund(msg.sender);
  }

  // Overriding the fund forwarding from Crowdsale.
  // In addition to sending the funds, we want to call
  // the RefundVault deposit function
  function forwardFunds() internal {
    vault.deposit.value(msg.value)(msg.sender);
  }

  /*******************************************************************
  * ICOEngineInterface functions implementations for Eidoo platform  *
  *******************************************************************/

   // false if the ico is not started, true if the ico is started and running, true if the ico is completed
  function started() public view returns(bool) {
    return isBatch1Running() || isBatch2Running();
  }

  // false if the ico is not started, true if the ico is started and running, true if the ico is completed
  function endend() public view returns(bool) {
    return isBetweenBatch1AndBatch2() || hasEnded();
  }

  // time stamp of the starting time of the ico, must return 0 if it depends on the block number
  function startTime() public view returns(uint256) {
    if(isBatch1Running()) {
      return startTimeBatch1;
    }
    else if(isBatch2Running()) {
      return startTimeBatch2;
    }
    else {
      return 0;
    }
  }

  // time stamp of the ending time of the ico, must retrun 0 if it depends on the block number
  function endTime() public view returns(uint) {
    if(isBatch1Running()) {
      return endTimeBatch1;
    }
    else if(isBatch2Running()) {
      return endTimeBatch2;
    }
    else {
      return 0;
    }
  }

  // returns the total number of the tokens available for the sale, must not change when the ico is started
  function totalTokens() public view returns(uint) {
    if(isBatch1Running()) {
      return getTokenAmount(capBatch1, rateBatch1);
    }
    else if(isBatch2Running()) {
      uint256 totalCapTokensBatch1 = getTokenAmount(capBatch1, rateBatch1);
      uint256 totalCapTokensBatch2 = getTokenAmount(capBatch2, rateBatch2);
      return totalCapTokensBatch1.add(totalCapTokensBatch2);
    }
    else {
      return 0;
    }
  }

  // returns the number of the tokens available for the ico. At the moment that the ico starts it must be equal to totalTokens(),
  // then it will decrease. It is used to calculate the percentage of sold tokens as remainingTokens() / totalTokens()
  function remainingTokens() public view returns(uint) {
    uint256 totTokens = totalTokens();
    uint256 raisedTokens = token.totalSupply();
    return totTokens.sub(raisedTokens);
  }
}
