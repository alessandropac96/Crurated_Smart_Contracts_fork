// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISortManager} from "./ISortManager.sol";
import {IFilterManager} from "./IFilterManager.sol";
import {IDataProvider} from "./IDataProvider.sol";

/**
 * @title IQueryExecutor
 * @notice Two-step query executor interface
 * @dev Orchestrates the two-step process:
 *      Step 1: Filter and sort to get IDs
 *      Step 2: Fetch detailed data with caching
 */
interface IQueryExecutor {
    /**
     * @notice Query parameters structure
     * @param filters Array of filter types to apply
     * @param filterParams Encoded parameters for each filter
     * @param sortField Field to sort by
     * @param sortDirection Sort direction
     * @param offset Pagination offset
     * @param limit Pagination limit
     * @param owner Owner address for balance queries
     */
    struct QueryParams {
        bytes32[] filters;
        bytes[] filterParams;
        ISortManager.SortField sortField;
        ISortManager.SortDirection sortDirection;
        uint256 offset;
        uint256 limit;
        address owner;
    }

    /**
     * @notice Query result structure
     * @param tokenData Array of complete token data
     * @param totalCount Total number of tokens matching filters (before pagination)
     * @param hasMore Whether there are more results available
     */
    struct QueryResult {
        IDataProvider.TokenData[] tokenData;
        uint256 totalCount;
        bool hasMore;
    }

    /**
     * @notice Execute a complete two-step query
     * @param params Query parameters
     * @return result Query result with paginated data
     */
    function executeQuery(
        QueryParams memory params
    ) external view returns (QueryResult memory result);

    /**
     * @notice Execute step 1 only: get filtered and sorted IDs
     * @param params Query parameters
     * @return tokenIds Array of token IDs matching criteria
     */
    function getFilteredIds(
        QueryParams memory params
    ) external view returns (uint256[] memory tokenIds);

    /**
     * @notice Execute step 2 only: fetch data for given IDs
     * @param tokenIds Array of token IDs to fetch data for
     * @param owner Owner address for balance queries
     * @return tokenData Array of complete token data
     */
    function fetchDataForIds(
        uint256[] memory tokenIds,
        address owner
    ) external view returns (IDataProvider.TokenData[] memory tokenData);
}
