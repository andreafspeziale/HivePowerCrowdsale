pragma solidity 0.4.19;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/crowdsale/RefundVault.sol';
import 'zeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol';
import './HVT.sol';
import './ICOEngineInterface.sol';
import './KYCBase.sol';

/**
 * @title HivePowerCrowdsale
 * @dev HivePowerCrowdsale is a smart contract to manage a token crowdsale taken referring to OpenZeppelin contracts.
 * HivePowerCrowdsale is constituted by a sale period divided in three phases (1, 2, 3).
 * During each phase the investors can make token purchases and the contract will assign them
 * tokens basing on a token-per-wei rate. Each phase has an own maximum cap.
 * Funds collected are forwarded to a vault as they arrive.
 * If the ICO will be successful then the total fund will be sent to a wallet, otherwise all will be refunded
 */
/*contract HivePowerCrowdsale is Ownable, ICOEngineInterface, KYCBase {*/
contract HivePowerCrowdsale is Ownable {
  using SafeMath for uint256;

  // The token being sold
  HVT public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per wei (3 different casee)
  uint256 public ratePhase1;
  uint256 public ratePhase2;
  uint256 public ratePhase3;

  // amount of raised money in wei
  uint256 public weiRaised = 0;

  // amounts of raised token for each phase
  uint256 public tokenRaised = 0;

  // caps in tokens for each phase
  uint256 public capPhase1;
  uint256 public capPhase2;
  uint256 public capPhase3;

  // is the ICO successfully finalized
  bool public isFinalizedOK = false;
  // is the ICO not successfully finalized
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

  // additional tokens (i.e. for private sales, airdrops, referrals, etc.)
  uint256 public additionalTokens;
  bool public isAdditionalTokenDistributed = false;

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

  function HivePowerCrowdsale(uint256 _startTime,             // start time
                              uint256 _endTime,               // end time
                              uint256 _ratePhase1,            // rate (HVT/ETH) of phase 1
                              uint256 _ratePhase2,            // rate (HVT/ETH) of phase 2
                              uint256 _ratePhase3,            // rate (HVT/ETH) of phase 3
                              uint256 _capPhase1,             // token cap of phase 1
                              uint256 _capPhase2,             // token cap of phase 2
                              uint256 _capPhase3,             // token cap of phase 3
                              uint256 _foundersTokens,        // founders tokens
                              uint256 _stepLockedToken,       // step for token timelocks
                              uint256 _additionalTokens,      // additional tokens
                              uint256 _goal,                  // minimum goal to reach
                              address _wallet)                // wallet of the company
                              public {
    // initial checkings

    // timestamps checkings
    require(_startTime >= now);
    require(_endTime > _startTime);

    // more the phase is higher, lesser the rate is convenient
    require(_ratePhase1 > _ratePhase2);
    require(_ratePhase2 > _ratePhase3);
    require(_ratePhase3 > 0);

    // caps must be >0
    require(_capPhase1 > 0);
    require(_capPhase2 > 0);
    require(_capPhase3 > 0);

    // wallet cannot be 0
    require(_wallet != address(0));

    // tokens for founders must be >0
    require(_foundersTokens > 0);

    // additional tokens must be >0
    require(_additionalTokens > 0);

    // the timelocks for the founders tokens must have a duration
    require(_stepLockedToken > 0);

    // Initialize variables
    token = createTokenContract();

    // period
    startTime = _startTime;
    endTime = _endTime;

    // rates
    ratePhase1 = _ratePhase1;
    ratePhase2 = _ratePhase2;
    ratePhase3 = _ratePhase3;

    // caps
    capPhase1 = _capPhase1;
    capPhase2 = _capPhase2;
    capPhase3 = _capPhase3;

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
    isAdditionalTokenDistributed = false;

    // variables related to ICO finalization
    isFinalizedOK = false;
    isFinalizedNOK = false;
  }

  /**
   * create token time locks (in the ICO stepReleaseLockedToken = 6 months)
   * - Slot n. 1 => 0.25 tokens released for founders since endTime + stepLockedToken*1 =>  6 month after ICO end
   * - Slot n. 2 => 0.25 tokens released for founders since endTime + stepLockedToken*2 => 12 month after ICO end
   * - Slot n. 3 => 0.25 tokens released for founders since endTime + stepLockedToken*3 => 18 month after ICO end
   * - Slot n. 4 => 0.25 tokens released for founders since endTime + stepLockedToken*4 => 24 month after ICO end
   */
  function mintAdditionalTokens() onlyOwner public {
    require(!isAdditionalTokenDistributed);

    // mint tokens for team founders in timelocked vaults
    uint256 releaseTime = endTime;

    for(uint256 i=0; i < 4; i++)
    {
      // update releaseTime according to the step
      releaseTime = releaseTime.add(stepLockedToken);

      // create tokentimelock
      timeLocks[i] = new TokenTimelock(HVT(token), wallet, releaseTime);

      // mint tokens in tokentimelock
      token.mint(address(timeLocks[i]), foundersTokens.div(4));
    }
    CreatedTokenTimeLocks();

    // Mint additional tokens (referral, airdrops, etc.)
    token.mint(wallet, additionalTokens);
    MintedAdditionalTokens(wallet, additionalTokens);

    isAdditionalTokenDistributed = true;
  }

  // low level token purchase function
  // Function for Eidoo interface
  // function releaseTokensTo(address beneficiary) internal returns(bool) {
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(validPurchase());

    // running phase1
    if(isPhase1Running())
    {
      createTokens(beneficiary, ratePhase1, capPhase1);
    }

    // running phase2
    if(isPhase2Running())
    {
      createTokens(beneficiary, ratePhase2, capPhase2);
    }

    // running phase3
    if(isPhase3Running())
    {
      createTokens(beneficiary, ratePhase3, capPhase3);
    }
  }

  // create tokens after maximum cap checking given a rate
  function createTokens(address beneficiary, uint256 rate, uint256 cap) internal returns (bool) {
    // calculate token amount to be created and update state
    uint256 weiAmount = msg.value;
    uint256 tokens = getTokenAmount(weiAmount, rate);

    //check if tokens can be minted
    require(tokenRaised.add(tokens) <= cap);

    weiRaised = weiRaised.add(weiAmount);
    tokenRaised = tokenRaised.add(tokens);

    // mint tokens and transfer funds
    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    forwardFunds();
  }

  // @return true if crowdsale is in the valid period
  function isValidPeriod() public view returns (bool) {
    return now >= startTime && now <= endTime;
  }

  // @return true if crowdsale is running the phase 1
  function isPhase1Running() public view returns (bool) {
    return isValidPeriod() && tokenRaised < capPhase1;
  }

  // @return true if crowdsale is running the phase 2
  function isPhase2Running() public view returns (bool) {
    return isValidPeriod() && tokenRaised >= capPhase1 && tokenRaised < capPhase2;
  }

  // @return true if crowdsale is running the phase 3
  function isPhase3Running() public view returns (bool) {
    return isValidPeriod() && tokenRaised >= capPhase2 && tokenRaised < capPhase3;
  }

  // @return true if sale event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime || tokenRaised >= capPhase3;
  }

  // @return HVT (Mintable Token) token instance
  function createTokenContract() internal returns (HVT) {
    return new HVT();
  }

  // @return token amount in dependency on a given rate
  function getTokenAmount(uint256 weiAmount, uint256 rate) internal pure returns(uint256) {
    return weiAmount.mul(rate);
  }

  // @return true if the transaction is available
  function validPurchase() internal view returns (bool) {
    // check if the sale is running one of its three phases
    bool withinPeriod = isPhase1Running() || isPhase2Running() || isPhase3Running();

    // check the amount
    bool nonZeroPurchase = msg.value != 0;

    return withinPeriod && nonZeroPurchase;
  }

  /**
   * @dev finalize an ICO in dependency on the goal reaching:
   * 1) reached goal (successful ICO):
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
      // stop the minting
      token.finishMinting();

      // enabling token transfers
      token.enableTokenTransfers();

      // close the vault
      vault.close();

      // ICO successfully finalized
      isFinalizedOK = true;
      FinalizedOK();
    }
    else {
      // ICO not successfully finalized
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
    return now >= startTime;
  }

  // false if the ico is not started, false if the ico is started and running, true if the ico is completed
  function endend() public view returns(bool) {
    return hasEnded();
  }

  // time stamp of the starting time of the ico, must return 0 if it depends on the block number
  function startTime() public view returns(uint256) {
    return startTime;
  }

  // time stamp of the ending time of the ico, must retrun 0 if it depends on the block number
  function endTime() public view returns(uint) {
    return endTime;
  }

  // returns the total number of the tokens available for the sale, must not change when the ico is started
  function totalTokens() public view returns(uint) {
    uint totTokens = capPhase1;
    totTokens = totTokens.add(capPhase2);
    return totTokens.add(capPhase3);
  }

  // returns the number of the tokens available for the ico. At the moment that the ico starts it must be equal to totalTokens(),
  // then it will decrease. It is used to calculate the percentage of sold tokens as remainingTokens() / totalTokens()
  function remainingTokens() public view returns(uint) {
    uint totTokens = totalTokens();
    return totTokens.sub(tokenRaised);
  }

  // return the price as number of tokens released for each ether
  function price() public view returns(uint) {
    if(isPhase1Running()) {
      return ratePhase1;
    }
    else if(isPhase2Running()) {
      return ratePhase2;
    }
    else if(isPhase3Running()) {
      return ratePhase3;
    }
    else {
      return 0;
    }
  }
}
