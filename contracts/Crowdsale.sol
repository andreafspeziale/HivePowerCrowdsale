pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './HVT.sol';

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps fro two differe3nt phases (PreSale and Sale),
 * where investors can make token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate (different in the phases). Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract Crowdsale {
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

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


  function Crowdsale(
                      uint256 _startTimePreSale,
                      uint256 _endTimePreSale,
                      uint256 _startTimeSale,
                      uint256 _endTimeSale,
                      uint256 _ratePreSale,
                      uint256 _rateSale,
                      address _wallet)
                      public {
    require(_startTimePreSale >= now);
    require(_endTimePreSale >= _startTimePreSale);
    require(_startTimeSale >= _endTimePreSale);
    require(_endTimeSale >= _startTimeSale);

    require(_ratePreSale > 0);
    require(_rateSale > 0);

    require(_wallet != address(0));

    token = createTokenContract();

    startTimePreSale = _startTimePreSale;
    endTimePreSale = _endTimePreSale;
    startTimeSale = _startTimeSale;
    endTimeSale = _endTimeSale;

    ratePreSale = _ratePreSale;
    rateSale = _rateSale;

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

    // calculate token amount to be created
    uint256 tokens = getTokenAmount(weiAmount);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    forwardFunds();
  }

  // @return true if crowdsale (presale + sale) event has ended
  function hasEnded() public view returns (bool) {
    return now > endTimeSale;
  }

  // @return true if crowdsale is in the init phase (before PreSale)
  function isInit() public view returns (bool) {
    return now < startTimePreSale;
  }

  // @return true if crowdsale is running the PreSale phase
  function isPreSaleRunnig() public view returns (bool) {
    return now >= startTimePreSale && now <= endTimePreSale;
  }

  // @return true if crowdsale is the between PreSale and Sale phases
  function betweenPreSaleAndSale() public view returns (bool) {
    return now > endTimePreSale && now < startTimeSale;
  }

  // @return true if crowdsale is running the Sale phase
  function isSaleRunnig() public view returns (bool) {
    return now >= startTimeSale && now <= endTimeSale;
  }

  // creates the token to be sold.
  // override this method to have crowdsale of a specific mintable token.
  function createTokenContract() internal returns (HVT) {
    return new HVT();
  }

  // Override this method to have a way to add business logic to your crowdsale when buying
  function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
    if(now >= startTimePreSale && now <= endTimePreSale) {
      return weiAmount.mul(ratePreSale);
    }
    else if (now >= startTimeSale && now <= endTimeSale) {
      return weiAmount.mul(rateSale);
    }
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriodPreSale = now >= startTimePreSale && now <= endTimePreSale;
    bool withinPeriodSale = now >= startTimeSale && now <= endTimeSale;
    bool withinPeriod = withinPeriodPreSale || withinPeriodSale;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

}
