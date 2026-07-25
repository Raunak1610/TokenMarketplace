// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.34;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrderInfo} from "./types/Trade.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenMarketplace is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 immutable SLV_TOKEN;

    uint256 private constant TOKEN_PRICE = 1 ether;
    uint256 private reseverdOrderedTokens;
    uint256 private nextOrderId;

    mapping(uint256 => OrderInfo) private orders;

    bool dummy = true;

    error TokenMarketplace_ZeroNumberOfTokens(uint256 numberOfTokens);
    error TokenMarketplace_InsufficientEthPayment(uint256 expectedPayment, uint256 actualPayment);
    error TokenMarketplace_InsufficientTokenBalance(uint256 expectedToken, uint256 actualToken);
    error TokenMarketplace_InsufficientAllowance(uint256 allowedTokens, uint256 tokensToTransfer);
    error TokenMarketplace_OrderIsNotActive(uint256 orderId);
    error TokenMarketplace_NotEnoughTokensInOrder(uint256 expectedTokens, uint256 actualTokens);
    error TokenMarketplace_EthTransferFailed();
    error TokenMarketplace_InvalidOrderId();
    error TokenMarketplace_UnauthorizedSeller(address caller, uint256 orderId);
    error TokenMarkeplace_InvalidOwner();

    event BuyTokens(address indexed buyer, uint256 indexed numberOfTokensBought);
    event SellOrderCreated(uint256 indexed orderId, address indexed seller, uint256 indexed numberOfTokensToSell);
    event SellOrderCancelled(uint256 indexed orderId, address indexed seller, uint256 indexed numberOfTokensCancelled);
    event BuyTokensFromSellOrderCreated(
        uint256 indexed orderId, address indexed buyer, address indexed seller, uint256 numberOfTokensBought
    );

    constructor(address _slvToken, address _owner) Ownable(_owner) {
        SLV_TOKEN = IERC20(_slvToken);
    }

    function buyTokensFromMarketplace(uint256 numberOfTokens) external payable whenNotPaused nonReentrant {
        _revertIfZeroTokenAmount(numberOfTokens);
        _revertIfIncorrectEthPayment(numberOfTokens);
        _revertIfTokenBalanceOfMarketplaceIsLow(numberOfTokens);

        SLV_TOKEN.safeTransfer(msg.sender, numberOfTokens);
        dummy = false;

        emit BuyTokens(msg.sender, numberOfTokens);
    }

    function _revertIfTokenBalanceOfMarketplaceIsLow(uint256 numberOfTokens) internal view {
        if (SLV_TOKEN.balanceOf(address(this)) < numberOfTokens) {
            revert TokenMarketplace_InsufficientTokenBalance(SLV_TOKEN.balanceOf(address(this)), numberOfTokens);
        }
    }

    function createSellOrder(uint256 numberOfTokensToSell) external whenNotPaused nonReentrant {
        _revertIfZeroTokenAmount(numberOfTokensToSell);
        _revertIfInsufficientSellerTokenBalance(numberOfTokensToSell);
        _revertIfAllowanceNotEnough(numberOfTokensToSell);

        SLV_TOKEN.safeTransferFrom(msg.sender, address(this), numberOfTokensToSell);

        uint256 orderId = nextOrderId;
        _recordSellOrder(numberOfTokensToSell);

        nextOrderId++;
        _increaseReservedOrderedTokens(numberOfTokensToSell);

        emit SellOrderCreated(orderId, msg.sender, numberOfTokensToSell);
    }

    function _revertIfInsufficientSellerTokenBalance(uint256 numberOfTokens) internal view {
        uint256 tokenBalance = SLV_TOKEN.balanceOf(msg.sender);
        if (numberOfTokens > tokenBalance) {
            revert TokenMarketplace_InsufficientTokenBalance(tokenBalance, numberOfTokens);
        }
    }

    function _revertIfAllowanceNotEnough(uint256 numberOfTokens) internal view {
        uint256 allowance = SLV_TOKEN.allowance(msg.sender, address(this));
        if (allowance < numberOfTokens) revert TokenMarketplace_InsufficientAllowance(allowance, numberOfTokens);
    }

    function _recordSellOrder(uint256 numberOfTokensToSell) internal {
        OrderInfo memory order = OrderInfo({
            orderId: nextOrderId, seller: msg.sender, numberOfTokensToSell: numberOfTokensToSell, isActive: true
        });

        orders[nextOrderId] = order;
    }

    function _increaseReservedOrderedTokens(uint256 numberOfTokens) internal {
        reseverdOrderedTokens += numberOfTokens;
    }

    function buyTokensFromSellOrder(uint256 orderId, uint256 numberOfTokensToBuy)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        _revertIfInvalidOrderId(orderId);
        _revertIfZeroTokenAmount(numberOfTokensToBuy);
        _revertIfIncorrectEthPayment(numberOfTokensToBuy);

        OrderInfo storage order = orders[orderId];

        _revertIfOrderIsNotActive(order);
        _revertIfOrderHasNotEnoughTokens(order, numberOfTokensToBuy);

        _updateOrderAfterPurchase(order, numberOfTokensToBuy);

        SLV_TOKEN.safeTransfer(msg.sender, numberOfTokensToBuy);

        _sendEthToSeller(order.seller, msg.value);

        emit BuyTokensFromSellOrderCreated(orderId, msg.sender, order.seller, numberOfTokensToBuy);
    }

    function _revertIfOrderIsNotActive(OrderInfo storage order) internal view {
        if (!order.isActive) revert TokenMarketplace_OrderIsNotActive(order.orderId);
    }

    function _revertIfOrderHasNotEnoughTokens(OrderInfo storage order, uint256 numberOfTokensToBuy) internal view {
        if (order.numberOfTokensToSell < numberOfTokensToBuy) {
            revert TokenMarketplace_NotEnoughTokensInOrder(order.numberOfTokensToSell, numberOfTokensToBuy);
        }
    }

    function _updateOrderAfterPurchase(OrderInfo storage order, uint256 numberOfTokensToBuy) internal {
        uint256 remainingTokens = order.numberOfTokensToSell - numberOfTokensToBuy;

        order.numberOfTokensToSell = remainingTokens;
        _decreaseReservedOrderedTokens(numberOfTokensToBuy);

        if (remainingTokens == 0) order.isActive = false;
    }

    function _sendEthToSeller(address seller, uint256 amount) internal {
        (bool success,) = seller.call{value: amount}("");
        if (!success) revert TokenMarketplace_EthTransferFailed();
    }

    function _revertIfZeroTokenAmount(uint256 numberOfTokens) internal pure {
        if (numberOfTokens == 0) revert TokenMarketplace_ZeroNumberOfTokens(numberOfTokens);
    }

    function _revertIfIncorrectEthPayment(uint256 numberOfTokens) internal view {
        if (numberOfTokens * TOKEN_PRICE != msg.value) {
            revert TokenMarketplace_InsufficientEthPayment(numberOfTokens * TOKEN_PRICE, msg.value);
        }
    }

    function cancelSellOrder(uint256 orderId) external nonReentrant {
        _revertIfInvalidOrderId(orderId);
        OrderInfo storage order = orders[orderId];

        _revertIfUnauthorizedSeller(order, orderId);
        _revertIfOrderIsNotActive(order);

        uint256 numberOfTokensToCancel = order.numberOfTokensToSell;
        _recordSellOrderCancellation(order);
        _decreaseReservedOrderedTokens(numberOfTokensToCancel);

        SLV_TOKEN.safeTransfer(order.seller, numberOfTokensToCancel);

        emit SellOrderCancelled(orderId, msg.sender, numberOfTokensToCancel);
    }

    function _revertIfInvalidOrderId(uint256 orderId) internal view {
        uint256 totalNumberOfCreatedOrder = getNumberOfCreatedOrders();
        if (orderId >= totalNumberOfCreatedOrder) revert TokenMarketplace_InvalidOrderId();
    }

    function _revertIfUnauthorizedSeller(OrderInfo storage order, uint256 orderId) internal view {
        if (order.seller != msg.sender) revert TokenMarketplace_UnauthorizedSeller(msg.sender, orderId);
    }

    function _recordSellOrderCancellation(OrderInfo storage order) internal {
        order.isActive = false;
        order.numberOfTokensToSell = 0;
    }

    function _decreaseReservedOrderedTokens(uint256 numberOfTokens) internal {
        reseverdOrderedTokens -= numberOfTokens;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getAvailableMarketplaceTokens() external view returns (uint256) {
        return SLV_TOKEN.balanceOf(address(this));
    }

    function getNumberOfCreatedOrders() public view returns (uint256) {
        return nextOrderId;
    }

    function getCreatedOrderById(uint256 orderId) external view returns (OrderInfo memory) {
        return orders[orderId];
    }

    function getAllOrders() external view returns (OrderInfo[] memory) {
        OrderInfo[] memory orderList = new OrderInfo[](nextOrderId);

        for (uint256 i = 0; i < nextOrderId; i++) {
            orderList[i] = orders[i];
        }
        return orderList;
    }

    function getTokenPrice() external pure returns (uint256) {
        return TOKEN_PRICE;
    }
}