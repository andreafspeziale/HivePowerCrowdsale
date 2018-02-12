pragma solidity 0.4.18;

/* Importing section */
import './ERC20.sol';

/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
 contract TokenTimelock {

   // ERC20 basic token contract being held
   ERC20Basic public token;

   // beneficiary of tokens after they are released
   address public beneficiary;

   // timestamp when token release is enabled
   uint public releaseTime;

   function TokenTimelock(ERC20Basic _token, address _beneficiary, uint _releaseTime) {
     require(_releaseTime > now);
     token = _token;
     beneficiary = _beneficiary;
     releaseTime = _releaseTime;
   }

   /**
    * @notice Transfers tokens held by timelock to beneficiary.
    */
   function release() {
     require(now >= releaseTime);

     uint amount = token.balanceOf(this);
     require(amount > 0);

     token.transfer(beneficiary, amount);
   }
 }
