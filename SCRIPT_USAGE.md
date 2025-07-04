# Batch Optimization Scripts - Usage Guide

## Overview

The batch optimization system provides multiple ways to analyze and optimize gas usage for Crurated contract operations. This guide explains how to use each script effectively.

## Quick Start

### 1. Easy Setup (Recommended)
Use the automated script that handles everything:

```bash
# Deploy contracts locally and run analysis
./batch_optimize.sh deploy-local
./batch_optimize.sh demo
```

### 2. Manual Setup
If you prefer to set environment variables manually:

```bash
# Set your environment variables
export PROXY_ADDRESS=0x...  # Your deployed Crurated proxy contract
export ADMIN=0x...          # Admin address for operations
export OWNER=0x...          # Owner address (optional)

# Then run any script
forge script script/MintGasAnalysis.s.sol:MintGasAnalysis --rpc-url http://localhost:8545
```

## Available Scripts

### 📊 **Analysis Scripts** (Standalone - Easy to Use)

#### 1. Mint Gas Analysis
```bash
forge script script/MintGasAnalysis.s.sol:MintGasAnalysis --rpc-url http://localhost:8545
```
- **What it does**: Analyzes gas costs for mint operations
- **Requirements**: `PROXY_ADDRESS` (required), `ADMIN` (uses default if missing)
- **Output**: Gas costs, optimal batch sizes, efficiency metrics

#### 2. Migrate Gas Analysis
```bash
forge script script/MigrateGasAnalysis.s.sol:MigrateGasAnalysis --rpc-url http://localhost:8545
```
- **What it does**: Analyzes gas costs for migrate operations with status history
- **Requirements**: `PROXY_ADDRESS` (required), `ADMIN` (uses default if missing)
- **Output**: Gas costs for different status counts, optimal batch sizes

### ⚙️ **Advanced Scripts** (Full-Featured)

#### 3. BatchOptimization (Core Engine)
```bash
forge script script/BatchOptimization.s.sol:BatchOptimization --rpc-url http://localhost:8545
```
- **What it does**: Core optimization engine with all functions
- **Requirements**: `PROXY_ADDRESS`, `ADMIN` (both required)
- **Output**: Basic analysis and helpful usage instructions

#### 4. BatchOptimizationRunner (Full Demo)
```bash
forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner --rpc-url http://localhost:8545
```
- **What it does**: Complete demonstration of all features
- **Requirements**: `PROXY_ADDRESS`, `ADMIN`, `OWNER` (all required)
- **Output**: Comprehensive demo with sample operations

### 🛠️ **CLI Tools** (Automated)

#### 5. Batch Optimize Shell Script
```bash
./batch_optimize.sh [command]
```

**Available commands:**
- `deploy-local` - Deploy contracts locally for testing
- `analyze-mint` - Quick mint gas analysis
- `analyze-migrate` - Quick migrate gas analysis  
- `analyze-costs` - Incremental cost analysis
- `execute-mints` - Execute sample mint operations
- `demo` - Full demonstration
- `help` - Show usage instructions

## Environment Variables

### Required Variables
- **`PROXY_ADDRESS`**: Address of your deployed Crurated proxy contract
- **`ADMIN`**: Address with admin permissions on the contract

### Optional Variables  
- **`OWNER`**: Contract owner address (needed for some advanced operations)
- **`RPC_URL`**: Custom RPC endpoint (defaults to `http://localhost:8545`)

### Setting Variables

**Option 1: Export manually**
```bash
export PROXY_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

**Option 2: Use .env file**
```bash
echo "PROXY_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512" > .env
echo "ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" >> .env
source .env
```

**Option 3: Use batch_optimize.sh (automatic)**
```bash
./batch_optimize.sh deploy-local  # Creates .env.local automatically
```

## Error Handling

### Common Issues and Solutions

#### ❌ "Environment variable not set"
**Problem**: Missing required environment variables
**Solution**: 
```bash
# Check what's missing
env | grep -E "(PROXY_ADDRESS|ADMIN|OWNER)"

# Set missing variables
export PROXY_ADDRESS=0x...
export ADMIN=0x...
```

#### ❌ "Failed to initialize optimizer"
**Problem**: Wrong proxy address or contract not deployed
**Solution**:
```bash
# Check if contract exists
cast code $PROXY_ADDRESS --rpc-url http://localhost:8545

# If empty, deploy first
./batch_optimize.sh deploy-local
```

#### ❌ "Caller is not admin"
**Problem**: Wrong admin address or permissions
**Solution**:
```bash
# Check current admin
cast call $PROXY_ADDRESS "admin()" --rpc-url http://localhost:8545

# Use the correct admin address
export ADMIN=0x...
```

## Usage Examples

### Example 1: Quick Analysis
```bash
# Deploy locally (if needed)
./batch_optimize.sh deploy-local

# Run mint analysis
forge script script/MintGasAnalysis.s.sol:MintGasAnalysis --rpc-url http://localhost:8545

# Expected output:
# === Mint Gas Analysis ===
# ✅ Analysis completed:
#   Base gas (1 mint): 125000
#   Gas per additional mint: 45000
#   Recommended max batch size: 25
#   Batching efficiency: 75% of single operation
```

### Example 2: Custom Environment
```bash
# Set your custom contract
export PROXY_ADDRESS=0x1234567890123456789012345678901234567890
export ADMIN=0x9876543210987654321098765432109876543210

# Run analysis
forge script script/MintGasAnalysis.s.sol:MintGasAnalysis --rpc-url https://api.avax.network/ext/bc/C/rpc
```

### Example 3: Full Workflow
```bash
# 1. Deploy and setup
./batch_optimize.sh deploy-local

# 2. Analyze mint operations
./batch_optimize.sh analyze-mint

# 3. Analyze migrate operations  
./batch_optimize.sh analyze-migrate

# 4. Run full demonstration
./batch_optimize.sh demo

# 5. Execute sample operations
./batch_optimize.sh execute-mints
```

## Script Comparison

| Script | Complexity | Setup Required | Best For |
|--------|------------|---------------|----------|
| `MintGasAnalysis.s.sol` | Simple | Minimal | Quick mint analysis |
| `MigrateGasAnalysis.s.sol` | Simple | Minimal | Quick migrate analysis |
| `BatchOptimization.s.sol` | Advanced | Full setup | Custom operations |
| `BatchOptimizationRunner.s.sol` | Advanced | Full setup | Complete testing |
| `batch_optimize.sh` | Automated | None | Everything |

## Advanced Usage

### Custom Gas Analysis
```solidity
// In your own script
BatchOptimization optimizer = new BatchOptimization();
optimizer.initialize(proxyAddress, adminAddress, 0);

// Analyze specific scenarios
GasAnalysis memory analysis = optimizer.analyzeMintGas(50);
uint256 additionalCost = optimizer.calculateAdditionalGasCost(10, 5, "mint", 0);
```

### Batch Execution
```solidity
// Prepare operations
MintOperation[] memory ops = new MintOperation[](100);
// ... fill operations

// Execute with optimal batching
uint256[] memory tokenIds = optimizer.executeBatchedMints(ops);
```

## Performance Tips

1. **Start with small batch sizes** - Test with 10-20 items first
2. **Monitor gas prices** - Adjust batch sizes based on network conditions  
3. **Use appropriate analysis** - Different operations have different optimal sizes
4. **Test with real data** - Use your actual CIDs and status patterns
5. **Regular analysis** - Gas costs change, re-analyze periodically

## Troubleshooting

### Missing Dependencies
```bash
# Install Foundry if needed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build contracts
forge build
```

### Network Issues
```bash
# Test connection
cast block-number --rpc-url http://localhost:8545

# Start local node if needed
anvil --host 0.0.0.0 --port 8545
```

### Permission Issues
```bash
# Make scripts executable
chmod +x batch_optimize.sh

# Check file permissions
ls -la script/*.s.sol
```

## Support

If you encounter issues:

1. Check this guide first
2. Verify environment variables are set correctly
3. Ensure contracts are deployed and accessible
4. Test with the simple analysis scripts first
5. Use `./batch_optimize.sh deploy-local` for a clean setup

For detailed technical information, see:
- `BATCH_OPTIMIZATION.md` - Technical documentation
- `BATCH_OPTIMIZATION_SUMMARY.md` - Implementation overview
- `BATCH_OPTIMIZATION_TEST_RESULTS.md` - Test verification