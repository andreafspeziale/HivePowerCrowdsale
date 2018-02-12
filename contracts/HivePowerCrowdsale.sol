pragma solidity 0.4.18;

/* Importing section */
import './Ownable.sol';
import './SafeMath.sol';
import './MintableInterface.sol';
import './TokenCappedCrowdsale.sol';
import './HVT.sol';
import './TokenTimelock.sol';


 contract HivePowerCrowdsale is Ownable, TokenCappedCrowdsale {
   using SafeMath for uint256;
   uint256 public MAXIMUM_SUPPLY = 100000000 * 10**18;
   uint256 [] public LOCKED = [     20000000 * 10**18,
                                    15000000 * 10**18,
                                     6000000 * 10**18,
                                     6000000 * 10**18 ];
   uint256 public POST_ICO =        21000000 * 10**18;
   uint256 [] public LOCK_END = [
     1588334400,    // Release n.4 ->  01.05.2020 12:00:00 GMT
     1572609600,    // Release n.3 ->  01.11.2019 12:00:00 GMT
     1556712000,    // Release n.2 ->  01.05.2019 12:00:00 GMT
     1541073600     // Release n.1 ->  01.11.2018 12:00:00 GMT
   ];

   mapping (address => bool) public claimed;
   TokenTimelock [4] public timeLocks;

   event ClaimTokens(address indexed to, uint amount);

   modifier beforeStart() {
     require(block.number < startBlock);
     _;
   }

   //_startBlock, _endBlock, _rate, _wallet
   function HivePowerCrowdsale(
     uint256 _startBlock,
     uint256 _endBlock,
     uint256 _rate,
     uint256 _tokenStartBlock,
     uint256 _tokenLockEndBlock,
     address _wallet)
     Crowdsale(_startBlock, _endBlock, _rate, _wallet) {
       token = new HVT(_tokenStartBlock, _tokenLockEndBlock);

       // create timelocks for tokens
       timeLocks[0] = new TokenTimelock(HVT(token), _wallet, LOCK_END[0]);
       timeLocks[1] = new TokenTimelock(HVT(token), _wallet, LOCK_END[1]);
       timeLocks[2] = new TokenTimelock(HVT(token), _wallet, LOCK_END[2]);
       timeLocks[3] = new TokenTimelock(HVT(token), _wallet, LOCK_END[3]);
       token.mint(address(timeLocks[0]), LOCKED[0]);
       token.mint(address(timeLocks[1]), LOCKED[1]);
       token.mint(address(timeLocks[2]), LOCKED[2]);
       token.mint(address(timeLocks[3]), LOCKED[3]);

       token.mint(_wallet, POST_ICO);

       // initialize maximum number of tokens that can be sold
       tokenCap = MAXIMUM_SUPPLY.sub(HVT(token).totalSupply());
   }

   function claimTokens(address [] buyers, uint [] amounts) onlyOwner beforeStart public {
     require(buyers.length == amounts.length);
     uint len = buyers.length;
     for (uint i = 0; i < len; i++) {
       address to = buyers[i];
       uint256 amount = amounts[i];
       if (amount > 0 && !claimed[to]) {
         claimed[to] = true;
         tokenCap = tokenCap.sub(amount);
         uint256 unlockedAmount = amount.div(10).mul(3);
         token.mint(to, unlockedAmount);
         token.mintLocked(to, amount.sub(unlockedAmount));
         ClaimTokens(to, amount);
       }
     }
   }

 }
