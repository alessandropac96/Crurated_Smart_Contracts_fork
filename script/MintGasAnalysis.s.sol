// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BatchOptimization} from "./BatchOptimization.s.sol";
import {Crurated} from "../src/Crurated.sol";

/**
 * @title MintGasAnalysis
 * @notice Standalone script for analyzing mint operation gas costs
 * @dev Can be run independently with environment variables or prompts for missing values
 */
contract MintGasAnalysis is Script {
    function run() external {
        console.log("=== Mint Gas Analysis ===");
        
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
        
        // Run analysis with different batch sizes
        console.log("\n--- Running Mint Gas Analysis ---");
        
        uint256[] memory testSizes = new uint256[](4);
        testSizes[0] = 10;
        testSizes[1] = 25;
        testSizes[2] = 50;
        testSizes[3] = 100;
        
        for (uint256 i = 0; i < testSizes.length; i++) {
            uint256 maxTestSize = testSizes[i];
            console.log("Testing with max batch size:", maxTestSize);
            
            try optimizer.analyzeMintGas(maxTestSize) returns (BatchOptimization.GasAnalysis memory analysis) {
                console.log("[OK] Analysis completed:");
                console.log("  Base gas (1 mint):", analysis.baseGas);
                console.log("  Gas per additional mint:", analysis.perItemGas);
                console.log("  Recommended max batch size:", analysis.maxBatchSize);
                console.log("  Total gas for max batch:", analysis.totalGas);
                console.log("  Average gas per mint:", analysis.averageGasPerItem);
                
                // Calculate efficiency
                uint256 efficiency = (analysis.baseGas * 100) / analysis.averageGasPerItem;
                console.log("  Batching efficiency (%):", efficiency);
            } catch {
                console.log("[ERROR] Analysis failed for batch size:", maxTestSize);
            }
        }
        
        console.log("\n=== Analysis Complete ===");
        console.log("Use the recommended batch sizes for optimal gas efficiency!");
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