// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
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
        console.log("=== Batch Optimization Runner ===");
        
        // Load environment variables with error handling
        address proxyAddress;
        try vm.envAddress("PROXY_ADDRESS") returns (address addr) {
            proxyAddress = addr;
        } catch {
            console.log("ERROR: PROXY_ADDRESS environment variable not set");
            console.log("Please set the proxy address of your deployed Crurated contract");
            console.log("Example: export PROXY_ADDRESS=0x...");
            console.log("Or use: ./batch_optimize.sh deploy-local");
            return;
        }
        
        try vm.envAddress("OWNER") returns (address addr) {
            owner = addr;
        } catch {
            console.log("ERROR: OWNER environment variable not set");
            console.log("Please set the owner address");
            console.log("Example: export OWNER=0x...");
            return;
        }
        
        try vm.envAddress("ADMIN") returns (address addr) {
            admin = addr;
        } catch {
            console.log("ERROR: ADMIN environment variable not set");
            console.log("Please set the admin address");
            console.log("Example: export ADMIN=0x...");
            return;
        }
        
        console.log("Proxy Address:", proxyAddress);
        console.log("Owner Address:", owner);
        console.log("Admin Address:", admin);
        
        // Initialize contracts
        proxy = Crurated(proxyAddress);
        optimizer = new BatchOptimization();
        
        try optimizer.initialize(proxyAddress, admin, 0) {
            console.log("[OK] Optimizer initialized");
        } catch {
            console.log("[ERROR] Failed to initialize optimizer");
            return;
        }
        
        // Setup required status types
        _setupStatusTypes();
        
        // Run demonstrations
        console.log("Running demonstrations...");
        _demonstrateMintOptimization();
        _demonstrateMigrateOptimization();
        _demonstrateGasCostAnalysis();
        
        console.log("=== All demonstrations completed successfully! ===");
    }

    /**
     * @notice Analyze mint operations gas usage patterns
     */
    function analyzeMintGas() external {
        if (!_initializeOptimizer()) return;
        
        console.log("Analyzing mint gas patterns...");
        try optimizer.analyzeMintGas(100) {
            console.log("[OK] Mint gas analysis completed successfully");
        } catch {
            console.log("[ERROR] Mint gas analysis failed");
        }
    }

    /**
     * @notice Analyze migrate operations gas usage patterns
     */
    function analyzeMigrateGas() external {
        if (!_initializeOptimizer()) return;
        
        console.log("Analyzing migrate gas patterns...");
        try optimizer.analyzeMigrateGas(50, 3) {
            console.log("[OK] Migrate gas analysis completed successfully");
        } catch {
            console.log("[ERROR] Migrate gas analysis failed");
        }
    }

    /**
     * @notice Execute sample mint operations using optimal batching
     */
    function executeSampleMints() external {
        if (!_initializeOptimizer()) return;
        
        // Create sample mint operations
        BatchOptimization.MintOperation[] memory operations = _createSampleMintOperations(25);
        
        console.log("Executing sample mint operations...");
        try optimizer.executeBatchedMints(operations) returns (uint256[] memory tokenIds) {
            console.log("[OK] Successfully executed mint operations");
            console.log("Operations count:", operations.length);
            console.log("Generated tokens:", tokenIds.length);
        } catch {
            console.log("[ERROR] Failed to execute mint operations");
        }
    }

    /**
     * @notice Execute sample migrate operations using optimal batching
     */
    function executeSampleMigrations() external {
        if (!_initializeOptimizer()) return;
        
        // Setup status types first
        _setupStatusTypes();
        
        // Create sample migrate operations
        BatchOptimization.MigrateOperation[] memory operations = _createSampleMigrateOperations(15);
        
        console.log("Executing sample migrate operations...");
        try optimizer.executeBatchedMigrations(operations) returns (uint256[] memory tokenIds) {
            console.log("[OK] Successfully executed migrate operations");
            console.log("Operations count:", operations.length);
            console.log("Generated tokens:", tokenIds.length);
        } catch {
            console.log("[ERROR] Failed to execute migrate operations");
        }
    }

    /**
     * @notice Calculate gas costs for different batch size increases
     */
    function analyzeIncrementalGasCosts() external {
        if (!_initializeOptimizer()) return;
        
        console.log("Analyzing incremental gas costs...");
        
        // Analyze mint costs
        console.log("--- Mint Cost Analysis ---");
        try optimizer.calculateAdditionalGasCost(1, 4, "mint", 0) returns (uint256 cost) {
            console.log("Adding 4 items to batch of 1");
            console.log("Additional gas cost:", cost);
        } catch {
            console.log("[ERROR] Failed to analyze mint costs (1->5)");
        }
        
        try optimizer.calculateAdditionalGasCost(5, 5, "mint", 0) returns (uint256 cost) {
            console.log("Adding 5 items to batch of 5");
            console.log("Additional gas cost:", cost);
        } catch {
            console.log("[ERROR] Failed to analyze mint costs (5->10)");
        }
        
        // Analyze migrate costs
        console.log("--- Migrate Cost Analysis ---");
        try optimizer.calculateAdditionalGasCost(1, 2, "migrate", 2) returns (uint256 cost) {
            console.log("Adding 2 items to batch of 1");
            console.log("Additional gas cost:", cost);
        } catch {
            console.log("[ERROR] Failed to analyze migrate costs (1->3)");
        }
        
        console.log("[OK] Incremental cost analysis completed");
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initialize optimizer with environment variables
     * @return success True if initialization was successful
     */
    function _initializeOptimizer() internal returns (bool success) {
        address proxyAddress;
        try vm.envAddress("PROXY_ADDRESS") returns (address addr) {
            proxyAddress = addr;
        } catch {
            console.log("[ERROR] PROXY_ADDRESS not set. Use: export PROXY_ADDRESS=0x...");
            return false;
        }
        
        try vm.envAddress("ADMIN") returns (address addr) {
            admin = addr;
        } catch {
            console.log("[ERROR] ADMIN not set. Use: export ADMIN=0x...");
            return false;
        }
        
        proxy = Crurated(proxyAddress);
        optimizer = new BatchOptimization();
        
        try optimizer.initialize(proxyAddress, admin, 0) {
            return true;
        } catch {
            console.log("[ERROR] Failed to initialize optimizer with provided addresses");
            return false;
        }
    }

    /**
     * @dev Setup required status types for demonstrations
     */
    function _setupStatusTypes() internal {
        vm.startPrank(admin);
        try proxy.addStatus("Created") {
            console.log("Info logged");
        } catch {
            console.log("Info logged");
        }
        
        try proxy.addStatus("Verified") {
            console.log("Info logged");
        } catch {
            console.log("Info logged");
        }
        
        try proxy.addStatus("Certified") {
            console.log("Info logged");
        } catch {
            console.log("Info logged");
        }
        vm.stopPrank();
    }

    /**
     * @dev Demonstrate mint operation optimization
     */
    function _demonstrateMintOptimization() internal {
        console.log("Info logged");
        
        // Create sample operations
        BatchOptimization.MintOperation[] memory operations = _createSampleMintOperations(30);
        
        // Calculate optimal batching
        BatchOptimization.BatchResult memory result = optimizer.calculateMintBatching(operations);
        
        console.log("Info logged");
        console.log("Info logged");
        console.log("Info logged");
        
        // Execute the batches
        uint256[] memory tokenIds = optimizer.executeBatchedMints(operations);
        console.log("Info logged");
    }

    /**
     * @dev Demonstrate migrate operation optimization
     */
    function _demonstrateMigrateOptimization() internal {
        console.log("Info logged");
        
        // Create sample operations
        BatchOptimization.MigrateOperation[] memory operations = _createSampleMigrateOperations(12);
        
        // Calculate optimal batching
        BatchOptimization.BatchResult memory result = optimizer.calculateMigrateBatching(operations);
        
        console.log("Info logged");
        console.log("Info logged");
        console.log("Info logged");
        
        // Execute the batches
        uint256[] memory tokenIds = optimizer.executeBatchedMigrations(operations);
        console.log("Info logged");
    }

    /**
     * @dev Demonstrate gas cost analysis for different scenarios
     */
    function _demonstrateGasCostAnalysis() internal {
        console.log("Info logged");
        
        // Analyze adding items to different batch sizes
        uint256 cost1to5 = optimizer.calculateAdditionalGasCost(1, 4, "mint", 0);
        uint256 cost5to10 = optimizer.calculateAdditionalGasCost(5, 5, "mint", 0);
        uint256 cost10to15 = optimizer.calculateAdditionalGasCost(10, 5, "mint", 0);
        
        console.log("Info logged");
        console.log("Info logged");
        console.log("Info logged");
        console.log("Info logged");
        
        // Analyze for migrate operations
        uint256 migrateCost1to3 = optimizer.calculateAdditionalGasCost(1, 2, "migrate", 2);
        uint256 migrateCost3to6 = optimizer.calculateAdditionalGasCost(3, 3, "migrate", 2);
        
        console.log("Info logged");
        console.log("Info logged");
        console.log("Info logged");
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