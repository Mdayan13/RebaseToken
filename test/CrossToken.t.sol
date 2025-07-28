// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interaction/IRebaseToken.sol";
import {RebaseTokenPool} from "../src/tokenPool.sol";
import {Vault} from "../src/vault.sol";
import {CCIPLocalSimulatorFork, Register} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRebaseToken} from "../src/interaction/IRebaseToken.sol";
import {RegistryModuleOwnerCustom} from
    "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {IRouterClient} from "lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {TokenAdminRegistry} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

import {Test, console} from "lib/forge-std/src/Test.sol";

contract CrossChainTest is Test {
    address public owner = makeAddr("owner");
    address public user = makeAddr("alice");
    uint256 public sendValue = 1e5;
    uint256 public sepoliaFork;
    uint256 public arbsepoliaFork;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    RebaseToken public sepoliaToken;
    RebaseToken public arbitrumToken;
    Vault public vault;
    RebaseTokenPool public sepoliapool;
    RebaseTokenPool public arbpool;

    Register.NetworkDetails public sepoliaNetworkDetails;
    Register.NetworkDetails public arbitrumNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("eth");
        arbsepoliaFork = vm.createFork("arb");
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.startPrank(owner);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliapool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliapool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliapool)
        );
        vm.stopPrank();
        vm.selectFork(arbsepoliaFork);
        vm.startPrank(owner);
        arbitrumNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbitrumToken = new RebaseToken();
        arbpool = new RebaseTokenPool(
            IERC20(address(arbitrumToken)),
            new address[](0),
            arbitrumNetworkDetails.rmnProxyAddress,
            arbitrumNetworkDetails.routerAddress
        );
        console.log("yeah here");
        arbitrumToken.grantMintAndBurnRole(address(arbpool));
        RegistryModuleOwnerCustom(arbitrumNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbitrumToken)
        );
        TokenAdminRegistry(arbitrumNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbitrumToken));
        TokenAdminRegistry(arbitrumNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbitrumToken), address(arbpool)
        );
        vm.stopPrank();
        configureNetwork(
            sepoliaFork, sepoliapool, arbpool, IRebaseToken(address(arbitrumToken)), arbitrumNetworkDetails
        );
        console.log("fuck");
        configureNetwork(
            arbsepoliaFork, arbpool, sepoliapool, IRebaseToken(address(sepoliaToken)), sepoliaNetworkDetails
        );
    }

    function configureNetwork(
        uint256 forkId,
        TokenPool localPool,
        TokenPool _remotePoolAddress,
        IRebaseToken _remoteTokenAddress,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(forkId);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chainId = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(address(_remotePoolAddress));
        chainId[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddresses[0],
            remoteTokenAddress: abi.encode(address(_remoteTokenAddress)),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });

        localPool.applyChainUpdates(chainId);
    }

    function bridgeToken(
        uint256 amountTobridge,
        uint256 localfork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localfork);
        vm.startPrank(user);
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount =
            Client.EVMTokenAmount({token: address(localToken), amount: amountTobridge});
        tokenToSendDetails[0] = tokenAmount;
        // Approve the router to burn tokens on users behalf
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountTobridge);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenToSendDetails,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: ""
        });
        vm.stopPrank();

        console.log("111");

        ccipLocalSimulatorFork.requestLinkFromFaucet(
            user, IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        );
        vm.startPrank(user);
        console.log("222");

        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        );

        console.log("333");
        uint256 localBalanceBefore = localToken.balanceOf(user);

        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountTobridge);
        console.log("444");

        vm.stopPrank();

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 1 hours);

        uint256 remoteBeforeBalance = IERC20(address(remoteToken)).balanceOf(user);
        console.log("Remote balance before bridge: %d", remoteBeforeBalance);
        vm.selectFork(sepoliaFork);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBeforeBalance + amountTobridge);
    }

    function testAllBridge() public {
        vm.selectFork(sepoliaFork);

        vm.deal(user, sendValue);

        vm.startPrank(user);
        Vault(payable(address(vault))).deposit{value: sendValue}();

        uint256 startBalance = IERC20(address(sepoliaToken)).balanceOf(user);
        assertEq(startBalance, sendValue);
        bridgeToken(
            sendValue,
            sepoliaFork,
            arbsepoliaFork,
            sepoliaNetworkDetails,
            arbitrumNetworkDetails,
            sepoliaToken,
            arbitrumToken
        );
    }
}
