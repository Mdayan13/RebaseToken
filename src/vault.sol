// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interaction/IRebaseToken.sol";

contract Vault {
    error Vault__redeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Depositted(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getGlobslInterstRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Depositted(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__redeemFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
