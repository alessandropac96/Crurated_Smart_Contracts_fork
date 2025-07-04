// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BatchOptimization} from "./BatchOptimization.s.sol";
import {Crurated} from "../src/Crurated.sol";

/**
 * @title MigrateGasAnalysis
 * @notice Standalone script for analyzing migrate operation gas costs
 * @dev Can be run independently with environment variables or prompts for missing values
 */
contract MigrateGasAnalysis is Script {
    function run() external {
        console.log("=== Migrate Gas Analysis ===");
        
        // Try to get environment variables, with fallback handling
        address proxyAddress = _getProxyAddress();
        if (proxyAddress == address(0)) return;
        
        address adminAddress = _getAdminAddress();
        if (adminAddress == address(0)) return;
        
        console.log("Proxy Contract:", proxyAddress);
        console.log("Admin Address:", adminAddress);
        
        // Initialize optimizer
        BatchOptimization optimizer = new BatchOptimization();
        
        try optimizer.initialize(proxyAddress, adminAddress, 0) {
            console.log("[OK] Optimizer initialized successfully");
        } catch {
            console.log("[ERROR] Failed to initialize optimizer");
            console.log("Please check that the proxy address is correct and the contract is deployed");
            return;
        }
        
        // Run analysis with different batch sizes and status counts
        console.log("\n--- Running Migrate Gas Analysis ---");
        
        uint256[] memory batchSizes = new uint256[](3);
        batchSizes[0] = 10;
        batchSizes[1] = 20;
        batchSizes[2] = 30;
        
        uint256[] memory statusCounts = new uint256[](3);
        statusCounts[0] = 2;
        statusCounts[1] = 3;
        statusCounts[2] = 5;
        
        for (uint256 i = 0; i < batchSizes.length; i++) {
            for (uint256 j = 0; j < statusCounts.length; j++) {
                uint256 maxBatchSize = batchSizes[i];
                uint256 statusCount = statusCounts[j];
                
                console.log("Testing batch size with statuses");
                console.log("Batch size:", maxBatchSize);
                console.log("Status count:", statusCount);
                
                try optimizer.analyzeMigrateGas(maxBatchSize, statusCount) returns (BatchOptimization.GasAnalysis memory analysis) {
                    console.log("[OK] Analysis completed:");
                    console.log("  Base gas (1 migration):", analysis.baseGas);
                    console.log("  Gas per additional migration:", analysis.perItemGas);
                    console.log("  Recommended max batch size:", analysis.maxBatchSize);
                    console.log("  Total gas for max batch:", analysis.totalGas);
                    console.log("  Average gas per migration:", analysis.averageGasPerItem);
                    
                    // Calculate gas per status
                    uint256 gasPerStatus = analysis.averageGasPerItem / statusCount;
                    console.log("  Approximate gas per status:", gasPerStatus);
                    
                    // Calculate efficiency vs single operations
                    uint256 efficiency = (analysis.baseGas * 100) / analysis.averageGasPerItem;
                                         console.log("  Batching efficiency (%):", efficiency);
                } catch {
                    console.log("[ERROR] Analysis failed");
                 console.log("Batch size:", maxBatchSize);
                 console.log("Status count:", statusCount);
                }
            }
        }
        
        console.log("\n--- Gas Cost Scaling Analysis ---");
        console.log("Testing how gas costs scale with status count...");
        
        uint256 fixedBatchSize = 10;
        for (uint256 statusCount = 1; statusCount <= 10; statusCount++) {
            try optimizer.analyzeMigrateGas(fixedBatchSize, statusCount) returns (BatchOptimization.GasAnalysis memory analysis) {
                                     console.log("Status count:", statusCount);
                     console.log("Average gas:", analysis.averageGasPerItem);
            } catch {
                                 console.log("[ERROR] Failed with status count:", statusCount);
            }
        }
        
        console.log("\n=== Analysis Complete ===");
        console.log("[INFO] Key insights:");
        console.log("- More statuses = higher gas costs per migration");
        console.log("- Larger batches = better efficiency up to gas limit");
        console.log("- Use recommended batch sizes for your specific status patterns");
    }
    
    function _getProxyAddress() internal view returns (address) {
        try vm.envAddress("PROXY_ADDRESS") returns (address addr) {
            return addr;
        } catch {
            console.log("[ERROR] PROXY_ADDRESS environment variable not set");
            console.log("Please set it with: export PROXY_ADDRESS=0x...");
            console.log("Or deploy contracts first with: ./batch_optimize.sh deploy-local");
            return address(0);
        }
    }
    
    function _getAdminAddress() internal view returns (address) {
        try vm.envAddress("ADMIN") returns (address addr) {
            return addr;
        } catch {
            // Try to use a default development address
            console.log("[WARNING]  ADMIN environment variable not set");
            console.log("Using default development address (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)");
            console.log("For custom admin, set: export ADMIN=0x...");
            return 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default anvil address
        }
    }
}