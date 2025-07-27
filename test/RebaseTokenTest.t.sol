// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebaseToken} from "../src/RebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IRebaseToken} from "../src/interaction/IRebaseToken.sol";
import {Vault} from "../src/vault.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    uint256 public SEND_VALUE = 1e5;
    address public Owner = makeAddr("Owner");
    address public User = makeAddr("User");

    function setUp() public {
        vm.startPrank(Owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addrewardsTovault(uint256 amountToadd) public {
        (bool success,) = payable(address(vault)).call{value: amountToadd}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(User);
        vm.deal(User, amount);
        vault.deposit{value: amount}();

        uint256 startBalance = rebaseToken.balanceOf(User);
        console.log("starting Balance:- ", startBalance);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(User);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 lastBAlance = rebaseToken.balanceOf(User);
        assertGt(lastBAlance, middleBalance);

        assertApproxEqAbs(lastBAlance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(User);
        vm.deal(User, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(User), amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(User), 0);
        assertEq(address(User).balance, amount);
        vm.stopPrank();
    }

    function testReedeemFilterAfterPassed(uint256 deposittedAmount, uint256 timw) public {
        timw = bound(timw, 1000, type(uint96).max);
        deposittedAmount = bound(deposittedAmount, 1e5, type(uint96).max);

        vm.deal(User, deposittedAmount);
        vm.prank(User);
        vault.deposit{value: deposittedAmount}();

        vm.warp(block.timestamp + timw);
        uint256 balance = rebaseToken.balanceOf(User);

        vm.deal(Owner, balance - deposittedAmount);
        vm.prank(Owner);
        addrewardsTovault(balance - deposittedAmount);

        vm.prank(User);
        vault.redeem(type(uint256).max);

        uint256 EthBlance = address(User).balance;

        assertEq(balance, EthBlance);
        assertGt(EthBlance, deposittedAmount);

        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanBalance() public {
        // deposit funds
        vm.startPrank(User);
        vm.deal(User, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        vm.expectRevert();
        vault.redeem(SEND_VALUE + 1);
        vm.stopPrank();
    }

    function testCannotMintAndBurn() public {
        vm.startPrank(User);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(User, 100, rebaseToken.getGlobslInterstRate());
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.burn(User, 100);
    }

    function testTransfer(uint256 amount, uint256 sendingAmount) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        sendingAmount = bound(sendingAmount, 1e5, amount - 1e5);

        vm.deal(User, amount);
        vm.prank(User);
        vault.deposit{value: amount}();

        address user2 = makeAddr("User2");
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        uint256 userBalance = rebaseToken.balanceOf(User);
        assertEq(0, user2Balance);
        assertEq(amount, userBalance);

        vm.prank(Owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(User);
        rebaseToken.transfer(user2, sendingAmount);
        uint256 userAftet = rebaseToken.balanceOf(User);
        uint256 user2after = rebaseToken.balanceOf(user2);
        assertEq(userAftet, userBalance - sendingAmount);
        assertEq(user2after, sendingAmount);
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, 1e3, type(uint96).max);
        vm.deal(User, amount);
        vm.prank(User);
        vault.deposit{value: amount}();
    }

    function testCannotSetInterestRate(uint256 newRate) public {
        vm.prank(User);
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebaseToken.setInterestRate(newRate);
    }

    function testSetInterestRate(uint256 newInterestRate) public {
        // bound the interest rate to be less than the current interest rate
        newInterestRate = bound(newInterestRate, 0, rebaseToken.getGlobslInterstRate() - 1);
        // Update the interest rate
        vm.startPrank(Owner);
        rebaseToken.setInterestRate(newInterestRate);
        uint256 interestRate = rebaseToken.getGlobslInterstRate();
        assertEq(interestRate, newInterestRate);
        vm.stopPrank();

        // check that if someone deposits, this is their new interest rate
        vm.startPrank(User);
        vm.deal(User, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        uint256 userInterestRate = rebaseToken.getuserInterestRate(User);
        vm.stopPrank();
        assertEq(userInterestRate, newInterestRate);
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getGlobslInterstRate();
        newInterestRate = bound(newInterestRate, initialInterestRate + 1, type(uint96).max);
        vm.prank(Owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken_canOnlyDecreaseTheRate.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getGlobslInterstRate(), initialInterestRate);
    }

    function testGetPrincipleAmount() public {
        uint256 amount = 1e5;
        vm.deal(User, amount);
        vm.prank(User);
        vault.deposit{value: amount}();
        uint256 principleAmount = rebaseToken.PrincipalBalanceO(User);
        assertEq(principleAmount, amount);

        // check that the principle amount is the same after some time has passed
        vm.warp(block.timestamp + 1 days);
        uint256 principleAmountAfterWarp = rebaseToken.PrincipalBalanceO(User);
        assertEq(principleAmountAfterWarp, amount);
    }
}
