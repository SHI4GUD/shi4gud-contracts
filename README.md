<p align="center">
  <a href="https://shi4gud.com" target="_blank">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="logos/shi4gud-light.svg">
      <source media="(prefers-color-scheme: light)" srcset="logos/shi4gud-dark.svg">
      <img alt="SHI4GUD Logo" src="logos/shi4gud-dark.svg" width="250">
    </picture>
  </a>
</p>

<h1 align="center">SHI4GUD Smart Contracts</h1>

<p align="center">
  <a href="https://docs.soliditylang.org/" target="_blank"><img src="https://img.shields.io/badge/Solidity-0.7.6%20%2F%200.8.16-363636?style=flat&logo=solidity" alt="Solidity"></a>
  <a href="https://github.com/OpenZeppelin/openzeppelin-contracts" target="_blank"><img src="https://img.shields.io/badge/OpenZeppelin-4.x-4E5EE4?style=flat" alt="OpenZeppelin"></a>
  <a href="https://uniswap.org" target="_blank"><img src="https://img.shields.io/badge/Uniswap-V2%20%2F%20V3-FF007A?style=flat&logo=uniswap&logoColor=white" alt="Uniswap"></a>
  <a href="https://github.com/endaoment" target="_blank"><img src="https://img.shields.io/badge/Endaoment-Integration-00C853?style=flat" alt="Endaoment"></a>
</p>

<p align="center">
  Open source smart contracts for the SHI4GUD protocol.
  <br />
  <a href="https://docs.shi4gud.com"><strong>Explore the docs »</strong></a>
  <br />
  <br />
</p>

---

## About

Open source smart contracts powering the SHI4GUD Burn Bank protocol. These contracts implement token staking, consensus-based governance, dynamic token burning, and charitable donations.

For detailed information about the SHI4GUD ecosystem, visit the [dApp repository](https://github.com/shi4gud/shi4gud-dapp) or the [official documentation](https://docs.shi4gud.com).

## Contracts

### Ktv2.sol (Solidity 0.8.16)
Core protocol contract implementing:
- Token staking with dynamic burn mechanics
- Decentralized governance through off-chain nodes
- Consensus-based reward distribution
- Epoch-based voting system

### Ktv2Factory.sol (Solidity 0.8.16)
Factory contract for deploying new Ktv2 instances with custom parameters.

### TokenPrice.sol (Solidity 0.7.6)
Price oracle supporting both Uniswap V2 and V3 pools.

## Key Features

- **Consensus Governance** - Multiple OC nodes must agree on all reward distributions
- **Dynamic Token Burns** - Burn amount adjusts based on donation size and token price
- **Price Oracle Integration** - Real-time pricing from Uniswap V2/V3
- **Permissionless Deployment** - Factory pattern for creating multiple instances

## Dependencies

This project leverages battle-tested, audited smart contract libraries:

### OpenZeppelin Contracts
The SHI4GUD protocol uses [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) contracts for secure, audited implementations of access control (Ownable), ERC20 token interfaces, and standard contract patterns.

🔗 **Visit [OpenZeppelin's GitHub](https://github.com/OpenZeppelin/openzeppelin-contracts) to review their open-source, audited contracts.**

### Endaoment Integration
The SHI4GUD dApp integrates with [Endaoment](https://endaoment.org) contracts for on-chain charitable donations and donor-advised fund management. Endaoment provides the infrastructure for transparent, blockchain-based philanthropy.

🔗 **Learn more at [Endaoment's GitHub](https://github.com/endaoment).**

### Uniswap Integration
The SHI4GUD protocol uses [Uniswap](https://uniswap.org) V2 and V3 core contracts for price oracle functionality. The TokenPrice contract reads directly from Uniswap liquidity pools to get real-time, on-chain token pricing.

🔗 **Uniswap V3 Core**: [github.com/Uniswap/v3-core](https://github.com/Uniswap/v3-core)  
🔗 **Uniswap V2 Core**: [github.com/Uniswap/v2-core](https://github.com/Uniswap/v2-core)

## Official Addresses
For official deployment addresses, visit the [documentation](https://docs.shi4gud.com/official-deployments-addresses/).

## Links

*   📝 **Docs**: [docs.shi4gud.com](https://docs.shi4gud.com)
*   🌐 **Website**: [shi4gud.com](https://shi4gud.com)
*   🚀 **dApp**: [app.shi4gud.com](https://app.shi4gud.com)

## Related Repositories

- **dApp**: [`shi4gud/shi4gud-dapp`](https://github.com/shi4gud/shi4gud-dapp)
- **Node**: [`shi4gud/shi4gud-node`](https://github.com/shi4gud/shi4gud-node)