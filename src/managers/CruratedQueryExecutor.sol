// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BaseQueryExecutor} from "../abstracts/BaseQueryExecutor.sol";
import {CruratedBase} from "../abstracts/CruratedBase.sol";

/**
 * @title CruratedQueryExecutor
 * @notice Complete query executor for Crurated tokens
 * @dev Implements two-step query pattern with filtering, sorting, and caching
 */
contract CruratedQueryExecutor is BaseQueryExecutor {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Crurated contract
    CruratedBase public immutable crurated;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize with all manager instances
     * @param _crurated Address of Crurated contract
     * @param _filterManager Address of filter manager
     * @param _sortManager Address of sort manager
     * @param _dataProvider Address of data provider
     */
    constructor(
        address _crurated,
        address _filterManager,
        address _sortManager,
        address _dataProvider
    ) BaseQueryExecutor(_filterManager, _sortManager, _dataProvider) {
        require(_crurated != address(0), "Invalid crurated address");
        crurated = CruratedBase(_crurated);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all available token IDs from Crurated contract
     * @return tokenIds Array of all token IDs
     */
    function _getAllTokenIds() internal view override returns (uint256[] memory tokenIds) {
        uint256 totalTokens = crurated.tokenCount();
        tokenIds = new uint256[](totalTokens);

        for (uint256 i = 0; i < totalTokens; i++) {
            tokenIds[i] = i + 1; // Token IDs start at 1
        }

        return tokenIds;
    }
}
