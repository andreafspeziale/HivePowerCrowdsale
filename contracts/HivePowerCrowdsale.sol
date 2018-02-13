pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './HVT.sol';

/**
 * @title HivePowerCrowdsale
 * @dev HivePowerCrowdsale is a contract for managing a token crowdsale taken referring to OpenZeppelin Crowdsale and CappedCrowdsale contract.
 * Crowdsales have a start and end timestamps for two different phases (PreSale and Sale),
 * where investors can make token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate (different in the phases). Funds collected are forwarded to a wallet
 * as they arrive. Each phase has its cap.
 */
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

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


  function HivePowerCrowdsale(uint256 _startTimePreSale,
                              uint256 _endTimePreSale,
                              uint256 _startTimeSale,
                              uint256 _endTimeSale,
                              uint256 _ratePreSale,
                              uint256 _rateSale,
                              uint256 _capPreSale,
                              uint256 _capSale,
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

    wallet = _wallet;
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
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
  function betweenPreSaleAndSale() public view returns (bool) {
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

  // send ether to the fund collection wallet
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriodPreSale = now >= startTimePreSale && now <= endTimePreSale && weiRaisedPreSale.add(msg.value) <= capPreSale;
    bool withinPeriodSale = now >= startTimeSale && now <= endTimeSale && weiRaisedSale.add(msg.value) <= capSale;
    bool withinPeriod = withinPeriodPreSale || withinPeriodSale;
    bool nonZeroPurchase = msg.value != 0;

    return withinPeriod && nonZeroPurchase;
  }

}
