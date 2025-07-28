// SPDX-License-Identifier: mIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/vault.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol";
import {RegistryModuleOwnerCustom} from
    "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRebaseToken} from "../src/interaction/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/tokenPool.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        token = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(address(token)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );

        vm.stopBroadcast();
    }
}

contract Setpermissions is Script {
    function grantRole(address token, address pool) public {
        vm.startBroadcast();
        IRebaseToken(token).grantMintAndBurnRole(address(pool));
        vm.stopBroadcast();
    }

    function setAdmin(address token, address pool) public {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        RegistryModuleOwnerCustom(networkDetails.tokenAdminRegistryAddress).registerAdminViaGetCCIPAdmin(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(token), address(pool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
