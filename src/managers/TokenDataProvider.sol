// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {CacheableDataProvider} from "../abstracts/CacheableDataProvider.sol";
import {CruratedBase} from "../abstracts/CruratedBase.sol";

/**
 * @title TokenDataProvider
 * @notice Concrete implementation of cacheable data provider for Crurated tokens
 * @dev Fetches and caches complete token data with automatic invalidation
 */
contract TokenDataProvider is CacheableDataProvider {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Crurated contract
    CruratedBase public immutable crurated;

    /// @notice Mapping to track latest status per token (for caching)
    mapping(uint256 => CruratedBase.Status) internal _latestStatus;

    /// @notice Mapping to track status count per token
    mapping(uint256 => uint256) internal _statusCount;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenDataFetched(uint256 indexed tokenId, address indexed owner);
    event StatusTracked(uint256 indexed tokenId, uint256 statusId);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenNotExists(uint256 tokenId);
    error InvalidOwner();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize with Crurated contract and cache TTL
     * @param _crurated Address of Crurated contract
     * @param _cacheTTL Cache time-to-live in seconds
     */
    constructor(
        address _crurated,
        uint256 _cacheTTL
    ) CacheableDataProvider(_cacheTTL) {
        require(_crurated != address(0), "Invalid crurated address");
        crurated = CruratedBase(_crurated);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Track status update for a token (invalidates cache)
     * @param tokenId Token ID that was updated
     * @param status New status information
     */
    function trackStatusUpdate(
        uint256 tokenId,
        CruratedBase.Status memory status
    ) external {
        _latestStatus[tokenId] = status;
        _statusCount[tokenId]++;
        _invalidateTokenCache(tokenId);
        emit StatusTracked(tokenId, status.statusId);
    }

    /**
     * @notice Track metadata update for a token (invalidates cache)
     * @param tokenId Token ID that was updated
     */
    function trackMetadataUpdate(uint256 tokenId) external {
        _invalidateTokenCache(tokenId);
    }

    /**
     * @notice Update cache TTL (admin function)
     * @param newTTL New TTL value
     */
    function updateCacheTTL(uint256 newTTL) external {
        _updateCacheTTL(newTTL);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetch fresh token data from Crurated contract
     * @param tokenId Token ID to fetch
     * @param owner Owner address for balance
     * @return data Complete token data
     */
    function _fetchTokenData(
        uint256 tokenId,
        address owner
    ) internal view override returns (TokenData memory data) {
        if (owner == address(0)) revert InvalidOwner();

        // Validate token exists
        uint256 totalTokens = crurated.tokenCount();
        if (tokenId == 0 || tokenId > totalTokens) {
            revert TokenNotExists(tokenId);
        }

        // Fetch data from contract
        data.tokenId = tokenId;
        data.cid = crurated.cidOf(tokenId);
        data.balance = crurated.balanceOf(owner, tokenId);
        data.latestStatus = _latestStatus[tokenId];
        data.statusCount = _statusCount[tokenId];

        return data;
    }
}
