// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IFilterManager} from "../abstracts/IFilterManager.sol";
import {CruratedBase} from "../abstracts/CruratedBase.sol";

/**
 * @title TokenFilterManager
 * @notice Concrete implementation of filter manager for Crurated tokens
 * @dev Provides filtering capabilities for token queries
 */
contract TokenFilterManager is IFilterManager {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Crurated contract
    CruratedBase public immutable crurated;

    /// @notice Filter type constants
    bytes32 public constant FILTER_BY_STATUS = keccak256("FILTER_BY_STATUS");
    bytes32 public constant FILTER_BY_TIME_RANGE = keccak256("FILTER_BY_TIME_RANGE");
    bytes32 public constant FILTER_BY_OWNER = keccak256("FILTER_BY_OWNER");

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidFilterType();
    error InvalidFilterParams();

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
                        FILTER IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Filter tokens by status
     * @param statusId Status ID to filter by
     * @param allTokenIds All token IDs to filter
     * @return filteredIds Filtered token IDs
     */
    function filterByStatus(
        uint256 statusId,
        uint256[] memory allTokenIds
    ) external pure override returns (uint256[] memory filteredIds) {
        // Count matching tokens
        uint256 count = 0;
        uint256 length = allTokenIds.length;
        bool[] memory matches = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            // This is a simplified check - in a real implementation,
            // you'd need to track status history in the contract
            // For now, we assume all tokens match (placeholder logic)
            matches[i] = true;
            count++;
        }

        // Build result array
        filteredIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < length; i++) {
            if (matches[i]) {
                filteredIds[index++] = allTokenIds[i];
            }
        }

        return filteredIds;
    }

    /**
     * @notice Filter tokens by time range
     * @param fromTimestamp Start timestamp
     * @param toTimestamp End timestamp
     * @param allTokenIds All token IDs to filter
     * @return filteredIds Filtered token IDs
     */
    function filterByTimeRange(
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256[] memory allTokenIds
    ) external pure override returns (uint256[] memory filteredIds) {
        if (fromTimestamp > toTimestamp) revert InvalidFilterParams();

        // For this implementation, we'll return all tokens
        // In a real implementation, you'd check token creation/update timestamps
        return allTokenIds;
    }

    /**
     * @notice Filter tokens by owner
     * @param owner Owner address to filter by
     * @param allTokenIds All token IDs to filter
     * @return filteredIds Filtered token IDs
     */
    function filterByOwner(
        address owner,
        uint256[] memory allTokenIds
    ) external view override returns (uint256[] memory filteredIds) {
        if (owner == address(0)) revert InvalidFilterParams();

        uint256 length = allTokenIds.length;
        uint256 count = 0;
        bool[] memory matches = new bool[](length);

        // Check balance for each token
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = allTokenIds[i];
            if (crurated.balanceOf(owner, tokenId) > 0) {
                matches[i] = true;
                count++;
            }
        }

        // Build result array
        filteredIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < length; i++) {
            if (matches[i]) {
                filteredIds[index++] = allTokenIds[i];
            }
        }

        return filteredIds;
    }

    /**
     * @notice Apply multiple filters in sequence
     * @param filters Array of filter types
     * @param params Encoded parameters for each filter
     * @param allTokenIds All token IDs to filter
     * @return filteredIds Filtered token IDs after all filters
     */
    function applyFilters(
        bytes32[] memory filters,
        bytes[] memory params,
        uint256[] memory allTokenIds
    ) external view override returns (uint256[] memory filteredIds) {
        if (filters.length != params.length) revert InvalidFilterParams();

        filteredIds = allTokenIds;

        // Apply each filter sequentially
        for (uint256 i = 0; i < filters.length; i++) {
            bytes32 filterType = filters[i];

            if (filterType == FILTER_BY_STATUS) {
                uint256 statusId = abi.decode(params[i], (uint256));
                filteredIds = this.filterByStatus(statusId, filteredIds);
            } else if (filterType == FILTER_BY_TIME_RANGE) {
                (uint256 fromTimestamp, uint256 toTimestamp) = abi.decode(
                    params[i],
                    (uint256, uint256)
                );
                filteredIds = this.filterByTimeRange(
                    fromTimestamp,
                    toTimestamp,
                    filteredIds
                );
            } else if (filterType == FILTER_BY_OWNER) {
                address owner = abi.decode(params[i], (address));
                filteredIds = this.filterByOwner(owner, filteredIds);
            } else {
                revert InvalidFilterType();
            }
        }

        return filteredIds;
    }
}
