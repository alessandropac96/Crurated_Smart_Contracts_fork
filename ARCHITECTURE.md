# Query System Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         CLIENT / FRONTEND                             │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             │ Query Request
                             │ (filters, sorting, pagination)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      CruratedQueryExecutor                            │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  executeQuery(QueryParams) → QueryResult                       │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │ Step 1: Filter & Sort (Get IDs)                          │ │  │
│  │  │  - Apply filters                                          │ │  │
│  │  │  - Sort results                                           │ │  │
│  │  │  - Apply pagination                                       │ │  │
│  │  │  → Returns: uint256[] tokenIds                           │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │ Step 2: Fetch Data (With Caching)                        │ │  │
│  │  │  - Check cache                                            │ │  │
│  │  │  - Fetch missing data                                     │ │  │
│  │  │  - Update cache                                           │ │  │
│  │  │  → Returns: TokenData[]                                  │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────┘  │
└────────────────┬──────────────────┬──────────────────┬───────────────┘
                 │                  │                  │
                 ▼                  ▼                  ▼
┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
│ TokenFilterManager │  │ TokenSortManager   │  │ TokenDataProvider  │
├────────────────────┤  ├────────────────────┤  ├────────────────────┤
│ • filterByOwner    │  │ • sortByTokenId    │  │ • getTokenData     │
│ • filterByStatus   │  │ • sortByBalance    │  │ • getTokenDataBatch│
│ • filterByTime     │  │ • sortByTimestamp  │  │ • Cache Management │
│ • applyFilters     │  │ • sortByStatus     │  │ • TTL Support      │
└────────┬───────────┘  └────────┬───────────┘  └────────┬───────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   Crurated Contract    │
                    ├────────────────────────┤
                    │ • Token Storage        │
                    │ • Balance Tracking     │
                    │ • Status Management    │
                    │ • Metadata (CIDs)      │
                    └────────────────────────┘
```

## Component Interaction Flow

### Query Execution Flow

```
1. Client Request
   ↓
2. QueryExecutor receives QueryParams
   {
     filters: [FILTER_BY_OWNER],
     filterParams: [encode(ownerAddress)],
     sortField: TOKEN_ID,
     sortDirection: DESC,
     offset: 0,
     limit: 10,
     owner: ownerAddress
   }
   ↓
3. STEP 1: Get Filtered & Sorted IDs
   ↓
   3a. QueryExecutor → _getAllTokenIds()
       Returns: [1, 2, 3, 4, 5]
   ↓
   3b. QueryExecutor → FilterManager.applyFilters()
       Input: [1, 2, 3, 4, 5]
       Filters: [FILTER_BY_OWNER]
       Returns: [1, 2, 5] (tokens owned by address)
   ↓
   3c. QueryExecutor → SortManager.sort()
       Input: [1, 2, 5]
       Sort: TOKEN_ID, DESC
       Returns: [5, 2, 1]
   ↓
   3d. Apply Pagination
       Input: [5, 2, 1]
       Offset: 0, Limit: 10
       Returns: [5, 2, 1] (all fit in page)
   ↓
4. STEP 2: Fetch Data with Caching
   ↓
   4a. For each tokenId in [5, 2, 1]:
       ↓
       DataProvider.getTokenData(tokenId, owner)
       ↓
       Check Cache:
       ├─ If cached & valid → Return cached data (CACHE HIT)
       └─ If not cached → Fetch from Crurated (CACHE MISS)
          ↓
          Fetch:
          - tokenId
          - cid (from Crurated.cidOf())
          - balance (from Crurated.balanceOf())
          - latestStatus (from tracking)
          - statusCount (from tracking)
          ↓
          Store in cache
          ↓
          Return TokenData
   ↓
5. Build QueryResult
   {
     tokenData: [TokenData5, TokenData2, TokenData1],
     totalCount: 3,
     hasMore: false
   }
   ↓
6. Return to Client
```

## Cache Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TokenDataProvider                         │
│                   (CacheableDataProvider)                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Cache Storage                            │  │
│  │                                                        │  │
│  │  _cache: mapping(tokenId => TokenData)               │  │
│  │  _cacheValid: mapping(tokenId => bool)               │  │
│  │  _cacheTimestamp: mapping(tokenId => uint256)        │  │
│  │  _tokenCacheVersion: mapping(tokenId => uint256)     │  │
│  │  _cacheVersion: uint256 (global)                     │  │
│  │  cacheTTL: uint256 (time-to-live)                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Cache Validation Logic                      │  │
│  │                                                        │  │
│  │  _isCacheValid(tokenId):                             │  │
│  │    1. Check global version match                     │  │
│  │    2. Check cache entry exists                       │  │
│  │    3. Check TTL (if enabled)                         │  │
│  │    → Returns: bool                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Cache Invalidation Triggers                   │  │
│  │                                                        │  │
│  │  • Manual: invalidateCache(tokenId)                  │  │
│  │  • Bulk: invalidateAllCache()                        │  │
│  │  • Auto: trackStatusUpdate(tokenId, status)          │  │
│  │  • Auto: trackMetadataUpdate(tokenId)                │  │
│  │  • TTL: Automatic expiry after cacheTTL seconds      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ 1. Query Request
       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Query Executor                            │
│                                                              │
│  Step 1: Filter & Sort                                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │Get All IDs │→ │Apply       │→ │Sort        │→ IDs      │
│  │[1,2,3,4,5] │  │Filters     │  │Results     │  [5,2,1]  │
│  └────────────┘  └────────────┘  └────────────┘           │
│                                                              │
│  Step 2: Fetch Data                                         │
│  ┌────────────────────────────────────────────────────┐    │
│  │ For each ID:                                        │    │
│  │   Check Cache → Hit? Return : Fetch & Cache        │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Result: TokenData[]                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
              ┌────────────────┐
              │ TokenData[]    │
              │ + totalCount   │
              │ + hasMore      │
              └────────────────┘
```

## Class Hierarchy

```
Interfaces (Abstract Contracts)
├── IFilterManager
│   └── TokenFilterManager (Concrete)
│
├── ISortManager
│   └── TokenSortManager (Concrete)
│
├── IDataProvider
│   └── CacheableDataProvider (Abstract with Cache Logic)
│       └── TokenDataProvider (Concrete)
│
└── IQueryExecutor
    └── BaseQueryExecutor (Abstract Orchestration)
        └── CruratedQueryExecutor (Concrete)
```

## Pagination Flow

```
Total Tokens: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
Page Size: 3

Request 1: offset=0, limit=3
┌─────────────────────────────────────┐
│ Result: [1, 2, 3]                   │
│ totalCount: 10                      │
│ hasMore: true                       │
└─────────────────────────────────────┘

Request 2: offset=3, limit=3
┌─────────────────────────────────────┐
│ Result: [4, 5, 6]                   │
│ totalCount: 10                      │
│ hasMore: true                       │
└─────────────────────────────────────┘

Request 3: offset=6, limit=3
┌─────────────────────────────────────┐
│ Result: [7, 8, 9]                   │
│ totalCount: 10                      │
│ hasMore: true                       │
└─────────────────────────────────────┘

Request 4: offset=9, limit=3
┌─────────────────────────────────────┐
│ Result: [10]                        │
│ totalCount: 10                      │
│ hasMore: false                      │
└─────────────────────────────────────┘
```

## Filter Chaining

```
Initial: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
   ↓
Filter 1: FILTER_BY_OWNER (owner=Alice)
Result: [1, 3, 5, 7, 9] (Alice's tokens)
   ↓
Filter 2: FILTER_BY_STATUS (status=Certified)
Result: [3, 7, 9] (Certified tokens owned by Alice)
   ↓
Filter 3: FILTER_BY_TIME_RANGE (after timestamp X)
Result: [7, 9] (Recent certified tokens owned by Alice)
   ↓
Sort: TOKEN_ID, DESC
Result: [9, 7]
   ↓
Paginate: offset=0, limit=1
Result: [9]
```

## Cache Hit vs Miss Performance

```
Scenario: Fetch data for 5 tokens

Cache Miss (First Request):
┌─────────────────────────────────────┐
│ Token 1: Fetch from contract (~9k)  │
│ Token 2: Fetch from contract (~9k)  │
│ Token 3: Fetch from contract (~9k)  │
│ Token 4: Fetch from contract (~9k)  │
│ Token 5: Fetch from contract (~9k)  │
│ Total: ~45k gas                     │
└─────────────────────────────────────┘

Cache Hit (Subsequent Request):
┌─────────────────────────────────────┐
│ Token 1: Return from cache (~4k)    │
│ Token 2: Return from cache (~4k)    │
│ Token 3: Return from cache (~4k)    │
│ Token 4: Return from cache (~4k)    │
│ Token 5: Return from cache (~4k)    │
│ Total: ~20k gas                     │
│ Savings: ~55% gas reduction         │
└─────────────────────────────────────┘

Mixed (Partial Cache):
┌─────────────────────────────────────┐
│ Token 1: Cache hit (~4k)            │
│ Token 2: Cache miss (~9k)           │
│ Token 3: Cache hit (~4k)            │
│ Token 4: Cache hit (~4k)            │
│ Token 5: Cache miss (~9k)           │
│ Total: ~30k gas                     │
│ Savings: ~33% gas reduction         │
└─────────────────────────────────────┘
```

## Integration Points

### With Crurated Contract

```
TokenDataProvider ←→ Crurated
   ├─ Read: tokenCount()
   ├─ Read: cidOf(tokenId)
   ├─ Read: balanceOf(owner, tokenId)
   └─ Read: statusName(statusId)

TokenFilterManager ←→ Crurated
   └─ Read: balanceOf(owner, tokenId)

TokenSortManager ←→ Crurated
   └─ Read: balanceOf(owner, tokenId)

CruratedQueryExecutor ←→ Crurated
   └─ Read: tokenCount()
```

### Event Flow

```
Crurated Contract Events:
   ├─ ProvenanceUpdated
   │  └─ Trigger: dataProvider.trackStatusUpdate()
   │     └─ Effect: Invalidate cache for tokenId
   │
   └─ MetadataUpdated
      └─ Trigger: dataProvider.trackMetadataUpdate()
         └─ Effect: Invalidate cache for tokenId
```

## Deployment Sequence

```
1. Deploy Crurated (already deployed)
   ↓
2. Deploy TokenFilterManager(crurated)
   ↓
3. Deploy TokenSortManager(crurated)
   ↓
4. Deploy TokenDataProvider(crurated, cacheTTL)
   ↓
5. Deploy CruratedQueryExecutor(
     crurated,
     filterManager,
     sortManager,
     dataProvider
   )
   ↓
6. Configure cache TTL (optional)
   dataProvider.updateCacheTTL(newTTL)
   ↓
7. Ready for queries!
```

## Summary

This architecture provides:

✅ **Clean Separation**: Each component has a single responsibility
✅ **Flexibility**: Components can be upgraded independently
✅ **Efficiency**: Two-step pattern minimizes gas usage
✅ **Scalability**: Caching reduces repeated data fetching costs
✅ **Extensibility**: Easy to add new filters, sort fields, or data sources
✅ **Testability**: Each component can be tested in isolation
