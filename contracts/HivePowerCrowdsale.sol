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
/*contract HivePowerCrowdBatch2 is Ownable, ICOEngineInterface, KYCBase {*/
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

  // tokens assigned to the founders and timelocked
  uint256 public foundersTokens;

  // additional tokens (i.e. for private Batch2s, airdrops, referrals, etc.)
  uint256 public additionalTokens;

  // is the ICO successfully(not) finalized
  bool public isFinalizedOK = false;
  bool public isFinalizedNOK = false;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;

  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // timelocks for founders token
  TokenTimelock [4] public timeLocks;

  // step for the token releasing (ex. every 6 months a slot is released, starting from crowdsale end)
  uint256 stepReleaseLockedToken;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  /* ICO successfully finalized */
  event FinalizedOK();

  /* ICO not successfully finalized */
  event FinalizedNOK();

  /**
   * event for additional token minting
   */
  event MintedAdditionalTokens(address indexed to, uint256 amount);

  function HivePowerCrowdSale(uint256 _startTimeBatch1,
                              uint256 _endTimeBatch1,
                              uint256 _startTimeBatch2,
                              uint256 _endTimeBatch2,
                              uint256 _rateBatch1,
                              uint256 _rateBatch2,
                              uint256 _capBatch1,
                              uint256 _capBatch2,
                              uint256 _foundersTokens,
                              uint256 _stepReleaseLockedToken,
                              uint256 _additionalTokens,
                              uint256 _goal,
                              address _wallet)
                              public {
    // Check input arguments
    require(_startTimeBatch1 >= now);
    require(_endTimeBatch1 >= _startTimeBatch1);
    require(_startTimeBatch2 >= _endTimeBatch1);
    require(_endTimeBatch2 >= _startTimeBatch2);

    require(_rateBatch1 > 0);
    require(_rateBatch2 > 0);

    require(_capBatch1 > 0);
    require(_capBatch2 > 0);

    uint256 sumCaps = _capBatch1;
    sumCaps = sumCaps.add(capBatch2);
    require(_goal < sumCaps);

    require(_wallet != address(0));

    // Initialize variables
    token = createTokenContract();

    startTimeBatch1 = _startTimeBatch1;
    endTimeBatch1 = _endTimeBatch1;
    startTimeBatch2 = _startTimeBatch2;
    endTimeBatch2 = _endTimeBatch2;

    rateBatch1 = _rateBatch1;
    rateBatch2 = _rateBatch2;

    capBatch1 = _capBatch1;
    capBatch2 = _capBatch2;

    additionalTokens = _additionalTokens;

    goal = _goal;

    isFinalizedOK = false;
    isFinalizedNOK = false;

    wallet = _wallet;

    // vault definition for handling of an eventual refunding
    vault = new RefundVault(_wallet);

    // founders tokens handling
    foundersTokens = _foundersTokens;

    // create timelocks for tokens starting from the crowdsale end
    stepReleaseLockedToken = _stepReleaseLockedToken;
    createTokenTimeLocks();
  }

  function createTokenTimeLocks() onlyOwner internal {
    uint256 releaseTime = endTimeBatch2;
    for(uint256 i=0; i<4; i++)
    {
      releaseTime = releaseTime.add(stepReleaseLockedToken);
      // create tokentimelock
      timeLocks[i] = new TokenTimelock(HVT(token), wallet, releaseTime);
      // mint tokens in tokentimelock
      token.mint(address(timeLocks[i]), foundersTokens.div(4));
    }
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

  // @return true if the crowdsale event (Batch1 + Batch2) has ended (i.e. the second phase Batch2 has ended)
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
    // Batch1 phase check
    bool withinPeriodBatch1 = now >= startTimeBatch1 && now <= endTimeBatch1 && weiRaisedBatch1.add(msg.value) <= capBatch1;
    // Batch2 phase check
    bool withinPeriodBatch2 = now >= startTimeBatch2 && now <= endTimeBatch2 && weiRaisedBatch2.add(msg.value) <= capBatch2;

    bool withinPeriod = withinPeriodBatch1 || withinPeriodBatch2;

    bool nonZeroPurchase = msg.value != 0;

    return withinPeriod && nonZeroPurchase;
  }

  /**
   * @dev finalize an ICO in dependency of the goal reaching:
   * 1) reached goal (successful ICO):
   * -> mint additional tokens (i.e. for airdrops, referrals, founders, etc.) and assign them to the owner
   * -> release sold tokens for the transfers
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
      // Mint additional tokens (referral, airdrops, etc.) and assign them to the owner
      if(additionalTokens > 0) {
        token.mint(owner, additionalTokens);
        token.finishMinting();
        MintedAdditionalTokens(owner, additionalTokens);
      }

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
   * -> enable the refunds
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
      return startTimeBatch1;
    }
    else {
      return 0;
    }
  }

  // time stamp of the ending time of the ico, must retrun 0 if it depends on the block number
  function endTime() public view returns(uint) {
    if(isBatch1Running()) {
      return endTimeBatch2;
    }
    else if(isBatch2Running()) {
      return endTimeBatch2;
    }
    else {
      return 0;
    }
  }

  // returns the total number of the tokens available for the crowdsale, must not change when the ico is started
  function totalTokens() public view returns(uint) {
    if(isBatch1Running()) {
      return getTokenAmount(capBatch1, rateBatch1);
    }
    else if(isBatch2Running()) {
      uint256 totalCapTokens = getTokenAmount(capBatch1, rateBatch1);
      return totalCapTokens.add(getTokenAmount(capBatch2, rateBatch2));
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
