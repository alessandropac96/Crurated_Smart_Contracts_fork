# Query System Architecture

## Overview

This document describes the two-step query system with caching for the Crurated smart contract. The system implements a clean abstraction layer for sorting, filtering, and fetching data with built-in caching capabilities.

## Architecture

### Two-Step Query Pattern

The system implements a two-step data fetching pattern:

1. **Step 1: Filter & Sort** - Get IDs matching criteria
2. **Step 2: Fetch Data** - Retrieve detailed data with caching

This pattern optimizes gas usage and enables efficient pagination and caching.

## Components

### 1. Filter Manager (`IFilterManager` / `TokenFilterManager`)

**Purpose**: Filter token IDs based on various criteria

**Key Features**:
- Filter by owner (checks token balance)
- Filter by status ID
- Filter by time range
- Chainable filters (apply multiple filters sequentially)

**Example Usage**:
```solidity
// Filter tokens owned by a specific address
uint256[] memory ownedTokens = filterManager.filterByOwner(ownerAddress, allTokenIds);

// Apply multiple filters
bytes32[] memory filters = new bytes32[](2);
filters[0] = filterManager.FILTER_BY_OWNER();
filters[1] = filterManager.FILTER_BY_STATUS();

bytes[] memory params = new bytes[](2);
params[0] = abi.encode(ownerAddress);
params[1] = abi.encode(statusId);

uint256[] memory filtered = filterManager.applyFilters(filters, params, allTokenIds);
```

### 2. Sort Manager (`ISortManager` / `TokenSortManager`)

**Purpose**: Sort token IDs based on various fields

**Key Features**:
- Sort by token ID (ascending/descending)
- Sort by timestamp (ascending/descending)
- Sort by status (ascending/descending)
- Sort by balance for a specific owner (ascending/descending)

**Example Usage**:
```solidity
// Sort by token ID ascending
uint256[] memory sorted = sortManager.sort(
    tokenIds,
    ISortManager.SortField.TOKEN_ID,
    ISortManager.SortDirection.ASC
);

// Sort by balance descending
uint256[] memory sortedByBalance = sortManager.sortByBalance(
    tokenIds,
    ownerAddress,
    ISortManager.SortDirection.DESC
);
```

### 3. Data Provider (`IDataProvider` / `TokenDataProvider`)

**Purpose**: Fetch and cache complete token data

**Key Features**:
- Cacheable data fetching
- Automatic cache invalidation
- TTL-based cache expiry
- Batch data fetching
- Status tracking integration

**Data Structure**:
```solidity
struct TokenData {
    uint256 tokenId;
    string cid;              // IPFS content identifier
    uint256 balance;         // Balance for queried owner
    Status latestStatus;     // Most recent status
    uint256 statusCount;     // Total status updates
}
```

**Example Usage**:
```solidity
// Fetch single token data (with caching)
IDataProvider.TokenData memory data = dataProvider.getTokenData(tokenId, owner);

// Fetch batch data
uint256[] memory tokenIds = new uint256[](3);
tokenIds[0] = 1;
tokenIds[1] = 2;
tokenIds[2] = 3;
IDataProvider.TokenData[] memory batchData = dataProvider.getTokenDataBatch(tokenIds, owner);

// Check cache status
bool isCached = dataProvider.isCached(tokenId);

// Invalidate cache
dataProvider.invalidateCache(tokenId);
dataProvider.invalidateAllCache();
```

### 4. Query Executor (`IQueryExecutor` / `CruratedQueryExecutor`)

**Purpose**: Orchestrate the complete two-step query process

**Key Features**:
- Complete query execution with filtering, sorting, and pagination
- Separate step execution for flexibility
- Pagination support with `hasMore` indicator
- Integration with all managers

**Query Parameters**:
```solidity
struct QueryParams {
    bytes32[] filters;                    // Filter types to apply
    bytes[] filterParams;                 // Encoded filter parameters
    ISortManager.SortField sortField;     // Field to sort by
    ISortManager.SortDirection sortDirection; // Sort direction
    uint256 offset;                       // Pagination offset
    uint256 limit;                        // Pagination limit
    address owner;                        // Owner for balance queries
}
```

**Query Result**:
```solidity
struct QueryResult {
    IDataProvider.TokenData[] tokenData;  // Paginated token data
    uint256 totalCount;                   // Total matching tokens
    bool hasMore;                         // More results available
}
```

**Example Usage**:
```solidity
// Complete query with pagination
IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
    filters: new bytes32[](0),
    filterParams: new bytes[](0),
    sortField: ISortManager.SortField.TOKEN_ID,
    sortDirection: ISortManager.SortDirection.DESC,
    offset: 0,
    limit: 10,
    owner: ownerAddress
});

IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(params);

// Two-step execution
// Step 1: Get filtered IDs
uint256[] memory ids = queryExecutor.getFilteredIds(params);

// Step 2: Fetch data for specific IDs
IDataProvider.TokenData[] memory data = queryExecutor.fetchDataForIds(ids, owner);
```

## Caching System

### Cache Implementation

The `CacheableDataProvider` abstract contract provides a sophisticated caching layer:

**Features**:
- In-memory cache storage
- Cache validity tracking
- TTL (Time-To-Live) support
- Global cache versioning for bulk invalidation
- Per-token cache versioning
- Automatic cache invalidation on updates

**Cache Flow**:
1. Check if data is cached and valid
2. If valid, return cached data (cache hit)
3. If invalid, fetch fresh data (cache miss)
4. Store fetched data in cache
5. Return data

**Cache Invalidation**:
- Manual invalidation via `invalidateCache(tokenId)`
- Bulk invalidation via `invalidateAllCache()`
- Automatic invalidation on status updates
- Automatic invalidation on metadata updates
- TTL-based expiry (configurable)

### Cache Configuration

```solidity
// Deploy with 5-minute cache TTL
TokenDataProvider dataProvider = new TokenDataProvider(
    address(crurated),
    300  // 300 seconds = 5 minutes
);

// Update TTL
dataProvider.updateCacheTTL(600); // 10 minutes

// Disable TTL (cache never expires automatically)
dataProvider.updateCacheTTL(0);
```

## Integration with Crurated

### Status Tracking

When token statuses are updated, the data provider should be notified:

```solidity
// After updating status
CruratedBase.Status memory status = CruratedBase.Status({
    statusId: certifiedStatusId,
    timestamp: block.timestamp,
    reason: "Quality certified"
});

dataProvider.trackStatusUpdate(tokenId, status);
```

### Metadata Updates

When token metadata is updated, invalidate the cache:

```solidity
// After updating CID
dataProvider.trackMetadataUpdate(tokenId);
```

## Complete Workflow Example

```solidity
// 1. Deploy managers
TokenFilterManager filterManager = new TokenFilterManager(address(crurated));
TokenSortManager sortManager = new TokenSortManager(address(crurated));
TokenDataProvider dataProvider = new TokenDataProvider(address(crurated), 300);

// 2. Deploy query executor
CruratedQueryExecutor queryExecutor = new CruratedQueryExecutor(
    address(crurated),
    address(filterManager),
    address(sortManager),
    address(dataProvider)
);

// 3. Execute query
bytes32[] memory filters = new bytes32[](1);
filters[0] = filterManager.FILTER_BY_OWNER();

bytes[] memory params = new bytes[](1);
params[0] = abi.encode(ownerAddress);

IQueryExecutor.QueryParams memory queryParams = IQueryExecutor.QueryParams({
    filters: filters,
    filterParams: params,
    sortField: ISortManager.SortField.TOKEN_ID,
    sortDirection: ISortManager.SortDirection.DESC,
    offset: 0,
    limit: 20,
    owner: ownerAddress
});

IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(queryParams);

// 4. Process results
for (uint256 i = 0; i < result.tokenData.length; i++) {
    IDataProvider.TokenData memory token = result.tokenData[i];
    // Process token data
}

// 5. Pagination
if (result.hasMore) {
    queryParams.offset = queryParams.offset + queryParams.limit;
    IQueryExecutor.QueryResult memory nextPage = queryExecutor.executeQuery(queryParams);
}
```

## Gas Optimization

### Efficient Sorting

The sort manager uses bubble sort for simplicity. For production with large datasets:
- Consider implementing quicksort or mergesort
- Use off-chain sorting for very large datasets
- Limit the number of tokens sorted on-chain

### Caching Benefits

Caching provides significant gas savings:
- **Cache Hit**: ~50% gas reduction vs fresh fetch
- **Batch Operations**: Amortized cost across multiple tokens
- **Repeated Queries**: Subsequent queries are much cheaper

### Pagination

Always use pagination for large result sets:
- Reduces gas cost per query
- Improves user experience
- Prevents transaction timeouts

## Testing

The system includes comprehensive tests covering:

### Filter Manager Tests
- Filter by owner
- Filter by owner with no tokens
- Filter by time range
- Apply multiple filters

### Sort Manager Tests
- Sort by token ID (ascending/descending)
- Sort by balance (ascending/descending)
- Sort by timestamp
- Sort by status

### Data Provider Tests
- Get single token data
- Get batch token data
- Cache invalidation (single/all)
- Track status updates
- Track metadata updates

### Query Executor Tests
- Basic query execution
- Query with pagination
- Query with filters
- Query with sorting
- Two-step query pattern
- Complete workflow integration

Run tests:
```bash
forge test --match-contract QuerySystemTest -vv
```

## Future Enhancements

### Potential Improvements

1. **Advanced Filtering**
   - Range filters (e.g., balance > X)
   - Complex boolean logic (AND/OR/NOT)
   - Full-text search on metadata

2. **Optimized Sorting**
   - Implement quicksort/mergesort for large datasets
   - Off-chain sorting with on-chain verification
   - Pre-sorted indices

3. **Enhanced Caching**
   - LRU (Least Recently Used) eviction
   - Configurable cache size limits
   - Persistent cache across transactions

4. **Query Optimization**
   - Query plan optimization
   - Index-based lookups
   - Materialized views

5. **Analytics**
   - Query performance metrics
   - Cache hit/miss statistics
   - Popular query patterns

## Security Considerations

1. **Access Control**: Ensure only authorized addresses can invalidate cache
2. **Cache Poisoning**: Validate data before caching
3. **Gas Limits**: Implement safeguards for large queries
4. **Integer Overflow**: Use SafeMath or Solidity 0.8+ overflow protection
5. **Reentrancy**: Follow checks-effects-interactions pattern

## Conclusion

This query system provides a robust, efficient, and extensible abstraction layer for data access in the Crurated smart contract. The two-step pattern with caching optimizes gas usage while maintaining flexibility and clean code architecture.
