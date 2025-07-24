// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RebaseToken is ERC20 {
     error RebaseToken_canOnlyDecreaseTheRate(uint256 oldinterestRate, uint256 newInterestRate);

     uint256 private s_interestRate = 5e10;

     event InterestChanged(uint256 newInteresetRate);

     constructor() ERC20 ("RebaseToken", "RBT") {}

     /**
      * @notice this set the Interest Rate only admin Can change 
      * @param _newInterestRate this is the new intereste that is about to take the place of old InterestRate
      * @dev the interest CAn only decrease
      */
     function setInterestRate(uint256 _newInterestRate) external {
          if(_newInterestRate < s_interestRate){
               revert RebaseToken_canOnlyDecreaseTheRate(s_interestRate,_newInterestRate);
          }
          s_interestRate =_newInterestRate;
          emit InterestChanged(_newInterestRate);
     }
}