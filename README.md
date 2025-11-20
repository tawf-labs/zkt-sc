# ZKT Smart Contracts

Zero Knowledge (ZK) Technology Smart Contracts built with Foundry.

## Overview

This project contains smart contracts for ZK-related functionality, developed using the Foundry toolkit for Ethereum application development.

## Project Structure

```
├── sc/                     # Smart contracts directory
│   ├── src/               # Contract source files
│   │   └── Counter.sol    # Example Counter contract
│   ├── test/              # Test files
│   ├── script/            # Deployment scripts
│   ├── lib/               # Foundry libraries
│   └── foundry.toml       # Foundry configuration
└── README.md              # This file
```

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Git

## Getting Started

1. Clone the repository:
```bash
git clone <repository-url>
cd zkt-sc
```

2. Navigate to the smart contracts directory:
```bash
cd sc
```

3. Install dependencies:
```bash
forge install
```

## Available Commands

### Build

Compile the smart contracts:
```bash
forge build
```

### Run Tests

Execute the test suite:
```bash
forge test
```

### Format Code

Format Solidity code:
```bash
forge fmt
```

### Gas Snapshots

Generate gas usage snapshots:
```bash
forge snapshot
```

### Local Development

Start a local Ethereum node:
```bash
anvil
```

### Deployment

Deploy contracts using the deployment script:
```bash
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Contract Interaction

Interact with contracts using Cast:
```bash
cast <subcommand>
```

## Getting Help

For more information about Foundry commands:
```bash
forge --help
anvil --help
cast --help
```

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## License

UNLICENSED
