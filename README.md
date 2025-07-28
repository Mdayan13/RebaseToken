# 🔁 RebaseToken with CCIP Integration

**RebaseToken** is an ERC20-compatible **elastic supply** token (rebase mechanism) designed to interact with **Chainlink CCIP** for **cross-chain transfers**. This project enables dynamic token supply adjustment while securely sending and receiving tokens across multiple EVM-compatible blockchains.

---

## ✨ Features

- 🪙 **Rebase Logic** — Token supply can dynamically expand or contract via `rebase()` function.
- 🌐 **Cross-Chain Transfers** — Built-in support for **Chainlink CCIP** to send tokens to other chains.
- 🔒 **Access Control** — Rebase and CCIP functions gated by roles or ownership.
- 🧪 Testnet ready — Supports local simulation and CCIP testnet environments.

---

## 📦 Tech Stack

- Solidity ^0.8.x
- Chainlink CCIP (Testnet & Local Simulator Support)
- Foundry (for local dev and testing)
- Ethereum-compatible chains (Avalanche, Polygon, Arbitrum, etc.)

---

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (if using frontend or scripting)
- Testnet ETH & LINK for CCIP operations

---

## 🛠 Deployment

```bash
forge build
forge script script/Deploy.s.sol:DeployRebaseToken --broadcast --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY>
