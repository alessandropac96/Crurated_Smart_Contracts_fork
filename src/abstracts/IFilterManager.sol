// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IFilterManager
 * @notice Interface for filtering token IDs based on various criteria
 * @dev Implements step 1 of two-step query pattern: filter and return IDs only
 */
interface IFilterManager {
    /**
     * @notice Filter token IDs based on status
     * @param statusId The status ID to filter by
     * @param allTokenIds All available token IDs to filter from
     * @return filteredIds Array of token IDs matching the filter
     */
    function filterByStatus(
        uint256 statusId,
        uint256[] memory allTokenIds
    ) external view returns (uint256[] memory filteredIds);

    /**
     * @notice Filter token IDs based on timestamp range
     * @param fromTimestamp Start of the time range (inclusive)
     * @param toTimestamp End of the time range (inclusive)
     * @param allTokenIds All available token IDs to filter from
     * @return filteredIds Array of token IDs matching the filter
     */
    function filterByTimeRange(
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256[] memory allTokenIds
    ) external view returns (uint256[] memory filteredIds);

    /**
     * @notice Filter token IDs based on owner
     * @param owner The owner address to filter by
     * @param allTokenIds All available token IDs to filter from
     * @return filteredIds Array of token IDs matching the filter
     */
    function filterByOwner(
        address owner,
        uint256[] memory allTokenIds
    ) external view returns (uint256[] memory filteredIds);

    /**
     * @notice Apply multiple filters in sequence
     * @param filters Array of filter types to apply
     * @param params Encoded parameters for each filter
     * @param allTokenIds All available token IDs to filter from
     * @return filteredIds Array of token IDs matching all filters
     */
    function applyFilters(
        bytes32[] memory filters,
        bytes[] memory params,
        uint256[] memory allTokenIds
    ) external view returns (uint256[] memory filteredIds);
}
