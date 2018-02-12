pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './MintableInterface.sol';
import './StandardToken.sol';


contract HVT is MintableInterface, Ownable, StandardToken {
  using SafeMath for uint256;

  string public name = "HiVe Token";
  string public symbol = "HVT";
  uint256 public decimals = 18;

  uint256 public transferableFromBlock;
  uint256 public lockEndBlock;
  mapping (address => uint256) public initiallyLockedAmount;

  function HVT(uint256 _transferableFromBlock, uint256 _lockEndBlock) public {
    require(_lockEndBlock > _transferableFromBlock);
    transferableFromBlock = _transferableFromBlock;
    lockEndBlock = _lockEndBlock;
  }

  modifier canTransfer(address _from, uint _value) {
    if (block.number < lockEndBlock) {
      require(block.number >= transferableFromBlock);
      uint256 locked = lockedBalanceOf(_from);
      if (locked > 0) {
        uint256 newBalance = balanceOf(_from).sub(_value);
        require(newBalance >= locked);
      }
    }
   _;
  }

  function lockedBalanceOf(address _to) public constant returns(uint256) {
    uint256 locked = initiallyLockedAmount[_to];
    if (block.number >= lockEndBlock ) return 0;
    else if (block.number <= transferableFromBlock) return locked;

    uint256 releaseForBlock = locked.div(lockEndBlock.sub(transferableFromBlock));
    uint256 released = block.number.sub(transferableFromBlock).mul(releaseForBlock);
    return locked.sub(released);
  }

  function transfer(address _to, uint _value) canTransfer(msg.sender, _value) public returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint _value) canTransfer(_from, _value) public returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  // --------------- Minting methods

  modifier canMint() {
    require(!mintingFinished());
    _;
  }

  function mintingFinished() public constant returns(bool) {
    return block.number >= transferableFromBlock;
  }

  /**
   * @dev Function to mint tokens, implements MintableInterface
   * @param _to The address that will recieve the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Transfer(address(0), _to, _amount);
    return true;
  }

  function mintLocked(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
    initiallyLockedAmount[_to] = initiallyLockedAmount[_to].add(_amount);
    return mint(_to, _amount);
  }

  function burn(uint256 _amount) public returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_amount);
    totalSupply = totalSupply.sub(_amount);
    Transfer(msg.sender, address(0), _amount);
    return true;
  }
}
