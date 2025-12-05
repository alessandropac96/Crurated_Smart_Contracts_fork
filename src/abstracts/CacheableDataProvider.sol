// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IDataProvider} from "./IDataProvider.sol";
import {CruratedBase} from "./CruratedBase.sol";

/**
 * @title CacheableDataProvider
 * @notice Abstract cacheable data provider with storage optimization
 * @dev Implements caching layer for frequently accessed token data
 *      Cache is invalidated on token updates to ensure data consistency
 */
abstract contract CacheableDataProvider is IDataProvider {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Cached token data mapping
    mapping(uint256 => TokenData) internal _cache;

    /// @notice Cache validity tracking
    mapping(uint256 => bool) internal _cacheValid;

    /// @notice Cache timestamp for TTL management
    mapping(uint256 => uint256) internal _cacheTimestamp;

    /// @notice Global cache version for bulk invalidation
    uint256 internal _cacheVersion;

    /// @notice Token-specific cache version
    mapping(uint256 => uint256) internal _tokenCacheVersion;

    /// @notice Cache TTL in seconds (0 = no expiry)
    uint256 public cacheTTL;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CacheHit(uint256 indexed tokenId);
    event CacheMiss(uint256 indexed tokenId);
    event CacheInvalidated(uint256 indexed tokenId);
    event CacheInvalidatedAll();
    event CacheTTLUpdated(uint256 oldTTL, uint256 newTTL);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize with cache TTL
     * @param _cacheTTL Time-to-live for cache entries (0 = no expiry)
     */
    constructor(uint256 _cacheTTL) {
        cacheTTL = _cacheTTL;
        _cacheVersion = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get token data with caching
     * @param tokenId Token ID to fetch
     * @param owner Owner address for balance
     * @return data Complete token data
     */
    function getTokenData(
        uint256 tokenId,
        address owner
    ) external view override returns (TokenData memory data) {
        // Check cache validity
        if (_isCacheValid(tokenId)) {
            return _cache[tokenId];
        }

        // Cache miss - fetch fresh data
        return _fetchTokenData(tokenId, owner);
    }

    /**
     * @notice Get token data batch with caching
     * @param tokenIds Array of token IDs
     * @param owner Owner address for balances
     * @return dataArray Array of token data
     */
    function getTokenDataBatch(
        uint256[] memory tokenIds,
        address owner
    ) external view override returns (TokenData[] memory dataArray) {
        uint256 length = tokenIds.length;
        dataArray = new TokenData[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];

            if (_isCacheValid(tokenId)) {
                dataArray[i] = _cache[tokenId];
            } else {
                dataArray[i] = _fetchTokenData(tokenId, owner);
            }
        }

        return dataArray;
    }

    /**
     * @notice Check if token data is cached
     * @param tokenId Token ID to check
     * @return True if cached and valid
     */
    function isCached(uint256 tokenId) external view override returns (bool) {
        return _isCacheValid(tokenId);
    }

    /**
     * @notice Invalidate cache for specific token
     * @param tokenId Token ID to invalidate
     */
    function invalidateCache(uint256 tokenId) external override {
        _invalidateTokenCache(tokenId);
    }

    /**
     * @notice Invalidate all cached data
     */
    function invalidateAllCache() external override {
        _cacheVersion++;
        emit CacheInvalidatedAll();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL CACHE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if cache entry is valid
     * @param tokenId Token ID to check
     * @return True if cache is valid
     */
    function _isCacheValid(uint256 tokenId) internal view returns (bool) {
        // Check global cache version
        if (_tokenCacheVersion[tokenId] != _cacheVersion) {
            return false;
        }

        // Check if cache entry exists
        if (!_cacheValid[tokenId]) {
            return false;
        }

        // Check TTL if enabled
        if (cacheTTL > 0) {
            uint256 cacheAge = block.timestamp - _cacheTimestamp[tokenId];
            if (cacheAge > cacheTTL) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Store data in cache
     * @param tokenId Token ID
     * @param data Token data to cache
     */
    function _updateCache(uint256 tokenId, TokenData memory data) internal {
        _cache[tokenId] = data;
        _cacheValid[tokenId] = true;
        _cacheTimestamp[tokenId] = block.timestamp;
        _tokenCacheVersion[tokenId] = _cacheVersion;
    }

    /**
     * @notice Invalidate specific token cache
     * @param tokenId Token ID to invalidate
     */
    function _invalidateTokenCache(uint256 tokenId) internal {
        _cacheValid[tokenId] = false;
        emit CacheInvalidated(tokenId);
    }

    /**
     * @notice Update cache TTL
     * @param newTTL New TTL value
     */
    function _updateCacheTTL(uint256 newTTL) internal {
        uint256 oldTTL = cacheTTL;
        cacheTTL = newTTL;
        emit CacheTTLUpdated(oldTTL, newTTL);
    }

    /*//////////////////////////////////////////////////////////////
                        ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetch fresh token data from source
     * @dev Must be implemented by concrete contracts
     * @param tokenId Token ID to fetch
     * @param owner Owner address for balance
     * @return data Complete token data
     */
    function _fetchTokenData(
        uint256 tokenId,
        address owner
    ) internal view virtual returns (TokenData memory data);
}
