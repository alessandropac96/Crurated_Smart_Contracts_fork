// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {CruratedBase} from "./CruratedBase.sol";

/**
 * @title IDataProvider
 * @notice Interface for providing enriched data for token IDs
 * @dev Implements step 2 of two-step query pattern: fetch and cache detailed data
 */
interface IDataProvider {
    /**
     * @notice Token data structure with all relevant information
     * @param tokenId The token identifier
     * @param cid IPFS content identifier
     * @param balance Token balance for the queried owner
     * @param latestStatus Most recent status information
     * @param statusCount Total number of status updates
     */
    struct TokenData {
        uint256 tokenId;
        string cid;
        uint256 balance;
        CruratedBase.Status latestStatus;
        uint256 statusCount;
    }

    /**
     * @notice Fetch complete data for a single token
     * @param tokenId The token ID to fetch data for
     * @param owner The owner address to check balance for
     * @return data Complete token data
     */
    function getTokenData(
        uint256 tokenId,
        address owner
    ) external view returns (TokenData memory data);

    /**
     * @notice Fetch complete data for multiple tokens (batch operation)
     * @param tokenIds Array of token IDs to fetch data for
     * @param owner The owner address to check balances for
     * @return dataArray Array of complete token data
     */
    function getTokenDataBatch(
        uint256[] memory tokenIds,
        address owner
    ) external view returns (TokenData[] memory dataArray);

    /**
     * @notice Check if data is cached for a token
     * @param tokenId The token ID to check
     * @return isCached True if data is cached
     */
    function isCached(uint256 tokenId) external view returns (bool isCached);

    /**
     * @notice Invalidate cache for a specific token
     * @param tokenId The token ID to invalidate cache for
     */
    function invalidateCache(uint256 tokenId) external;

    /**
     * @notice Invalidate all cached data
     */
    function invalidateAllCache() external;
}
