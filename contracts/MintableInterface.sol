pragma solidity 0.4.18;

contract MintableInterface {
  function mint(address _to, uint256 _amount) returns (bool);
  function mintLocked(address _to, uint256 _amount) returns (bool);
}
