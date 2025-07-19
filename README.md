# 🌐 Network Deployment Tracker

A smart contract for tracking and managing deployments across multiple blockchain networks** 

[![Clarity](https://img.shields.io/badge/Clarity-Smart%20Contract-purple)](https://clarity-lang.org/)
[![Stacks](https://img.shields.io/badge/Stacks-Blockchain-orange)](https://stacks.co/)

## 📋 Overview

The Network Deployment Tracker is a comprehensive Clarity smart contract that enables developers to track, manage, and monitor their smart contract deployments across multiple blockchain networks. This project teaches multi-network handling patterns and provides a centralized registry for deployment management.

## ✨ Key Features

- 🔗 **Multi-Network Support**: Register and manage multiple blockchain networks
- 📝 **Deployment Tracking**: Create and track deployment records with metadata
- 📊 **Status Management**: Update deployment status (pending, deployed, failed, verified)
- 🏷️ **Tagging System**: Add custom tags to organize deployments
- 📈 **Analytics**: Track deployer statistics and network deployment counts
- ✅ **Verification System**: Mark deployments as verified by contract owner
- 🔍 **Query Interface**: Filter deployments by status, network, or deployer

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic knowledge of Clarity smart contracts

### Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd network-deployment-tracker
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
npm run test
```

## 📖 Usage Guide

### 1. Register Networks 🌍

First, register the networks you want to track deployments on:

```clarity
(contract-call? .networkk-deployment-tracker register-network 
  u1 
  "mainnet" 
  u1 
  "https://api.mainnet.hiro.so" 
  false)

(contract-call? .networkk-deployment-tracker register-network 
  u2 
  "testnet" 
  u2147483648 
  "https://api.testnet.hiro.so" 
  true)
```

### 2. Create Deployment Records 📝

Track a new deployment:

```clarity
(contract-call? .networkk-deployment-tracker create-deployment
  "my-awesome-contract"
  "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.my-contract"
  u1
  "0x1234567890abcdef..."
  u50000
  u1000000
  (list "defi" "nft"))
```

### 3. Update Deployment Status 🔄

```clarity
(contract-call? .networkk-deployment-tracker update-deployment-status u1 "deployed")
```

### 4. Verify Deployments ✅

Contract owner can verify deployments:

```clarity
(contract-call? .networkk-deployment-tracker verify-deployment u1)
```

### 5. Query Deployments 🔍

Get deployment details:

```clarity
(contract-call? .networkk-deployment-tracker get-deployment u1)
```

Get deployer statistics:

```clarity
(contract-call? .networkk-deployment-tracker get-deployer-stats 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 🏗️ Contract Architecture

### Data Structures

- **`deployments`**: Main deployment registry with full metadata
- **`network-registry`**: Registered blockchain networks
- **`deployer-stats`**: Aggregated statistics per deployer
- **`network-deployment-count`**: Deployment counts per network

### Status Types

- `pending` - Deployment initiated but not confirmed
- `deployed` - Successfully deployed and confirmed
- `failed` - Deployment failed
- `verified` - Verified by contract owner

## 🔧 Development

### Running Tests

```bash
# Run all tests
npm run test

# Run tests with coverage
npm run test:report

# Watch for changes
npm run test:watch
```

### Contract Functions

#### Public Functions

| Function | Description |
|----------|-------------|
| `register-network` | Register a new blockchain network |
| `deactivate-network` | Deactivate a network |
| `create-deployment` | Create a new deployment record |
| `update-deployment-status` | Update deployment status |
| `verify-deployment` | Mark deployment as verified |
| `add-deployment-tag` | Add tags to deployment |

#### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-deployment` | Get deployment by ID |
| `get-network` | Get network details |
| `get-deployer-stats` | Get deployer statistics |
| `get-deployments-by-status` | Filter by status |
| `get-deployments-by-network` | Filter by network |
| `get-deployments-by-deployer` | Filter by deployer |

## 📊 Data Models

### Deployment Record

```clarity
{
  contract-name: (string-ascii 64),
  contract-address: (string-ascii 64),
  network-id: uint,
  network-name: (string-ascii 32),
  deployer: principal,
  deployment-hash: (string-ascii 64),
  status: (string-ascii 16),
  gas-used: uint,
  deployment-cost: uint,
  created-at: uint,
  updated-at: uint,
  is-verified: bool,
  tags: (list 5 (string-ascii 32))
}
```

### Network Registry

```clarity
{
  network-name: (string-ascii 32),
  chain-id: uint,
  rpc-endpoint: (string-ascii 128),
  is-testnet: bool,
  is-active: bool
}
```

## 🎯 Learning Objectives

This project teaches:

- ✅ Multi-network blockchain interaction patterns
- ✅ Data modeling for complex tracking systems
- ✅ Access control and authorization patterns
- ✅ State management across multiple entities
- ✅ Query optimization for filtering operations
- ✅ Event tracking and analytics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Useful Links

- [Clarity Documentation](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)
- [Stacks Blockchain](https://stacks.co/)

---

**Happy Deploying!** 🚀✨
