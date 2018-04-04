pragma solidity 0.4.21;

import './SafeMath.sol';
import './Ownable.sol';
import './RefundVault.sol';
import './TokenTimelock.sol';
import "./ICOEngineInterface.sol";
import "./KYCBase.sol";
import "./HVT.sol";

// The Hive Power crowdsale contract
contract HivePowerCrowdsale is Ownable, ICOEngineInterface, KYCBase {
    using SafeMath for uint;
    enum State {Running,Success,Failure}

    State public state;

    HVT public token;

    address public wallet;

    // from ICOEngineInterface
    uint [] public prices;

    // from ICOEngineInterface
    uint public startTime;

    // from ICOEngineInterface
    uint public endTime;

    // from ICOEngineInterface
    uint [] public caps;

    // from ICOEngineInterface
    uint public remainingTokens;

    // from ICOEngineInterface
    uint public totalTokens;

    // amount of wei raised
    uint public weiRaised;

    // soft goal in wei
    uint public goal;

    // boolean to make sure preallocate is called only once
    bool public isPreallocated;

    // preallocated company token
    uint public companyTokens;

    // preallocated token for founders
    uint public foundersTokens;

    // vault for refunding
    RefundVault public vault;

    // addresses of time-locked founder vaults
    address [4] public timeLockAddresses;

    // step in seconds for token release
    uint public stepLockedToken;

    // allowed overshoot when crossing the bonus barrier (in wei)
    uint public overshoot;

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

    /**
     * event for additional token minting
     * @param timelock address of the time-lock contract
     * @param amount amount of tokens minted
     * @param releaseTime release time of tokens
     * @param wallet address of the wallet that can get the token released
     */
    event TimeLocked(address indexed timelock, uint256 amount, uint256 releaseTime, address indexed wallet);

    /**
     * event for additional token minting
     * @param to who got the tokens
     * @param amount amount of tokens purchased
     */
    event Preallocated(address indexed to, uint256 amount);

    /**
     *  After you deployed the SampleICO contract, you have to call the ERC20
     *  approve() method from the _wallet account to the deployed contract address to assign
     *  the tokens to be sold by the ICO.
     */
    function HivePowerCrowdsale(address [] kycSigner, address _token, address _wallet, uint _startTime, uint _endTime, uint [] _prices, uint [] _caps, uint _goal, uint _companyTokens, uint _foundersTokens, uint _stepLockedToken, uint _overshoot)
        public
        KYCBase(kycSigner)
    {
        require(_token != address(0));
        require(_wallet != address(0));
        require(_startTime > now);
        require(_endTime > _startTime);
        require(_prices.length == _caps.length);

        token = HVT(_token);
        wallet = _wallet;
        startTime = _startTime;
        endTime = _endTime;
        prices = _prices;
        caps = _caps;
        totalTokens = _caps[_caps.length-1];
        remainingTokens = _caps[_caps.length-1];
        vault = new RefundVault(_wallet);
        goal = _goal;
        companyTokens = _companyTokens;
        foundersTokens = _foundersTokens;
        stepLockedToken = _stepLockedToken;
        overshoot = _overshoot;
        state = State.Running;
        isPreallocated = false;
    }

    function preallocate() onlyOwner public {
      // can be called only once
      require(!isPreallocated);

      // mint tokens for team founders in timelocked vaults
      uint amount = foundersTokens.div(4); //amount of token per vault
      uint256 releaseTime = endTime;
      for(uint256 i=0; i < 4; i++)
      {
        // update releaseTime according to the step
        releaseTime = releaseTime.add(stepLockedToken);
        // create tokentimelock
        TokenTimelock timeLock = new TokenTimelock(token, wallet, releaseTime);
        // keep address in memory
        timeLockAddresses[i] = address(timeLock);
        // mint tokens in tokentimelock
        token.mint(address(timeLock), amount);
        // generate event
        TimeLocked(address(timeLock), amount, releaseTime, wallet);
      }

      //teamTimeLocks.mintTokens(teamTokens);
      // Mint additional tokens (referral, airdrops, etc.)
      token.mint(wallet, companyTokens);
      Preallocated(wallet, companyTokens);
      // cannot be called anymore
      isPreallocated = true;
    }

    // function that is called from KYCBase
    function releaseTokensTo(address buyer) internal returns(bool) {
        // needs to be started
        require(started());
        // and not ended
        require(!ended());

        uint256 weiAmount = msg.value;
        uint currentPrice = price();
        uint currentCap = getCap();
        uint tokens = weiAmount.mul(currentPrice);
        uint tokenRaised=totalTokens.sub(remainingTokens);
        //check if tokens can be minted
        require(tokenRaised.add(tokens) <= currentCap);

        weiRaised = weiRaised.add(weiAmount);
        remainingTokens = remainingTokens.sub(tokens);

        // mint tokens and transfer funds
        token.mint(buyer, tokens);
        forwardFunds();
        TokenPurchase(msg.sender, buyer, weiAmount, tokens);
        return true;
    }

    function forwardFunds() internal {
      vault.deposit.value(msg.value)(msg.sender);
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
      require(state == State.Running);
      require(ended());

      // Check the soft goal reaching
      if(weiRaised >= goal) {
        // if goal reached

        // stop the minting
        token.finishMinting();
        // enable token transfers
        token.enableTokenTransfers();
        // close the vault and transfer funds to wallet
        vault.close();

        // ICO successfully finalized
        // set state to Success
        state = State.Success;
        FinalizedOK();
      }
      else {
        // if goal NOT reached
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
       // run checks again because this is a public function
       require(state == State.Running);
       require(ended());
       // enable the refunds
       vault.enableRefunds();
       // ICO not successfully finalised
       // set state to Failure
       state = State.Failure;
       FinalizedNOK();
     }

     // if crowdsale is unsuccessful, investors can claim refunds here
     function claimRefund() public {
       require(state == State.Failure);
       vault.refund(msg.sender);
    }

    // get the next cap as a function of the amount of sold token
    function getCap() public view returns(uint){
      uint tokenRaised=totalTokens-remainingTokens;
      for (uint i=0;i<caps.length-1;i++){
        if (tokenRaised < caps[i])
        {
          // allow for a an overshoot (only when bonus is applied)
          uint tokenPerOvershoot = overshoot * prices[i];
          return(caps[i].add(tokenPerOvershoot));
        }
      }
      // but not on the total amount of tokens
      return(totalTokens);
    }

    // from ICOEngineInterface
    function started() public view returns(bool) {
        return now >= startTime;
    }

    // from ICOEngineInterface
    function ended() public view returns(bool) {
        return now >= endTime || remainingTokens == 0;
    }

    function startTime() public view returns(uint) {
      return(startTime);
    }

    function endTime() public view returns(uint){
      return(endTime);
    }

    function totalTokens() public view returns(uint){
      return(totalTokens);
    }

    function remainingTokens() public view returns(uint){
      return(remainingTokens);
    }

    // return the price as number of tokens released for each ether
    function price() public view returns(uint){
      uint tokenRaised=totalTokens-remainingTokens;
      for (uint i=0;i<caps.length-1;i++){
        if (tokenRaised < caps[i])
        {
          return(prices[i]);
        }
      }
      return(prices[prices.length-1]);
    }

    // No payable fallback function, the tokens must be buyed using the functions buyTokens and buyTokensFor
    function () public {
        revert();
    }

}
