// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IQueryExecutor} from "./IQueryExecutor.sol";
import {ISortManager} from "./ISortManager.sol";
import {IFilterManager} from "./IFilterManager.sol";
import {IDataProvider} from "./IDataProvider.sol";

/**
 * @title BaseQueryExecutor
 * @notice Abstract base implementation of two-step query execution
 * @dev Provides the orchestration logic for filtering, sorting, and data fetching
 */
abstract contract BaseQueryExecutor is IQueryExecutor {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Filter manager instance
    IFilterManager public immutable filterManager;

    /// @notice Sort manager instance
    ISortManager public immutable sortManager;

    /// @notice Data provider instance
    IDataProvider public immutable dataProvider;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidPagination();
    error InvalidQueryParams();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize with manager instances
     * @param _filterManager Filter manager address
     * @param _sortManager Sort manager address
     * @param _dataProvider Data provider address
     */
    constructor(
        address _filterManager,
        address _sortManager,
        address _dataProvider
    ) {
        require(_filterManager != address(0), "Invalid filter manager");
        require(_sortManager != address(0), "Invalid sort manager");
        require(_dataProvider != address(0), "Invalid data provider");

        filterManager = IFilterManager(_filterManager);
        sortManager = ISortManager(_sortManager);
        dataProvider = IDataProvider(_dataProvider);
    }

    /*//////////////////////////////////////////////////////////////
                            QUERY EXECUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute complete two-step query with filtering, sorting, and pagination
     * @param params Query parameters
     * @return result Query result with paginated data
     */
    function executeQuery(
        QueryParams memory params
    ) external view override returns (QueryResult memory result) {
        // Validate pagination
        if (params.limit == 0) revert InvalidPagination();

        // Step 1: Get all token IDs that match filters and sorting
        uint256[] memory filteredIds = getFilteredIds(params);
        result.totalCount = filteredIds.length;

        // Apply pagination
        uint256 startIndex = params.offset;
        if (startIndex >= filteredIds.length) {
            // Return empty result if offset is beyond available data
            result.tokenData = new IDataProvider.TokenData[](0);
            result.hasMore = false;
            return result;
        }

        uint256 endIndex = startIndex + params.limit;
        if (endIndex > filteredIds.length) {
            endIndex = filteredIds.length;
            result.hasMore = false;
        } else {
            result.hasMore = true;
        }

        // Extract paginated IDs
        uint256 pageSize = endIndex - startIndex;
        uint256[] memory paginatedIds = new uint256[](pageSize);
        for (uint256 i = 0; i < pageSize; i++) {
            paginatedIds[i] = filteredIds[startIndex + i];
        }

        // Step 2: Fetch detailed data for paginated IDs
        result.tokenData = fetchDataForIds(paginatedIds, params.owner);

        return result;
    }

    /**
     * @notice Execute step 1: filter and sort to get IDs
     * @param params Query parameters
     * @return tokenIds Array of filtered and sorted token IDs
     */
    function getFilteredIds(
        QueryParams memory params
    ) public view override returns (uint256[] memory tokenIds) {
        // Get all available token IDs
        uint256[] memory allIds = _getAllTokenIds();

        // Apply filters if any
        if (params.filters.length > 0) {
            tokenIds = filterManager.applyFilters(
                params.filters,
                params.filterParams,
                allIds
            );
        } else {
            tokenIds = allIds;
        }

        // Apply sorting
        tokenIds = sortManager.sort(
            tokenIds,
            params.sortField,
            params.sortDirection
        );

        return tokenIds;
    }

    /**
     * @notice Execute step 2: fetch data for given IDs
     * @param tokenIds Array of token IDs
     * @param owner Owner address for balance queries
     * @return tokenData Array of complete token data
     */
    function fetchDataForIds(
        uint256[] memory tokenIds,
        address owner
    ) public view override returns (IDataProvider.TokenData[] memory tokenData) {
        return dataProvider.getTokenDataBatch(tokenIds, owner);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all available token IDs
     * @dev Must be implemented by concrete contracts
     * @return tokenIds Array of all token IDs
     */
    function _getAllTokenIds() internal view virtual returns (uint256[] memory tokenIds);
}
