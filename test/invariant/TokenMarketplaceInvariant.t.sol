// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.34;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TokenMarketplace} from "../../src/TokenMarketplace.sol";
import {OrderInfo} from "../../src/types/Trade.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {MarketplaceHandler} from "./TokenMarketplaceHandler.t.sol";

contract SLVTokenMarketplaceInvariantTest is StdInvariant, Test {
    ERC20Mock token;
    TokenMarketplace marketplace;
    MarketplaceHandler handler;

    address owner = makeAddr("owner");

    uint256 constant INITIAL_MARKETPLACE_TOKENS = 1000;

    function setUp() public {
        token = new ERC20Mock();
        marketplace = new TokenMarketplace(address(token), owner);

        token.mint(address(marketplace), INITIAL_MARKETPLACE_TOKENS);

        handler = new MarketplaceHandler(token, marketplace);

        bytes4[] memory selectors = new bytes4[](2);

        selectors[0] = MarketplaceHandler.buyFromMarketplace.selector;
        selectors[1] = MarketplaceHandler.createSellOrder.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_marketplaceTokenBalanceIsAccountedFor() public view {
        uint256 expectedBalance =
            INITIAL_MARKETPLACE_TOKENS - handler.marketplaceTokensBought() + handler.openOrderTokens();

        assertEq(token.balanceOf(address(marketplace)), expectedBalance);
    }

    function invariant_marketplaceCanCoverOpenOrders() public view {
        assertGe(token.balanceOf(address(marketplace)), handler.openOrderTokens());
    }

    function invariant_marketplaceEthBalanceOnlyFromDirectSales() public view {
        assertEq(address(marketplace).balance, handler.marketplaceTokensBought() * 1 ether);
    }

    function invariant_ordersHaveConsistentActiveState() public view {
        uint256 orderCount = marketplace.getNumberOfCreatedOrders();

        for (uint256 i = 0; i < orderCount; i++) {
            OrderInfo memory order = marketplace.getCreatedOrderById(i);

            if (order.isActive) {
                assertGt(order.numberOfTokensToSell, 0);
            } else {
                assertEq(order.numberOfTokensToSell, 0);
            }
        }
    }
}