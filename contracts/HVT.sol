pragma solidity 0.4.21;

import './MintableToken.sol';
import './BurnableToken.sol';
import './SafeMath.sol';

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

  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    require(enableTransfers);
    super.increaseApproval(_spender, _addedValue);
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    require(enableTransfers);
    super.decreaseApproval(_spender, _subtractedValue);
  }

  // enable token transfers
  function enableTokenTransfers() public onlyOwner {
    enableTransfers = true;
  }

  // batch transfer with different amounts for each address
  function batchTransferDiff(address[] _to, uint256[] _amount) public {
    require(enableTransfers);
    require(_to.length == _amount.length);
    uint256 totalAmount = arraySum(_amount);
    require(totalAmount <= balances[msg.sender]);
    balances[msg.sender] = balances[msg.sender].sub(totalAmount);
    for(uint i;i < _to.length;i++){
      balances[_to[i]] = balances[_to[i]].add(_amount[i]);
      Transfer(msg.sender,_to[i],_amount[i]);
    }
  }

  // batch transfer with same amount for each address
  function batchTransferSame(address[] _to, uint256 _amount) public {
    require(enableTransfers);
    uint256 totalAmount = _amount.mul(_to.length);
    require(totalAmount <= balances[msg.sender]);
    balances[msg.sender] = balances[msg.sender].sub(totalAmount);
    for(uint i;i < _to.length;i++){
      balances[_to[i]] = balances[_to[i]].add(_amount);
      Transfer(msg.sender,_to[i],_amount);
    }
  }

  // get sum of array values
  function arraySum(uint256[] _amount) internal pure returns(uint256){
    uint256 totalAmount;
    for(uint i;i < _amount.length;i++){
      totalAmount = totalAmount.add(_amount[i]);
    }
    return totalAmount;
  }
}
