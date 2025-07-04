# Crurated Batch Optimization System

## Overview

The Batch Optimization System provides advanced gas analysis and optimal batching strategies for Crurated contract operations. It calculates the maximum batch sizes that can fit within block gas limits, analyzes incremental gas costs, and automatically executes operations in optimally-sized batches to minimize gas costs and transaction time.

## Features

### 🔍 Gas Analysis
- **Mint Operations**: Analyze gas usage patterns for minting operations
- **Migrate Operations**: Analyze gas usage for migration with status history
- **Incremental Costs**: Calculate gas costs for adding items to existing batches
- **Block Limit Calculation**: Determine maximum batch sizes before hitting gas limits

### ⚡ Optimal Batching
- **Automatic Batch Sizing**: Calculate optimal batch sizes based on gas limits
- **Smart Execution**: Execute large sets of operations in optimally-sized batches
- **Gas Estimation**: Provide accurate gas estimates for batch operations
- **Safety Margins**: Built-in safety margins to avoid gas limit failures

### 📊 Reporting
- **Detailed Analysis**: Comprehensive gas usage reports
- **Cost Comparisons**: Compare costs of different batch sizes
- **Optimization Recommendations**: Suggest optimal batch strategies

## Architecture

### Core Components

1. **BatchOptimization.s.sol**: Main optimization contract with gas analysis and batching logic
2. **BatchOptimizationRunner.s.sol**: Demonstration script with real-world examples
3. **batch_optimize.sh**: CLI tool for easy access to optimization features

### Key Structs

```solidity
struct MintOperation {
    string cid;         // IPFS content identifier
    uint256 amount;     // Amount to mint
}

struct MigrateOperation {
    string cid;                      // IPFS content identifier
    uint256 amount;                  // Amount to mint
    CruratedBase.Status[] statuses;  // Historical status data
}

struct GasAnalysis {
    uint256 baseGas;           // Base gas for single operation
    uint256 perItemGas;        // Additional gas per extra item
    uint256 totalGas;          // Total gas for max batch
    uint256 maxBatchSize;      // Maximum safe batch size
    uint256 averageGasPerItem; // Average gas per item in max batch
}

struct BatchResult {
    uint256 batchCount;        // Number of batches needed
    uint256[] batchSizes;      // Size of each batch
    uint256 totalGasEstimate;  // Estimated total gas
    uint256 totalOperations;   // Total operations processed
}
```

## Usage Guide

### Prerequisites

1. **Deployed Crurated Contract**: You need a deployed Crurated proxy contract
2. **Environment Setup**: Required environment variables must be set
3. **Foundry**: Forge and Anvil for script execution

### Environment Variables

Create a `.env` file with:

```bash
# Required for all operations
PROXY_ADDRESS=0x...          # Address of deployed Crurated proxy
ADMIN=0x...                  # Admin address (can call mint/migrate)
OWNER=0x...                  # Owner address

# Optional
RPC_URL=http://localhost:8545      # RPC endpoint
BLOCK_GAS_LIMIT=30000000          # Custom gas limit (optional)
```

### Quick Start

#### 1. Local Testing Setup

```bash
# Deploy contracts locally and setup environment
./batch_optimize.sh deploy-local

# Source the generated environment
source .env.local
```

#### 2. Gas Analysis

```bash
# Analyze mint operation gas usage
./batch_optimize.sh analyze-mint

# Analyze migrate operation gas usage  
./batch_optimize.sh analyze-migrate

# Analyze incremental gas costs
./batch_optimize.sh analyze-costs
```

#### 3. Execute Optimized Batches

```bash
# Execute sample mint operations with optimal batching
./batch_optimize.sh execute-mints

# Execute sample migrate operations with optimal batching
./batch_optimize.sh execute-migrations

# Run full demonstration
./batch_optimize.sh demo
```

### Using the Forge Scripts Directly

#### Gas Analysis

```bash
# Analyze mint gas patterns
forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
    --rpc-url http://localhost:8545 \
    --sig "analyzeMintGas()"

# Analyze migrate gas patterns
forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
    --rpc-url http://localhost:8545 \
    --sig "analyzeMigrateGas()"
```

#### Sample Executions

```bash
# Execute optimized mint batches
forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
    --rpc-url http://localhost:8545 \
    --sig "executeSampleMints()" \
    --broadcast

# Execute optimized migrate batches  
forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
    --rpc-url http://localhost:8545 \
    --sig "executeSampleMigrations()" \
    --broadcast
```

## Advanced Usage

### Custom Batch Operations

You can create custom batch operations by directly using the BatchOptimization contract:

```solidity
// Initialize the optimizer
BatchOptimization optimizer = new BatchOptimization();
optimizer.initialize(proxyAddress, adminAddress, 0);

// Create your operations
BatchOptimization.MintOperation[] memory operations = new BatchOptimization.MintOperation[](100);
// ... populate operations ...

// Calculate optimal batching
BatchOptimization.BatchResult memory result = optimizer.calculateMintBatching(operations);

// Execute with optimal batching
uint256[] memory tokenIds = optimizer.executeBatchedMints(operations);
```

### Gas Cost Analysis

```solidity
// Analyze cost of adding items to a batch
uint256 additionalGas = optimizer.calculateAdditionalGasCost(
    5,        // current batch size
    10,       // additional items
    "mint",   // operation type
    0         // status count (for migrates)
);
```

### Custom Gas Limits

```solidity
// Initialize with custom gas limit
optimizer.initialize(proxyAddress, adminAddress, 25_000_000); // 25M gas limit
```

## Gas Optimization Strategies

### Mint Operations

**Typical Gas Usage:**
- Base cost: ~150,000 gas for first item
- Additional items: ~50,000 gas each
- Optimal batch size: 400-500 items (depending on gas limit)

**Recommendations:**
- Use batch sizes of 400+ for maximum efficiency
- Monitor gas prices and adjust batch sizes accordingly
- Consider splitting very large operations across multiple blocks

### Migrate Operations

**Typical Gas Usage:**
- Base cost: ~200,000 gas for first item
- Additional items: ~80,000 gas each (+ status processing)
- Status overhead: ~10,000 gas per status entry
- Optimal batch size: 200-300 items (depending on status count)

**Recommendations:**
- Limit status entries to essential history only
- Use smaller batch sizes for migrations with extensive history
- Group migrations by similar status count when possible

## Monitoring and Debugging

### Gas Analysis Output

The system provides detailed logging:

```
=== MINT GAS ANALYSIS ===
Base gas (1 item): 147832
Gas per additional item: 52104  
Max batch size: 478
Total gas for max batch: 25876432
Average gas per item: 54134
```

### Batch Execution Logging

```
=== MINT BATCHING STRATEGY ===
Total operations: 100
Number of batches: 1
Optimal batch size: 478
Total estimated gas: 5357632

Executed mint batch 1 with 100 operations
=== BATCH EXECUTION COMPLETE ===
Total operations executed: 100
Total batches: 1
```

## Error Handling

### Common Issues

1. **Gas Limit Exceeded**: Reduce batch size or increase gas limit
2. **Insufficient Permissions**: Ensure admin address has proper roles
3. **Invalid Operations**: Check CID format and amounts > 0
4. **Status Not Found**: Ensure status types are registered before migration

### Safety Features

- **10% Safety Margin**: Automatic reduction from theoretical max gas
- **Batch Size Caps**: Reasonable limits to prevent excessive gas usage
- **Input Validation**: Comprehensive validation of operation parameters
- **Graceful Degradation**: Fallback to smaller batches if needed

## Performance Tips

### For Large-Scale Operations

1. **Pre-analysis**: Run gas analysis before large batch operations
2. **Incremental Testing**: Test with smaller batches first
3. **Gas Price Monitoring**: Execute during low gas price periods
4. **Parallel Execution**: Use multiple admin accounts for parallel batching
5. **Status Optimization**: Minimize status history for faster migrations

### Cost Optimization

1. **Batch Size Tuning**: Use analysis results to find optimal sizes
2. **Operation Grouping**: Group similar operations together
3. **Gas Limit Awareness**: Monitor network congestion and adjust accordingly
4. **Transaction Timing**: Execute during off-peak hours

## Integration Examples

### Node.js Integration

```javascript
const { spawn } = require('child_process');

// Analyze mint gas usage
const analyzeMint = () => {
    return new Promise((resolve, reject) => {
        const process = spawn('./batch_optimize.sh', ['analyze-mint']);
        
        process.stdout.on('data', (data) => {
            console.log(data.toString());
        });
        
        process.on('close', (code) => {
            if (code === 0) resolve();
            else reject(new Error(`Process exited with code ${code}`));
        });
    });
};

// Execute optimized mints
const executeMints = async () => {
    await analyzeMint();
    // ... create operations data ...
    // Execute via smart contract call
};
```

### Python Integration

```python
import subprocess
import json

def analyze_gas_usage():
    """Analyze gas usage patterns"""
    result = subprocess.run(['./batch_optimize.sh', 'analyze-mint'], 
                          capture_output=True, text=True)
    return result.stdout

def execute_optimized_batches(operations):
    """Execute operations with optimal batching"""
    # Prepare operations data
    # Call batch optimization contract
    pass
```

## Contributing

To extend the batch optimization system:

1. **Add New Operation Types**: Extend the structs and analysis functions
2. **Improve Gas Estimation**: Enhance the gas calculation algorithms
3. **Add Network Support**: Include gas limits for different chains
4. **Performance Optimization**: Optimize batch calculation algorithms

## License

This optimization system is part of the Crurated project and follows the same MIT license.