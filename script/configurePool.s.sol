// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebaseTokenPool} from "../src/tokenPool.sol";
import {Script} from "forge-std/Script.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
// struct ChainUpdate {
//     uint64 remoteChainSelector; // ──╮ Remote chain selector
//     bool allowed; // ────────────────╯ Whether the chain should be enabled
//     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
//     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
//     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
//     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
//   }

contract ConfigurePool is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePoool,
        address remoteToken,
        bool outboundRateLimiterIsEnabled,
        uint128 outboundRateLimiterCapacity,
        uint128 outboundRateLimiterRate,
        bool inboundRateLimiterIsEnabled,
        uint128 inboundRateLimiterCapacity,
        uint128 inboundRateLimiterRate
    ) public {
        bytes[] memory remoteTokenAddresses = new bytes[](1);
        remoteTokenAddresses[0] = abi.encode(remoteToken);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](0);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(address(remotePoool)),
            remoteTokenAddress: remoteTokenAddresses[0],
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }
}
