pragma solidity 0.4.18;

/* Importing section */
import './Crowdsale.sol';

/**
 * @title CappedCrowdsale
 * @dev Extension of Crowsdale with a max amount of funds raised
 */
 contract TokenCappedCrowdsale is Crowdsale {
   using SafeMath for uint256;

   // tokenCap should be initialized in derived contract
   uint256 public tokenCap;

   uint256 public soldTokens;

   // overriding Crowdsale#hasEnded to add tokenCap logic
   // @return true if crowdsale event has ended
   function hasEnded() public constant returns (bool) {
     bool capReached = soldTokens >= tokenCap;
     return super.hasEnded() || capReached;
   }

   // overriding Crowdsale#buyTokens to add extra tokenCap logic
   function buyTokens(address beneficiary) payable {
     // calculate token amount to be created
     uint256 tokens = msg.value.mul(rate);
     uint256 newTotalSold = soldTokens.add(tokens);
     require(newTotalSold <= tokenCap);
     soldTokens = newTotalSold;
     super.buyTokens(beneficiary);
   }
 }
