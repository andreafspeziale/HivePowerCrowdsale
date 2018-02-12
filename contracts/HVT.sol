pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';

contract HVT is MintableToken {
  using SafeMath for uint256;

  string public name = "HiVe Token";
  string public symbol = "HVT";
  uint256 public decimals = 18;
}
