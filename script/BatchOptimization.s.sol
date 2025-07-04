// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Crurated} from "../src/Crurated.sol";
import {CruratedBase} from "../src/abstracts/CruratedBase.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title BatchOptimization
 * @notice Advanced gas optimization and batching script for Crurated operations
 * @dev Provides batch size calculation, gas cost analysis, and optimal batching for mint/migrate operations
 */
contract BatchOptimization is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default block gas limit for most EVM chains
    uint256 public constant DEFAULT_BLOCK_GAS_LIMIT = 30_000_000;
    
    /// @notice Safety margin to avoid hitting exact gas limit (10%)
    uint256 public constant SAFETY_MARGIN = 10;
    
    /// @notice Base gas cost for transaction overhead
    uint256 public constant BASE_TX_OVERHEAD = 21_000;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct MintOperation {
        string cid;
        uint256 amount;
    }

    struct MigrateOperation {
        string cid;
        uint256 amount;
        CruratedBase.Status[] statuses;
    }

    struct GasAnalysis {
        uint256 baseGas;
        uint256 perItemGas;
        uint256 totalGas;
        uint256 maxBatchSize;
        uint256 averageGasPerItem;
    }

    struct BatchResult {
        uint256 batchCount;
        uint256[] batchSizes;
        uint256 totalGasEstimate;
        uint256 totalOperations;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    Crurated public proxy;
    address public admin;
    uint256 public blockGasLimit;
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event GasAnalysisComplete(
        string operation,
        uint256 baseGas,
        uint256 perItemGas,
        uint256 maxBatchSize
    );

    event BatchingComplete(
        string operation,
        uint256 totalOperations,
        uint256 batchCount,
        uint256 totalGasEstimate
    );

    /*//////////////////////////////////////////////////////////////
                                INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the script with contract proxy and parameters
     * @param _proxy Address of the deployed Crurated proxy contract
     * @param _admin Admin address for operations
     * @param _blockGasLimit Custom block gas limit (0 for default)
     */
    function initialize(
        address _proxy,
        address _admin,
        uint256 _blockGasLimit
    ) external {
        proxy = Crurated(_proxy);
        admin = _admin;
        blockGasLimit = _blockGasLimit == 0 ? DEFAULT_BLOCK_GAS_LIMIT : _blockGasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                            GAS ANALYSIS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Analyze gas costs for mint operations with different batch sizes
     * @param maxTestSize Maximum batch size to test
     * @return analysis Detailed gas analysis results
     */
    function analyzeMintGas(uint256 maxTestSize) external returns (GasAnalysis memory analysis) {
        require(address(proxy) != address(0), "Proxy not initialized");
        
        vm.startPrank(admin);
        
        // Test single operation to get base gas
        uint256 singleGas = _measureMintGas(1);
        
        // Test batch of 5 to calculate per-item gas
        uint256 batchGas = _measureMintGas(5);
        uint256 perItemGas = (batchGas - singleGas) / 4; // Gas per additional item
        
        // Calculate theoretical maximum batch size
        uint256 safeGasLimit = (blockGasLimit * (100 - SAFETY_MARGIN)) / 100;
        uint256 availableGas = safeGasLimit - BASE_TX_OVERHEAD;
        uint256 maxBatchSize = (availableGas - singleGas) / perItemGas + 1;
        
        // Cap at reasonable testing limit
        if (maxBatchSize > maxTestSize) {
            maxBatchSize = maxTestSize;
        }
        
        // Verify with actual large batch test
        uint256 actualMaxGas = _measureMintGas(maxBatchSize);
        
        analysis = GasAnalysis({
            baseGas: singleGas,
            perItemGas: perItemGas,
            totalGas: actualMaxGas,
            maxBatchSize: maxBatchSize,
            averageGasPerItem: actualMaxGas / maxBatchSize
        });
        
        vm.stopPrank();
        
        emit GasAnalysisComplete("mint", analysis.baseGas, analysis.perItemGas, analysis.maxBatchSize);
        
        console.log("=== Mint Analysis Complete ===");
        console.log("Base gas cost:", analysis.baseGas);
        console.log("Per-item gas cost:", analysis.perItemGas);
        console.log("Optimal batch size:", analysis.maxBatchSize);
        
        return analysis;
    }

    /**
     * @notice Analyze gas costs for migrate operations with different batch sizes
     * @param maxTestSize Maximum batch size to test
     * @param statusCount Number of status entries per migration
     * @return analysis Detailed gas analysis results
     */
    function analyzeMigrateGas(
        uint256 maxTestSize, 
        uint256 statusCount
    ) external returns (GasAnalysis memory analysis) {
        require(address(proxy) != address(0), "Proxy not initialized");
        
        vm.startPrank(admin);
        
        // Test single operation to get base gas
        uint256 singleGas = _measureMigrateGas(1, statusCount);
        
        // Test batch of 3 to calculate per-item gas (smaller batch for migrate due to complexity)
        uint256 batchGas = _measureMigrateGas(3, statusCount);
        uint256 perItemGas = (batchGas - singleGas) / 2;
        
        // Calculate theoretical maximum batch size
        uint256 safeGasLimit = (blockGasLimit * (100 - SAFETY_MARGIN)) / 100;
        uint256 availableGas = safeGasLimit - BASE_TX_OVERHEAD;
        uint256 maxBatchSize = (availableGas - singleGas) / perItemGas + 1;
        
        // Cap at reasonable testing limit (migrate is more expensive)
        if (maxBatchSize > maxTestSize) {
            maxBatchSize = maxTestSize;
        }
        
        // Ensure minimum batch size of 1
        if (maxBatchSize == 0) {
            maxBatchSize = 1;
        }
        
        // Verify with actual large batch test
        uint256 actualMaxGas = _measureMigrateGas(maxBatchSize, statusCount);
        
        analysis = GasAnalysis({
            baseGas: singleGas,
            perItemGas: perItemGas,
            totalGas: actualMaxGas,
            maxBatchSize: maxBatchSize,
            averageGasPerItem: actualMaxGas / maxBatchSize
        });
        
        vm.stopPrank();
        
        emit GasAnalysisComplete("migrate", analysis.baseGas, analysis.perItemGas, analysis.maxBatchSize);
        
        console.log("=== Migrate Analysis Complete ===");
        console.log("Base gas cost:", analysis.baseGas);
        console.log("Per-item gas cost:", analysis.perItemGas);
        console.log("Optimal batch size:", analysis.maxBatchSize);
        console.log("Avg gas per status:", analysis.averageGasPerItem / statusCount);
        
        return analysis;
    }

    /*//////////////////////////////////////////////////////////////
                            BATCHING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate optimal batching for mint operations
     * @param operations Array of mint operations to batch
     * @return result Batching strategy and gas estimates
     */
    function calculateMintBatching(
        MintOperation[] calldata operations
    ) external returns (BatchResult memory result) {
        require(operations.length > 0, "No operations provided");
        
        // Get gas analysis for minting
        GasAnalysis memory gasAnalysis = this.analyzeMintGas(50);
        uint256 optimalBatchSize = gasAnalysis.maxBatchSize;
        
        // Calculate number of batches needed
        uint256 totalOps = operations.length;
        uint256 batchCount = (totalOps + optimalBatchSize - 1) / optimalBatchSize; // Ceiling division
        
        // Initialize batch sizes array
        uint256[] memory batchSizes = new uint256[](batchCount);
        uint256 totalGasEstimate = 0;
        
        // Calculate each batch size and gas estimate
        for (uint256 i = 0; i < batchCount; i++) {
            uint256 startIdx = i * optimalBatchSize;
            uint256 endIdx = startIdx + optimalBatchSize;
            if (endIdx > totalOps) {
                endIdx = totalOps;
            }
            
            uint256 batchSize = endIdx - startIdx;
            batchSizes[i] = batchSize;
            
            // Estimate gas for this batch
            if (batchSize == 1) {
                totalGasEstimate += gasAnalysis.baseGas;
            } else {
                totalGasEstimate += gasAnalysis.baseGas + (gasAnalysis.perItemGas * (batchSize - 1));
            }
        }
        
        result = BatchResult({
            batchCount: batchCount,
            batchSizes: batchSizes,
            totalGasEstimate: totalGasEstimate,
            totalOperations: totalOps
        });
        
        emit BatchingComplete("mint", totalOps, batchCount, totalGasEstimate);
        
        console.log("=== Mint Batching Complete ===");
        console.log("Total operations:", totalOps);
        console.log("Number of batches:", batchCount);
        console.log("Estimated total gas:", totalGasEstimate);
        
        return result;
    }

    /**
     * @notice Calculate optimal batching for migrate operations
     * @param operations Array of migrate operations to batch
     * @return result Batching strategy and gas estimates
     */
    function calculateMigrateBatching(
        MigrateOperation[] calldata operations
    ) external returns (BatchResult memory result) {
        require(operations.length > 0, "No operations provided");
        
        // Calculate average status count
        uint256 totalStatuses = 0;
        for (uint256 i = 0; i < operations.length; i++) {
            totalStatuses += operations[i].statuses.length;
        }
        uint256 avgStatusCount = totalStatuses / operations.length;
        
        // Get gas analysis for migration
        GasAnalysis memory gasAnalysis = this.analyzeMigrateGas(20, avgStatusCount);
        uint256 optimalBatchSize = gasAnalysis.maxBatchSize;
        
        // Calculate number of batches needed
        uint256 totalOps = operations.length;
        uint256 batchCount = (totalOps + optimalBatchSize - 1) / optimalBatchSize;
        
        // Initialize batch sizes array
        uint256[] memory batchSizes = new uint256[](batchCount);
        uint256 totalGasEstimate = 0;
        
        // Calculate each batch size and gas estimate
        for (uint256 i = 0; i < batchCount; i++) {
            uint256 startIdx = i * optimalBatchSize;
            uint256 endIdx = startIdx + optimalBatchSize;
            if (endIdx > totalOps) {
                endIdx = totalOps;
            }
            
            uint256 batchSize = endIdx - startIdx;
            batchSizes[i] = batchSize;
            
            // Estimate gas for this batch
            if (batchSize == 1) {
                totalGasEstimate += gasAnalysis.baseGas;
            } else {
                totalGasEstimate += gasAnalysis.baseGas + (gasAnalysis.perItemGas * (batchSize - 1));
            }
        }
        
        result = BatchResult({
            batchCount: batchCount,
            batchSizes: batchSizes,
            totalGasEstimate: totalGasEstimate,
            totalOperations: totalOps
        });
        
        emit BatchingComplete("migrate", totalOps, batchCount, totalGasEstimate);
        
        console.log("=== Migrate Batching Complete ===");
        console.log("Total operations:", totalOps);
        console.log("Average statuses per op:", avgStatusCount);
        console.log("Number of batches:", batchCount);
        console.log("Estimated total gas:", totalGasEstimate);
        
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute optimally batched mint operations
     * @param operations Array of mint operations to execute
     * @return tokenIds All created token IDs
     */
    function executeBatchedMints(
        MintOperation[] calldata operations
    ) external returns (uint256[] memory tokenIds) {
        require(address(proxy) != address(0), "Proxy not initialized");
        
        // Calculate optimal batching
        BatchResult memory batchResult = this.calculateMintBatching(operations);
        
        // Execute batches
        tokenIds = new uint256[](operations.length);
        uint256 tokenIdIndex = 0;
        
        vm.startPrank(admin);
        
        for (uint256 batchIdx = 0; batchIdx < batchResult.batchCount; batchIdx++) {
            uint256 batchSize = batchResult.batchSizes[batchIdx];
            uint256 startIdx = tokenIdIndex;
            
            // Prepare batch data
            string[] memory cids = new string[](batchSize);
            uint256[] memory amounts = new uint256[](batchSize);
            
            for (uint256 i = 0; i < batchSize; i++) {
                uint256 opIdx = startIdx + i;
                cids[i] = operations[opIdx].cid;
                amounts[i] = operations[opIdx].amount;
            }
            
            // Execute batch
            uint256[] memory batchTokenIds = proxy.mint(cids, amounts);
            
            // Store results
            for (uint256 i = 0; i < batchSize; i++) {
                tokenIds[tokenIdIndex++] = batchTokenIds[i];
            }
            
        }
        
        vm.stopPrank();
        
        console.log("=== Mint Execution Complete ===");
        console.log("Total tokens minted:", tokenIds.length);
        console.log("Executed in", batchResult.batchCount, "batches");
        
        return tokenIds;
    }

    /**
     * @notice Execute optimally batched migrate operations
     * @param operations Array of migrate operations to execute
     * @return tokenIds All created token IDs
     */
    function executeBatchedMigrations(
        MigrateOperation[] calldata operations
    ) external returns (uint256[] memory tokenIds) {
        require(address(proxy) != address(0), "Proxy not initialized");
        
        // Calculate optimal batching
        BatchResult memory batchResult = this.calculateMigrateBatching(operations);
        
        // Execute batches
        tokenIds = new uint256[](operations.length);
        uint256 tokenIdIndex = 0;
        
        vm.startPrank(admin);
        
        for (uint256 batchIdx = 0; batchIdx < batchResult.batchCount; batchIdx++) {
            uint256 batchSize = batchResult.batchSizes[batchIdx];
            uint256 startIdx = tokenIdIndex;
            
            // Prepare batch data
            string[] memory cids = new string[](batchSize);
            uint256[] memory amounts = new uint256[](batchSize);
            CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](batchSize);
            
            for (uint256 i = 0; i < batchSize; i++) {
                uint256 opIdx = startIdx + i;
                cids[i] = operations[opIdx].cid;
                amounts[i] = operations[opIdx].amount;
                statuses[i] = operations[opIdx].statuses;
            }
            
            // Execute batch
            uint256[] memory batchTokenIds = proxy.migrate(cids, amounts, statuses);
            
            // Store results
            for (uint256 i = 0; i < batchSize; i++) {
                tokenIds[tokenIdIndex++] = batchTokenIds[i];
            }
            
        }
        
        vm.stopPrank();
        
        console.log("=== Migration Execution Complete ===");
        console.log("Total tokens migrated:", tokenIds.length);
        console.log("Executed in", batchResult.batchCount, "batches");
        
        return tokenIds;
    }

    /*//////////////////////////////////////////////////////////////
                        UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate gas cost difference for adding operations to a batch
     * @param currentBatchSize Current batch size
     * @param additionalItems Number of items to add
     * @param operation Type of operation ("mint" or "migrate")
     * @param statusCount Average status count for migrate operations
     * @return additionalGas Gas cost for additional items
     */
    function calculateAdditionalGasCost(
        uint256 currentBatchSize,
        uint256 additionalItems,
        string calldata operation,
        uint256 statusCount
    ) external returns (uint256 additionalGas) {
        require(address(proxy) != address(0), "Proxy not initialized");
        
        vm.startPrank(admin);
        
        if (keccak256(bytes(operation)) == keccak256(bytes("mint"))) {
            uint256 currentGas = _measureMintGas(currentBatchSize);
            uint256 newGas = _measureMintGas(currentBatchSize + additionalItems);
            additionalGas = newGas - currentGas;
        } else if (keccak256(bytes(operation)) == keccak256(bytes("migrate"))) {
            uint256 currentGas = _measureMigrateGas(currentBatchSize, statusCount);
            uint256 newGas = _measureMigrateGas(currentBatchSize + additionalItems, statusCount);
            additionalGas = newGas - currentGas;
        } else {
            revert("Invalid operation type");
        }
        
        vm.stopPrank();
        
        console.log("=== Gas Cost Analysis ===");
        console.log("Additional gas for", additionalItems, "items:", additionalGas);
        
        return additionalGas;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Measure gas usage for mint operations
     */
    function _measureMintGas(uint256 batchSize) internal returns (uint256 gasUsed) {
        string[] memory cids = new string[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        
        for (uint256 i = 0; i < batchSize; i++) {
            cids[i] = string(abi.encodePacked("QmTest", vm.toString(i), vm.toString(block.timestamp)));
            amounts[i] = 1;
        }
        
        uint256 gasBefore = gasleft();
        proxy.mint(cids, amounts);
        gasUsed = gasBefore - gasleft();
        
        return gasUsed;
    }

    /**
     * @dev Measure gas usage for migrate operations
     */
    function _measureMigrateGas(uint256 batchSize, uint256 statusCount) internal returns (uint256 gasUsed) {
        // First ensure we have enough status types
        _ensureStatusTypes(statusCount);
        
        string[] memory cids = new string[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](batchSize);
        
        for (uint256 i = 0; i < batchSize; i++) {
            cids[i] = string(abi.encodePacked("QmMigrate", vm.toString(i), vm.toString(block.timestamp)));
            amounts[i] = 1;
            
            statuses[i] = new CruratedBase.Status[](statusCount);
            for (uint256 j = 0; j < statusCount; j++) {
                statuses[i][j] = CruratedBase.Status({
                    statusId: (j % 3) + 1, // Use status IDs 1, 2, 3
                    timestamp: block.timestamp - (j * 1000),
                    reason: string(abi.encodePacked("Status ", vm.toString(j)))
                });
            }
        }
        
        uint256 gasBefore = gasleft();
        proxy.migrate(cids, amounts, statuses);
        gasUsed = gasBefore - gasleft();
        
        return gasUsed;
    }
    
    /**
     * @dev Ensure required status types exist
     */
    function _ensureStatusTypes(uint256 requiredCount) internal {
        uint256 nextId = proxy.nextStatusId();
        uint256 needed = requiredCount < 3 ? 3 : requiredCount; // Ensure at least 3 status types
        
        for (uint256 i = nextId; i <= needed; i++) {
            proxy.addStatus(string(abi.encodePacked("Status", vm.toString(i))));
        }
    }

    /*//////////////////////////////////////////////////////////////
                        RUN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Run comprehensive gas analysis and batching demonstration
     * @dev Attempts to read environment variables, provides helpful error messages if missing
     */
    function run() external {
        console.log("=== Batch Optimization Script ===");
        
        // Try to read environment variables with error handling
        address proxyAddress;
        address adminAddress;
        
        try vm.envAddress("PROXY_ADDRESS") returns (address addr) {
            proxyAddress = addr;
        } catch {
            console.log("ERROR: PROXY_ADDRESS environment variable not set");
            console.log("Please set the proxy address of your deployed Crurated contract");
            console.log("Example: export PROXY_ADDRESS=0x...");
            console.log("Or use the batch_optimize.sh script for automated setup");
            return;
        }
        
        try vm.envAddress("ADMIN") returns (address addr) {
            adminAddress = addr;
        } catch {
            console.log("ERROR: ADMIN environment variable not set");
            console.log("Please set the admin address for contract operations");
            console.log("Example: export ADMIN=0x...");
            console.log("Or use the batch_optimize.sh script for automated setup");
            return;
        }
        
        console.log("Initializing with proxy:", proxyAddress);
        console.log("Using admin:", adminAddress);
        
        // Initialize the contract
        this.initialize(proxyAddress, adminAddress, 0);
        
        console.log("Running basic gas analysis...");
        
        // Run basic analysis
        try this.analyzeMintGas(20) {
            console.log("[OK] Mint gas analysis completed");
        } catch {
            console.log("[ERROR] Mint gas analysis failed - check contract state");
        }
        
        try this.analyzeMigrateGas(10, 2) {
            console.log("[OK] Migrate gas analysis completed");
        } catch {
            console.log("[ERROR] Migrate gas analysis failed - check contract state");
        }
        
        console.log("=== Script completed ===");
        console.log("For more detailed operations, use:");
        console.log("- analyzeMintGas(maxTestSize)");
        console.log("- analyzeMigrateGas(maxTestSize, statusCount)");
        console.log("- calculateAdditionalGasCost(...)");
        console.log("- executeBatchedMints(operations)");
        console.log("- executeBatchedMigrations(operations)");
    }

    /**
     * @notice Standalone initialization for direct script usage
     * @dev Call this before using other functions if not using run()
     */
    function setup() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address adminAddress = vm.envAddress("ADMIN");
        
        console.log("Setting up BatchOptimization...");
        console.log("Proxy:", proxyAddress);
        console.log("Admin:", adminAddress);
        
        this.initialize(proxyAddress, adminAddress, 0);
        console.log("[OK] Setup complete");
    }
}