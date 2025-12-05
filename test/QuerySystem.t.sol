// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {Crurated} from "../src/Crurated.sol";
import {CruratedBase} from "../src/abstracts/CruratedBase.sol";
import {TokenFilterManager} from "../src/managers/TokenFilterManager.sol";
import {TokenSortManager} from "../src/managers/TokenSortManager.sol";
import {TokenDataProvider} from "../src/managers/TokenDataProvider.sol";
import {CruratedQueryExecutor} from "../src/managers/CruratedQueryExecutor.sol";
import {IQueryExecutor} from "../src/abstracts/IQueryExecutor.sol";
import {ISortManager} from "../src/abstracts/ISortManager.sol";
import {IFilterManager} from "../src/abstracts/IFilterManager.sol";
import {IDataProvider} from "../src/abstracts/IDataProvider.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title QuerySystemTest
 * @notice Comprehensive test suite for the two-step query system
 * @dev Tests filtering, sorting, caching, and complete query execution
 */
contract QuerySystemTest is Test {
    // Contract instances
    Crurated implementation;
    Crurated proxy;
    TokenFilterManager filterManager;
    TokenSortManager sortManager;
    TokenDataProvider dataProvider;
    CruratedQueryExecutor queryExecutor;

    // Test addresses
    address owner = address(0x1);
    address admin = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    // Status IDs
    uint256 createdStatusId;
    uint256 certifiedStatusId;
    uint256 processedStatusId;

    // Events
    event CacheHit(uint256 indexed tokenId);
    event CacheMiss(uint256 indexed tokenId);
    event CacheInvalidated(uint256 indexed tokenId);
    event TokenDataFetched(uint256 indexed tokenId, address indexed owner);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy Crurated contract
        implementation = new Crurated(owner, admin);
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner,
            admin
        );
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = Crurated(address(proxyContract));

        vm.stopPrank();

        // Register statuses
        vm.startPrank(admin);
        createdStatusId = proxy.addStatus("Created");
        certifiedStatusId = proxy.addStatus("Certified");
        processedStatusId = proxy.addStatus("Processed");
        vm.stopPrank();

        // Deploy query system components
        vm.startPrank(owner);
        filterManager = new TokenFilterManager(address(proxy));
        sortManager = new TokenSortManager(address(proxy));
        dataProvider = new TokenDataProvider(address(proxy), 300); // 5 min cache TTL
        queryExecutor = new CruratedQueryExecutor(
            address(proxy),
            address(filterManager),
            address(sortManager),
            address(dataProvider)
        );
        vm.stopPrank();

        // Mint some test tokens
        vm.startPrank(admin);
        string[] memory cids = new string[](5);
        cids[0] = "QmToken1";
        cids[1] = "QmToken2";
        cids[2] = "QmToken3";
        cids[3] = "QmToken4";
        cids[4] = "QmToken5";

        uint256[] memory amounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = i + 1; // Different amounts for each token
        }

        proxy.mint(cids, amounts);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        FILTER MANAGER TESTS
    //////////////////////////////////////////////////////////////*/

    function testFilterByOwner() public view {
        uint256[] memory allTokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            allTokenIds[i] = i + 1;
        }

        uint256[] memory filtered = filterManager.filterByOwner(owner, allTokenIds);

        // All tokens should be owned by owner
        assertEq(filtered.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(filtered[i], i + 1);
        }
    }

    function testFilterByOwnerNoTokens() public view {
        uint256[] memory allTokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            allTokenIds[i] = i + 1;
        }

        uint256[] memory filtered = filterManager.filterByOwner(user1, allTokenIds);

        // user1 has no tokens
        assertEq(filtered.length, 0);
    }

    function testFilterByTimeRange() public view {
        uint256[] memory allTokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            allTokenIds[i] = i + 1;
        }

        uint256[] memory filtered = filterManager.filterByTimeRange(
            1000,
            block.timestamp + 1000,
            allTokenIds
        );

        // All tokens should be in range
        assertEq(filtered.length, 5);
    }

    function testApplyMultipleFilters() public {
        uint256[] memory allTokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            allTokenIds[i] = i + 1;
        }

        bytes32[] memory filters = new bytes32[](1);
        filters[0] = filterManager.FILTER_BY_OWNER();

        bytes[] memory params = new bytes[](1);
        params[0] = abi.encode(owner);

        uint256[] memory filtered = filterManager.applyFilters(filters, params, allTokenIds);

        assertEq(filtered.length, 5);
    }

    /*//////////////////////////////////////////////////////////////
                        SORT MANAGER TESTS
    //////////////////////////////////////////////////////////////*/

    function testSortByTokenIdAscending() public view {
        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 5;
        tokenIds[1] = 3;
        tokenIds[2] = 1;
        tokenIds[3] = 4;
        tokenIds[4] = 2;

        uint256[] memory sorted = sortManager.sort(
            tokenIds,
            ISortManager.SortField.TOKEN_ID,
            ISortManager.SortDirection.ASC
        );

        assertEq(sorted.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(sorted[i], i + 1);
        }
    }

    function testSortByTokenIdDescending() public view {
        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;

        uint256[] memory sorted = sortManager.sort(
            tokenIds,
            ISortManager.SortField.TOKEN_ID,
            ISortManager.SortDirection.DESC
        );

        assertEq(sorted.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(sorted[i], 5 - i);
        }
    }

    function testSortByBalance() public view {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
        }

        uint256[] memory sorted = sortManager.sortByBalance(
            tokenIds,
            owner,
            ISortManager.SortDirection.ASC
        );

        assertEq(sorted.length, 5);
        // Token 1 has balance 1, Token 2 has balance 2, etc.
        for (uint256 i = 0; i < 5; i++) {
            assertEq(sorted[i], i + 1);
        }
    }

    function testSortByBalanceDescending() public view {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
        }

        uint256[] memory sorted = sortManager.sortByBalance(
            tokenIds,
            owner,
            ISortManager.SortDirection.DESC
        );

        assertEq(sorted.length, 5);
        // Token 5 has highest balance
        for (uint256 i = 0; i < 5; i++) {
            assertEq(sorted[i], 5 - i);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DATA PROVIDER TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetTokenData() public {
        IDataProvider.TokenData memory data = dataProvider.getTokenData(1, owner);

        assertEq(data.tokenId, 1);
        assertEq(data.cid, "QmToken1");
        assertEq(data.balance, 1);
    }

    function testGetTokenDataBatch() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        IDataProvider.TokenData[] memory dataArray = dataProvider.getTokenDataBatch(
            tokenIds,
            owner
        );

        assertEq(dataArray.length, 3);
        assertEq(dataArray[0].tokenId, 1);
        assertEq(dataArray[0].balance, 1);
        assertEq(dataArray[1].tokenId, 2);
        assertEq(dataArray[1].balance, 2);
        assertEq(dataArray[2].tokenId, 3);
        assertEq(dataArray[2].balance, 3);
    }

    function testCacheInvalidation() public {
        // First fetch - should cache
        dataProvider.getTokenData(1, owner);

        // Invalidate cache
        dataProvider.invalidateCache(1);

        // Check cache is invalid
        assertFalse(dataProvider.isCached(1));
    }

    function testCacheInvalidationAll() public {
        // Fetch multiple tokens
        dataProvider.getTokenData(1, owner);
        dataProvider.getTokenData(2, owner);
        dataProvider.getTokenData(3, owner);

        // Invalidate all
        dataProvider.invalidateAllCache();

        // Check all caches are invalid
        assertFalse(dataProvider.isCached(1));
        assertFalse(dataProvider.isCached(2));
        assertFalse(dataProvider.isCached(3));
    }

    function testTrackStatusUpdate() public {
        CruratedBase.Status memory status = CruratedBase.Status({
            statusId: certifiedStatusId,
            timestamp: block.timestamp,
            reason: "Test certification"
        });

        dataProvider.trackStatusUpdate(1, status);

        // Cache should be invalidated
        assertFalse(dataProvider.isCached(1));
    }

    function testTrackMetadataUpdate() public {
        // First fetch to cache
        dataProvider.getTokenData(1, owner);

        // Track metadata update
        dataProvider.trackMetadataUpdate(1);

        // Cache should be invalidated
        assertFalse(dataProvider.isCached(1));
    }

    /*//////////////////////////////////////////////////////////////
                        QUERY EXECUTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testExecuteQueryBasic() public view {
        IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
            filters: new bytes32[](0),
            filterParams: new bytes[](0),
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.ASC,
            offset: 0,
            limit: 10,
            owner: owner
        });

        IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(params);

        assertEq(result.totalCount, 5);
        assertEq(result.tokenData.length, 5);
        assertFalse(result.hasMore);
    }

    function testExecuteQueryWithPagination() public view {
        IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
            filters: new bytes32[](0),
            filterParams: new bytes[](0),
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.ASC,
            offset: 0,
            limit: 3,
            owner: owner
        });

        IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(params);

        assertEq(result.totalCount, 5);
        assertEq(result.tokenData.length, 3);
        assertTrue(result.hasMore);
        assertEq(result.tokenData[0].tokenId, 1);
        assertEq(result.tokenData[1].tokenId, 2);
        assertEq(result.tokenData[2].tokenId, 3);
    }

    function testExecuteQuerySecondPage() public view {
        IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
            filters: new bytes32[](0),
            filterParams: new bytes[](0),
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.ASC,
            offset: 3,
            limit: 3,
            owner: owner
        });

        IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(params);

        assertEq(result.totalCount, 5);
        assertEq(result.tokenData.length, 2); // Only 2 remaining
        assertFalse(result.hasMore);
        assertEq(result.tokenData[0].tokenId, 4);
        assertEq(result.tokenData[1].tokenId, 5);
    }

    function testExecuteQueryWithFilters() public {
        bytes32[] memory filters = new bytes32[](1);
        filters[0] = filterManager.FILTER_BY_OWNER();

        bytes[] memory params = new bytes[](1);
        params[0] = abi.encode(owner);

        IQueryExecutor.QueryParams memory queryParams = IQueryExecutor.QueryParams({
            filters: filters,
            filterParams: params,
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.ASC,
            offset: 0,
            limit: 10,
            owner: owner
        });

        IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(queryParams);

        assertEq(result.totalCount, 5);
        assertEq(result.tokenData.length, 5);
    }

    function testExecuteQueryDescendingSort() public view {
        IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
            filters: new bytes32[](0),
            filterParams: new bytes[](0),
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.DESC,
            offset: 0,
            limit: 10,
            owner: owner
        });

        IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(params);

        assertEq(result.totalCount, 5);
        assertEq(result.tokenData.length, 5);
        assertEq(result.tokenData[0].tokenId, 5);
        assertEq(result.tokenData[4].tokenId, 1);
    }

    function testGetFilteredIds() public view {
        IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
            filters: new bytes32[](0),
            filterParams: new bytes[](0),
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.ASC,
            offset: 0,
            limit: 10,
            owner: owner
        });

        uint256[] memory ids = queryExecutor.getFilteredIds(params);

        assertEq(ids.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(ids[i], i + 1);
        }
    }

    function testFetchDataForIds() public view {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 3;
        tokenIds[2] = 5;

        IDataProvider.TokenData[] memory data = queryExecutor.fetchDataForIds(
            tokenIds,
            owner
        );

        assertEq(data.length, 3);
        assertEq(data[0].tokenId, 1);
        assertEq(data[1].tokenId, 3);
        assertEq(data[2].tokenId, 5);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCompleteWorkflow() public {
        // Step 1: Query with filters and sorting
        bytes32[] memory filters = new bytes32[](1);
        filters[0] = filterManager.FILTER_BY_OWNER();

        bytes[] memory params = new bytes[](1);
        params[0] = abi.encode(owner);

        IQueryExecutor.QueryParams memory queryParams = IQueryExecutor.QueryParams({
            filters: filters,
            filterParams: params,
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.DESC,
            offset: 0,
            limit: 3,
            owner: owner
        });

        // Execute query
        IQueryExecutor.QueryResult memory result = queryExecutor.executeQuery(queryParams);

        // Verify results
        assertEq(result.totalCount, 5);
        assertEq(result.tokenData.length, 3);
        assertTrue(result.hasMore);

        // Verify sorting (descending)
        assertEq(result.tokenData[0].tokenId, 5);
        assertEq(result.tokenData[1].tokenId, 4);
        assertEq(result.tokenData[2].tokenId, 3);

        // Verify data completeness
        assertEq(result.tokenData[0].cid, "QmToken5");
        assertEq(result.tokenData[0].balance, 5);
    }

    function testTwoStepQueryPattern() public view {
        // Step 1: Get filtered IDs
        IQueryExecutor.QueryParams memory params = IQueryExecutor.QueryParams({
            filters: new bytes32[](0),
            filterParams: new bytes[](0),
            sortField: ISortManager.SortField.TOKEN_ID,
            sortDirection: ISortManager.SortDirection.ASC,
            offset: 0,
            limit: 10,
            owner: owner
        });

        uint256[] memory ids = queryExecutor.getFilteredIds(params);
        assertEq(ids.length, 5);

        // Step 2: Fetch data for those IDs
        IDataProvider.TokenData[] memory data = queryExecutor.fetchDataForIds(ids, owner);
        assertEq(data.length, 5);

        // Verify data matches
        for (uint256 i = 0; i < 5; i++) {
            assertEq(data[i].tokenId, ids[i]);
        }
    }
}
