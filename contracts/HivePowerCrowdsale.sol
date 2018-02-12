pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './Crowdsale.sol';
import './CappedCrowdsale.sol';
import './HVT.sol';

contract HivePowerCrowdsale is Crowdsale {

  function HivePowerCrowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet) public
    /*CappedCrowdsale(_cap)*/
    Crowdsale(_startTime, _endTime, _rate, _wallet)
  {
    /* To implement:
       - two phases with different rates
       - vesting policy
    */
  }
}
