pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './Crowdsale.sol';
import './HVT.sol';

/**
 * @title HivePowerCrowdsale
 * @dev Crowdsale based on OpenZeppelin Crowdsale smart contract
 */
contract HivePowerCrowdsale is Crowdsale {

  function HivePowerCrowdsale(
    uint256 _startTimePreSale,
    uint256 _endTimePreSale,
    uint256 _startTimeSale,
    uint256 _endTimeSale,
    uint256 _ratePreSale,
    uint256 _rateSale,
    address _wallet)
    public
    Crowdsale(
      _startTimePreSale,
      _endTimePreSale,
      _startTimeSale,
      _endTimeSale,
      _ratePreSale,
      _rateSale,
      _wallet)
  {

  }
}
