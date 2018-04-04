pragma solidity 0.4.21;

import './MintableToken.sol';
import './BurnableToken.sol';
import './SafeMath.sol';
import './Ownable.sol';

contract HVT is MintableToken, BurnableToken {
  using SafeMath for uint256;

  string public name = "HiVe Token";
  string public symbol = "HVT";
  uint8 public decimals = 18;

  bool public enableTransfers = false;

  // functions overrides in order to maintain the token locked during the ICO
  function transfer(address _to, uint256 _value) public returns(bool) {
    require(enableTransfers);
    return super.transfer(_to,_value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
      require(enableTransfers);
      return super.transferFrom(_from,_to,_value);
  }

  function approve(address _spender, uint256 _value) public returns (bool) {
    require(enableTransfers);
    return super.approve(_spender,_value);
  }

  function burn(uint256 _value) public {
    require(enableTransfers);
    super.burn(_value);
  }

  // enable token transfers
  function enableTokenTransfers() public onlyOwner {
    enableTransfers = true;
  }
}
