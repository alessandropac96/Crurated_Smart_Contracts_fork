// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISortManager
 * @notice Interface for sorting token IDs based on various criteria
 * @dev Implements step 1 of two-step query pattern: sort and return ordered IDs
 */
interface ISortManager {
    /// @notice Sort direction enumeration
    enum SortDirection {
        ASC,
        DESC
    }

    /// @notice Sort field enumeration
    enum SortField {
        TOKEN_ID,
        TIMESTAMP,
        STATUS_ID,
        BALANCE
    }

    /**
     * @notice Sort token IDs by specified field and direction
     * @param tokenIds Array of token IDs to sort
     * @param field The field to sort by
     * @param direction Sort direction (ASC or DESC)
     * @return sortedIds Array of sorted token IDs
     */
    function sort(
        uint256[] memory tokenIds,
        SortField field,
        SortDirection direction
    ) external view returns (uint256[] memory sortedIds);

    /**
     * @notice Sort token IDs by timestamp
     * @param tokenIds Array of token IDs to sort
     * @param direction Sort direction (ASC or DESC)
     * @return sortedIds Array of sorted token IDs
     */
    function sortByTimestamp(
        uint256[] memory tokenIds,
        SortDirection direction
    ) external view returns (uint256[] memory sortedIds);

    /**
     * @notice Sort token IDs by status
     * @param tokenIds Array of token IDs to sort
     * @param direction Sort direction (ASC or DESC)
     * @return sortedIds Array of sorted token IDs
     */
    function sortByStatus(
        uint256[] memory tokenIds,
        SortDirection direction
    ) external view returns (uint256[] memory sortedIds);

    /**
     * @notice Sort token IDs by balance
     * @param tokenIds Array of token IDs to sort
     * @param owner The owner address to check balances for
     * @param direction Sort direction (ASC or DESC)
     * @return sortedIds Array of sorted token IDs
     */
    function sortByBalance(
        uint256[] memory tokenIds,
        address owner,
        SortDirection direction
    ) external view returns (uint256[] memory sortedIds);
}
