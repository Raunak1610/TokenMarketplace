// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.34;

import {Test} from "forge-std/Test.sol";
import {TokenMarketplace} from "../../src/TokenMarketplace.sol";
import {OrderInfo} from "../../src/types/Trade.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MarketplaceHandler is Test {
    ERC20Mock public token;
    TokenMarketplace public marketplace;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

    uint256 public marketplaceTokensBought;
    uint256 public openOrderTokens;

    constructor(ERC20Mock _token, TokenMarketplace _marketplace) {
        token = _token;
        marketplace = _marketplace;
    }

    function buyFromMarketplace(uint256 amount) public {
        uint256 inventory = marketplace.getAvailableMarketplaceTokens();

        if (inventory == 0) return;
        amount = bound(amount, 1, inventory);

        vm.deal(buyer, amount * 1 ether);
        vm.prank(buyer);
        marketplace.buyTokensFromMarketplace{value: amount * 1 ether}(amount);

        marketplaceTokensBought += amount;
    }

    function createSellOrder(uint256 amount) public {
        uint256 sellerBalance = token.balanceOf(seller);
        if (sellerBalance == 0) return;

        amount = bound(amount, 1, sellerBalance);

        vm.startPrank(seller);
        token.approve(address(marketplace), amount);
        marketplace.createSellOrder(amount);
        vm.stopPrank();

        openOrderTokens += amount;
    }

    function buyFromSeller(uint256 orderSeed, uint256 amount) public {
        uint256 orderCount = marketplace.getNumberOfCreatedOrders();
        if (orderCount == 0) return;

        uint256 orderId = bound(orderSeed, 0, orderCount - 1);

        OrderInfo memory order = marketplace.getCreatedOrderById(orderId);

        if (!order.isActive || order.numberOfTokensToSell == 0) return;

        amount = bound(amount, 1, order.numberOfTokensToSell);

        vm.deal(buyer, amount * 1 ether);
        vm.prank(buyer);
        marketplace.buyTokensFromSellOrder{value: amount * 1 ether}(orderId, amount);
        openOrderTokens -= amount;
    }

    function cancelSellOrder(uint256 orderSeed) public {
        uint256 orderCount = marketplace.getNumberOfCreatedOrders();
        if (orderCount == 0) return;

        uint256 orderId = bound(orderSeed, 0, orderCount - 1);
        OrderInfo memory order = marketplace.getCreatedOrderById(orderId);

        if (!order.isActive || order.numberOfTokensToSell == 0) return;

        vm.prank(seller);
        marketplace.cancelSellOrder(orderId);

        openOrderTokens -= order.numberOfTokensToSell;
    }
}