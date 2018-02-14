pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/crowdsale/RefundVault.sol';
import './HVT.sol';
/*import './ICOEngineInterface.sol';*/
/*import './KYCBase.sol';*/

/**
 * @title HivePowerCrowdsale
 * @dev HivePowerCrowdsale is a contract for managing a token crowdsale taken referring to OpenZeppelin Crowdsale and CappedCrowdsale contract.
 * Crowdsales have a start and end timestamps for two different phases (PreSale and Sale),
 * where investors can make token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate (different in the phases). Funds collected are forwarded to a wallet
 * as they arrive. Each phase has its cap.
 */
/*contract HivePowerCrowdsale is Ownable, ICOEngineInterface, KYCBase {*/
contract HivePowerCrowdsale is Ownable {
  using SafeMath for uint256;

  // The token being sold
  HVT public token;

  // start and end timestamps where investments are allowed (both inclusive) (PreSale phase)
  uint256 public startTimePreSale;
  uint256 public endTimePreSale;

  // start and end timestamps where investments are allowed (both inclusive) (Sale phase)
  uint256 public startTimeSale;
  uint256 public endTimeSale;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per wei (PreSale and Sale phases)
  uint256 public ratePreSale;
  uint256 public rateSale;

  // amount of raised money in wei
  uint256 public weiRaised;
  uint256 public weiRaisedPreSale;
  uint256 public weiRaisedSale;

  // caps
  uint256 public capPreSale;
  uint256 public capSale;

  // additional tokens (i.e. for private sales, airdrops, referrals, etc.)
  uint256 public additionalTokens;

  // is the ICO successfully(not) finalized
  bool public isFinalizedOK = false;
  bool public isFinalizedNOK = false;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;

  // minimum amount of funds to be raised in weis
  uint256 public goal;

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

  function HivePowerCrowdsale(uint256 _startTimePreSale,
                              uint256 _endTimePreSale,
                              uint256 _startTimeSale,
                              uint256 _endTimeSale,
                              uint256 _ratePreSale,
                              uint256 _rateSale,
                              uint256 _capPreSale,
                              uint256 _capSale,
                              uint256 _additionalTokens,
                              uint256 _goal,
                              address _wallet)
                              public {
    // Check input arguments
    require(_startTimePreSale >= now);
    require(_endTimePreSale >= _startTimePreSale);
    require(_startTimeSale >= _endTimePreSale);
    require(_endTimeSale >= _startTimeSale);

    require(_ratePreSale > 0);
    require(_rateSale > 0);

    require(_capPreSale > 0);
    require(_capSale > 0);

    uint256 sumCaps = _capPreSale;
    sumCaps = sumCaps.add(capSale);
    require(_goal < sumCaps);

    require(_wallet != address(0));

    // Initialize variables
    token = createTokenContract();

    startTimePreSale = _startTimePreSale;
    endTimePreSale = _endTimePreSale;
    startTimeSale = _startTimeSale;
    endTimeSale = _endTimeSale;

    ratePreSale = _ratePreSale;
    rateSale = _rateSale;

    capPreSale = _capPreSale;
    capSale = _capSale;

    additionalTokens = _additionalTokens;

    goal = _goal;

    isFinalizedOK = false;
    isFinalizedNOK = false;

    wallet = _wallet;

    vault = new RefundVault(wallet);
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

    // PreSale phase
    if(isPreSaleRunning())
    {
      // calculate token amount to be created and update state
      tokens = getTokenAmount(weiAmount, ratePreSale);
      weiRaisedPreSale = weiRaisedPreSale.add(weiAmount);
      weiRaised = weiRaised.add(weiAmount);

      // mint tokens and transfer funds
      token.mint(beneficiary, tokens);
      TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
      forwardFunds();
    }

    // Sale phase
    if(isSaleRunning())
    {
      // calculate token amount to be created and update state
      tokens = getTokenAmount(weiAmount, rateSale);
      weiRaisedSale = weiRaisedSale.add(weiAmount);
      weiRaised = weiRaised.add(weiAmount);

      // mint tokens and transfer funds
      token.mint(beneficiary, tokens);
      TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
      forwardFunds();
    }
  }

  // @return true if crowdsale is in the init phase (before PreSale)
  function isInit() public view returns (bool) {
    return now < startTimePreSale;
  }

  // @return true if crowdsale is running the PreSale phase
  function isPreSaleRunning() public view returns (bool) {
    return now >= startTimePreSale && now <= endTimePreSale && weiRaisedPreSale < capPreSale;
  }

  // @return true if crowdsale is the between PreSale and Sale phases
  function isBetweenPreSaleAndSale() public view returns (bool) {
    bool reachedPreSaleCap = now >= startTimePreSale && now <= endTimePreSale && weiRaisedPreSale >= capPreSale;
    bool withinBetweenPeriod = now > endTimePreSale && now < startTimeSale;
    return withinBetweenPeriod || reachedPreSaleCap;
  }

  // @return true if crowdsale is running the Sale phase
  function isSaleRunning() public view returns (bool) {
    return now >= startTimeSale && now <= endTimeSale && weiRaisedSale < capSale;
  }

  // @return true if the PreSale phase cap is reached
  function isPreSaleCapReached() public view returns (bool) {
    return weiRaisedPreSale == capPreSale;
  }

  // @return true if the Sale phase cap is reached
  function isSaleCapReached() public view returns (bool) {
    return weiRaisedSale == capSale;
  }

  // @return true if crowdsale (presale + sale) event has ended (i.e. the second phase has ended)
  function hasEnded() public view returns (bool) {
    bool reachedSaleCap = weiRaisedSale >= capSale;
    bool withinPeriod = now > endTimeSale;
    return reachedSaleCap || withinPeriod;
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
    bool withinPeriodPreSale = now >= startTimePreSale && now <= endTimePreSale && weiRaisedPreSale.add(msg.value) <= capPreSale;
    bool withinPeriodSale = now >= startTimeSale && now <= endTimeSale && weiRaisedSale.add(msg.value) <= capSale;
    bool withinPeriod = withinPeriodPreSale || withinPeriodSale;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  /**
   * @dev finalize an ICO in dependency of the goal reaching:
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
    return isPreSaleRunning() || isSaleRunning();
  }

  // false if the ico is not started, true if the ico is started and running, true if the ico is completed
  function endend() public view returns(bool) {
    return isBetweenPreSaleAndSale() || hasEnded();
  }

  // time stamp of the starting time of the ico, must return 0 if it depends on the block number
  function startTime() public view returns(uint256) {
    if(isPreSaleRunning()) {
      return startTimePreSale;
    }
    else if(isSaleRunning()) {
      return startTimePreSale;
    }
    else {
      return 0;
    }
  }

  // time stamp of the ending time of the ico, must retrun 0 if it depends on the block number
  function endTime() public view returns(uint) {
    if(isPreSaleRunning()) {
      return endTimeSale;
    }
    else if(isSaleRunning()) {
      return endTimeSale;
    }
    else {
      return 0;
    }
  }

  // returns the total number of the tokens available for the sale, must not change when the ico is started
  function totalTokens() public view returns(uint) {
    if(isPreSaleRunning()) {
      return getTokenAmount(capPreSale, ratePreSale);
    }
    else if(isSaleRunning()) {
      uint256 totalCapTokens = getTokenAmount(capPreSale, ratePreSale);
      return totalCapTokens.add(getTokenAmount(capSale, rateSale));
    }
    else {
      return 0;
    }
  }

  // returns the number of the tokens available for the ico. At the moment that the ico starts it must be equal to totalTokens(),
  // then it will decrease. It is used to calculate the percentage of sold tokens as remainingTokens() / totalTokens()
  function remainingTokens() public view returns(uint) {
    uint256 totTokens = totalTokens();
    uint256 raisedTokens;
    if(isPreSaleRunning()) {
      raisedTokens = getTokenAmount(weiRaisedPreSale, ratePreSale);
      return totTokens.sub(getTokenAmount(weiRaisedPreSale, ratePreSale));
    }
    else if(isSaleRunning()) {
      raisedTokens = getTokenAmount(weiRaisedPreSale, ratePreSale);
      raisedTokens = raisedTokens.add(getTokenAmount(weiRaisedSale, rateSale));
      return totTokens.sub(getTokenAmount(capSale, rateSale));
    }
    else {
      return 0;
    }
  }
}
