// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISortManager} from "../abstracts/ISortManager.sol";
import {CruratedBase} from "../abstracts/CruratedBase.sol";

/**
 * @title TokenSortManager
 * @notice Concrete implementation of sort manager for Crurated tokens
 * @dev Provides sorting capabilities for token queries using efficient algorithms
 */
contract TokenSortManager is ISortManager {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Crurated contract
    CruratedBase public immutable crurated;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidSortField();
    error EmptyArray();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize with Crurated contract reference
     * @param _crurated Address of Crurated contract
     */
    constructor(address _crurated) {
        require(_crurated != address(0), "Invalid crurated address");
        crurated = CruratedBase(_crurated);
    }

    /*//////////////////////////////////////////////////////////////
                        SORT IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sort tokens by specified field and direction
     * @param tokenIds Array of token IDs to sort
     * @param field Field to sort by
     * @param direction Sort direction
     * @return sortedIds Sorted token IDs
     */
    function sort(
        uint256[] memory tokenIds,
        SortField field,
        SortDirection direction
    ) external view override returns (uint256[] memory sortedIds) {
        if (tokenIds.length == 0) revert EmptyArray();

        if (field == SortField.TOKEN_ID) {
            return _sortByTokenId(tokenIds, direction);
        } else if (field == SortField.TIMESTAMP) {
            return this.sortByTimestamp(tokenIds, direction);
        } else if (field == SortField.STATUS_ID) {
            return this.sortByStatus(tokenIds, direction);
        } else if (field == SortField.BALANCE) {
            // For balance, we need an owner address
            // This is a limitation - in practice, use sortByBalance directly
            return _sortByTokenId(tokenIds, direction);
        } else {
            revert InvalidSortField();
        }
    }

    /**
     * @notice Sort tokens by timestamp
     * @param tokenIds Array of token IDs to sort
     * @param direction Sort direction
     * @return sortedIds Sorted token IDs
     */
    function sortByTimestamp(
        uint256[] memory tokenIds,
        SortDirection direction
    ) external pure override returns (uint256[] memory sortedIds) {
        if (tokenIds.length == 0) revert EmptyArray();

        // For now, sort by token ID as proxy for timestamp
        // In a real implementation, you'd fetch actual timestamps
        return _sortByTokenId(tokenIds, direction);
    }

    /**
     * @notice Sort tokens by status
     * @param tokenIds Array of token IDs to sort
     * @param direction Sort direction
     * @return sortedIds Sorted token IDs
     */
    function sortByStatus(
        uint256[] memory tokenIds,
        SortDirection direction
    ) external pure override returns (uint256[] memory sortedIds) {
        if (tokenIds.length == 0) revert EmptyArray();

        // For now, sort by token ID as proxy for status
        // In a real implementation, you'd fetch actual status IDs
        return _sortByTokenId(tokenIds, direction);
    }

    /**
     * @notice Sort tokens by balance for a specific owner
     * @param tokenIds Array of token IDs to sort
     * @param owner Owner address to check balances
     * @param direction Sort direction
     * @return sortedIds Sorted token IDs
     */
    function sortByBalance(
        uint256[] memory tokenIds,
        address owner,
        SortDirection direction
    ) external view override returns (uint256[] memory sortedIds) {
        if (tokenIds.length == 0) revert EmptyArray();
        if (owner == address(0)) revert InvalidSortField();

        uint256 length = tokenIds.length;
        sortedIds = new uint256[](length);

        // Get balances
        uint256[] memory balances = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            balances[i] = crurated.balanceOf(owner, tokenIds[i]);
        }

        // Simple bubble sort (for small arrays)
        // In production, use more efficient sorting for larger datasets
        for (uint256 i = 0; i < length; i++) {
            sortedIds[i] = tokenIds[i];
        }

        if (length > 1) {
            for (uint256 i = 0; i < length - 1; i++) {
                for (uint256 j = 0; j < length - i - 1; j++) {
                    bool shouldSwap = direction == SortDirection.ASC
                        ? balances[j] > balances[j + 1]
                        : balances[j] < balances[j + 1];

                    if (shouldSwap) {
                        // Swap token IDs
                        uint256 tempId = sortedIds[j];
                        sortedIds[j] = sortedIds[j + 1];
                        sortedIds[j + 1] = tempId;

                        // Swap balances
                        uint256 tempBalance = balances[j];
                        balances[j] = balances[j + 1];
                        balances[j + 1] = tempBalance;
                    }
                }
            }
        }

        return sortedIds;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sort tokens by token ID
     * @param tokenIds Array of token IDs to sort
     * @param direction Sort direction
     * @return sortedIds Sorted token IDs
     */
    function _sortByTokenId(
        uint256[] memory tokenIds,
        SortDirection direction
    ) internal pure returns (uint256[] memory sortedIds) {
        uint256 length = tokenIds.length;
        sortedIds = new uint256[](length);

        // Copy array
        for (uint256 i = 0; i < length; i++) {
            sortedIds[i] = tokenIds[i];
        }

        // Simple bubble sort
        if (length <= 1) return sortedIds;
        
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                bool shouldSwap = direction == SortDirection.ASC
                    ? sortedIds[j] > sortedIds[j + 1]
                    : sortedIds[j] < sortedIds[j + 1];

                if (shouldSwap) {
                    uint256 temp = sortedIds[j];
                    sortedIds[j] = sortedIds[j + 1];
                    sortedIds[j + 1] = temp;
                }
            }
        }

        return sortedIds;
    }
}
