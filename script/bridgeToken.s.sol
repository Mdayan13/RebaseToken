// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
//  struct EVM2AnyMessage {
//     bytes receiver; // abi.encode(receiver address) for dest EVM chains
//     bytes data; // Data payload
//     EVMTokenAmount[] tokenAmounts; // Token transfers
//     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
//     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
//   }

contract BridgeTokenScript is Script {
    function run(
        address receiver,
        uint64 destinationChainSelector,
        address tokenTosendAddres,
        uint256 amountTosends,
        address linkTokenAddress,
        address routerAddress
    ) public {
        vm.startBroadcast();
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenTosendAddres, amount: amountTosends});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        uint256 fee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, fee);
        IERC20(tokenTosendAddres).approve(routerAddress, amountTosends);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);

        vm.stopBroadcast();
    }
}
