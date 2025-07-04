// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {BatchOptimization} from "./BatchOptimization.s.sol";
import {Crurated} from "../src/Crurated.sol";
import {CruratedBase} from "../src/abstracts/CruratedBase.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title BatchOptimizationRunner
 * @notice Demonstration script showing how to use BatchOptimization for real-world scenarios
 * @dev Provides example workflows for gas analysis and optimized batch execution
 */
contract BatchOptimizationRunner is Script {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    BatchOptimization public optimizer;
    Crurated public proxy;
    address public owner;
    address public admin;

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Run complete demonstration of batch optimization features
     * @dev Requires deployed Crurated contract and environment variables
     */
    function run() external {
        // Load environment variables
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        owner = vm.envAddress("OWNER");
        admin = vm.envAddress("ADMIN");
        
        console2.log("=== BATCH OPTIMIZATION RUNNER ===");
        console2.log("Proxy Address:", proxyAddress);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);
        
        // Initialize contracts
        proxy = Crurated(proxyAddress);
        optimizer = new BatchOptimization();
        optimizer.initialize(proxyAddress, admin, 0); // Use default gas limit
        
        // Setup required status types
        _setupStatusTypes();
        
        // Run demonstrations
        _demonstrateMintOptimization();
        _demonstrateMigrateOptimization();
        _demonstrateGasCostAnalysis();
        
        console2.log("=== DEMONSTRATION COMPLETE ===");
    }

    /**
     * @notice Analyze mint operations gas usage patterns
     */
    function analyzeMintGas() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        admin = vm.envAddress("ADMIN");
        
        optimizer = new BatchOptimization();
        optimizer.initialize(proxyAddress, admin, 0);
        
        console2.log("=== MINT GAS ANALYSIS ===");
        BatchOptimization.GasAnalysis memory analysis = optimizer.analyzeMintGas(100);
        
        console2.log("Results stored in analysis struct");
        console2.log("Recommendation: Use batch size up to", analysis.maxBatchSize, "for optimal gas efficiency");
    }

    /**
     * @notice Analyze migrate operations gas usage patterns
     */
    function analyzeMigrateGas() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        admin = vm.envAddress("ADMIN");
        
        optimizer = new BatchOptimization();
        optimizer.initialize(proxyAddress, admin, 0);
        
        console2.log("=== MIGRATE GAS ANALYSIS ===");
        BatchOptimization.GasAnalysis memory analysis = optimizer.analyzeMigrateGas(50, 3); // 3 status entries per migration
        
        console2.log("Results stored in analysis struct");
        console2.log("Recommendation: Use batch size up to", analysis.maxBatchSize, "for optimal gas efficiency");
    }

    /**
     * @notice Execute sample mint operations using optimal batching
     */
    function executeSampleMints() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        admin = vm.envAddress("ADMIN");
        
        optimizer = new BatchOptimization();
        optimizer.initialize(proxyAddress, admin, 0);
        
        // Create sample mint operations
        BatchOptimization.MintOperation[] memory operations = _createSampleMintOperations(25);
        
        console2.log("=== EXECUTING OPTIMIZED MINT BATCHES ===");
        uint256[] memory tokenIds = optimizer.executeBatchedMints(operations);
        
        console2.log("Successfully minted", tokenIds.length, "tokens");
        console2.log("First token ID:", tokenIds[0]);
        console2.log("Last token ID:", tokenIds[tokenIds.length - 1]);
    }

    /**
     * @notice Execute sample migrate operations using optimal batching
     */
    function executeSampleMigrations() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        admin = vm.envAddress("ADMIN");
        
        optimizer = new BatchOptimization();
        optimizer.initialize(proxyAddress, admin, 0);
        
        // Setup status types first
        vm.startPrank(admin);
        proxy = Crurated(proxyAddress);
        proxy.addStatus("Created");
        proxy.addStatus("Verified"); 
        proxy.addStatus("Certified");
        vm.stopPrank();
        
        // Create sample migrate operations
        BatchOptimization.MigrateOperation[] memory operations = _createSampleMigrateOperations(15);
        
        console2.log("=== EXECUTING OPTIMIZED MIGRATE BATCHES ===");
        uint256[] memory tokenIds = optimizer.executeBatchedMigrations(operations);
        
        console2.log("Successfully migrated", tokenIds.length, "tokens");
        console2.log("First token ID:", tokenIds[0]);
        console2.log("Last token ID:", tokenIds[tokenIds.length - 1]);
    }

    /**
     * @notice Calculate gas costs for different batch size increases
     */
    function analyzeIncrementalGasCosts() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        admin = vm.envAddress("ADMIN");
        
        optimizer = new BatchOptimization();
        optimizer.initialize(proxyAddress, admin, 0);
        
        console2.log("=== INCREMENTAL GAS COST ANALYSIS ===");
        
        // Analyze mint costs
        console2.log("--- MINT OPERATIONS ---");
        uint256 mintGasCost1to5 = optimizer.calculateAdditionalGasCost(1, 4, "mint", 0);
        uint256 mintGasCost5to10 = optimizer.calculateAdditionalGasCost(5, 5, "mint", 0);
        uint256 mintGasCost10to20 = optimizer.calculateAdditionalGasCost(10, 10, "mint", 0);
        
        // Analyze migrate costs
        console2.log("--- MIGRATE OPERATIONS ---");
        uint256 migrateGasCost1to3 = optimizer.calculateAdditionalGasCost(1, 2, "migrate", 2);
        uint256 migrateGasCost3to6 = optimizer.calculateAdditionalGasCost(3, 3, "migrate", 2);
        uint256 migrateGasCost6to10 = optimizer.calculateAdditionalGasCost(6, 4, "migrate", 2);
        
        console2.log("=== COST SUMMARY ===");
        console2.log("Mint 1->5:", mintGasCost1to5, "gas");
        console2.log("Mint 5->10:", mintGasCost5to10, "gas");
        console2.log("Mint 10->20:", mintGasCost10to20, "gas");
        console2.log("Migrate 1->3:", migrateGasCost1to3, "gas");
        console2.log("Migrate 3->6:", migrateGasCost3to6, "gas");
        console2.log("Migrate 6->10:", migrateGasCost6to10, "gas");
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Setup required status types for demonstrations
     */
    function _setupStatusTypes() internal {
        vm.startPrank(admin);
        try proxy.addStatus("Created") {
            console2.log("Added 'Created' status");
        } catch {
            console2.log("'Created' status already exists");
        }
        
        try proxy.addStatus("Verified") {
            console2.log("Added 'Verified' status");
        } catch {
            console2.log("'Verified' status already exists");
        }
        
        try proxy.addStatus("Certified") {
            console2.log("Added 'Certified' status");
        } catch {
            console2.log("'Certified' status already exists");
        }
        vm.stopPrank();
    }

    /**
     * @dev Demonstrate mint operation optimization
     */
    function _demonstrateMintOptimization() internal {
        console2.log("\n=== MINT OPTIMIZATION DEMO ===");
        
        // Create sample operations
        BatchOptimization.MintOperation[] memory operations = _createSampleMintOperations(30);
        
        // Calculate optimal batching
        BatchOptimization.BatchResult memory result = optimizer.calculateMintBatching(operations);
        
        console2.log("Sample scenario: 30 mint operations");
        console2.log("Optimal strategy:", result.batchCount, "batches");
        console2.log("Estimated total gas:", result.totalGasEstimate);
        
        // Execute the batches
        uint256[] memory tokenIds = optimizer.executeBatchedMints(operations);
        console2.log("Successfully executed all", tokenIds.length, "mint operations");
    }

    /**
     * @dev Demonstrate migrate operation optimization
     */
    function _demonstrateMigrateOptimization() internal {
        console2.log("\n=== MIGRATE OPTIMIZATION DEMO ===");
        
        // Create sample operations
        BatchOptimization.MigrateOperation[] memory operations = _createSampleMigrateOperations(12);
        
        // Calculate optimal batching
        BatchOptimization.BatchResult memory result = optimizer.calculateMigrateBatching(operations);
        
        console2.log("Sample scenario: 12 migrate operations");
        console2.log("Optimal strategy:", result.batchCount, "batches");
        console2.log("Estimated total gas:", result.totalGasEstimate);
        
        // Execute the batches
        uint256[] memory tokenIds = optimizer.executeBatchedMigrations(operations);
        console2.log("Successfully executed all", tokenIds.length, "migrate operations");
    }

    /**
     * @dev Demonstrate gas cost analysis for different scenarios
     */
    function _demonstrateGasCostAnalysis() internal {
        console2.log("\n=== GAS COST ANALYSIS DEMO ===");
        
        // Analyze adding items to different batch sizes
        uint256 cost1to5 = optimizer.calculateAdditionalGasCost(1, 4, "mint", 0);
        uint256 cost5to10 = optimizer.calculateAdditionalGasCost(5, 5, "mint", 0);
        uint256 cost10to15 = optimizer.calculateAdditionalGasCost(10, 5, "mint", 0);
        
        console2.log("Gas cost analysis for mint operations:");
        console2.log("- Adding 4 items to batch of 1:", cost1to5);
        console2.log("- Adding 5 items to batch of 5:", cost5to10);
        console2.log("- Adding 5 items to batch of 10:", cost10to15);
        
        // Analyze for migrate operations
        uint256 migrateCost1to3 = optimizer.calculateAdditionalGasCost(1, 2, "migrate", 2);
        uint256 migrateCost3to6 = optimizer.calculateAdditionalGasCost(3, 3, "migrate", 2);
        
        console2.log("Gas cost analysis for migrate operations (2 statuses each):");
        console2.log("- Adding 2 items to batch of 1:", migrateCost1to3);
        console2.log("- Adding 3 items to batch of 3:", migrateCost3to6);
    }

    /**
     * @dev Create sample mint operations for testing
     */
    function _createSampleMintOperations(uint256 count) internal pure returns (BatchOptimization.MintOperation[] memory) {
        BatchOptimization.MintOperation[] memory operations = new BatchOptimization.MintOperation[](count);
        
        for (uint256 i = 0; i < count; i++) {
            operations[i] = BatchOptimization.MintOperation({
                cid: string(abi.encodePacked("QmSampleMint", vm.toString(i))),
                amount: 1
            });
        }
        
        return operations;
    }

    /**
     * @dev Create sample migrate operations for testing
     */
    function _createSampleMigrateOperations(uint256 count) internal pure returns (BatchOptimization.MigrateOperation[] memory) {
        BatchOptimization.MigrateOperation[] memory operations = new BatchOptimization.MigrateOperation[](count);
        
        for (uint256 i = 0; i < count; i++) {
            // Create status history for each migration
            CruratedBase.Status[] memory statuses = new CruratedBase.Status[](2 + (i % 3)); // Variable status count
            
            for (uint256 j = 0; j < statuses.length; j++) {
                statuses[j] = CruratedBase.Status({
                    statusId: (j % 3) + 1, // Status IDs 1, 2, 3
                    timestamp: 1000000 + (i * 1000) + (j * 100),
                    reason: string(abi.encodePacked("Migration ", vm.toString(i), " Status ", vm.toString(j)))
                });
            }
            
            operations[i] = BatchOptimization.MigrateOperation({
                cid: string(abi.encodePacked("QmSampleMigrate", vm.toString(i))),
                amount: 1,
                statuses: statuses
            });
        }
        
        return operations;
    }
}