// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.34;
import {Test} from "forge-std/Test.sol";
import {TokenMarketplace} from "../../src/TokenMarketplace.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TokenMarketplaceUnitTest is Test {
    uint256 constant DEFAULT_NUMBER_OF_MINTED_TOKENS = 1000;
    TokenMarketplace public tokenMarketplace;
    ERC20Mock public erc20Mock;

    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");

    error TokenMarketplace_ZeroNumberOfTokens(uint256 numberOfTokens);
    error TokenMarketplace_InsufficientEthPayment(uint256 expectedPayment, uint256 actualPayment);
    error TokenMarketplace_InsufficientTokenBalance(uint256 actualTokens, uint256 expectedTokens);
    error TokenMarketplace_InsufficientAllowance(uint256 allowedTokens, uint256 tokensToTransfer);

    function _mintSlvTokens(address addr, uint256 numberOfTokensToMint) internal {
        erc20Mock.mint(addr, numberOfTokensToMint);
    }

    function _approveTokens(address tokenOwner, address spender, uint256 approvalAmount) internal {
        vm.prank(tokenOwner);
        erc20Mock.approve(spender, approvalAmount);
    }

    function setUp() public {
        address owner = makeAddr("owner");
        erc20Mock = new ERC20Mock();
        tokenMarketplace = new TokenMarketplace(address(erc20Mock), owner);
        _mintSlvTokens(address(tokenMarketplace), DEFAULT_NUMBER_OF_MINTED_TOKENS);
    }

    function testBuyTokensFromMarketplace() public {
        uint256 tokensToBuyFromMarketplace = 2;
        uint256 tokenPrice = tokenMarketplace.getTokenPrice();
        uint256 totalPriceToPayToBuyTokens = tokensToBuyFromMarketplace * tokenPrice;
        uint256 tokenMarketplaceEthBalanceBefore = address(tokenMarketplace).balance;

        uint256 tokenBalanceOfBuyerBefore = erc20Mock.balanceOf(buyer);

        vm.prank(buyer);
        vm.deal(buyer, 10 ether);

        tokenMarketplace.buyTokensFromMarketplace{value: totalPriceToPayToBuyTokens}(tokensToBuyFromMarketplace);

        uint256 tokenMarketplaceEthBalanceAfter = address(tokenMarketplace).balance;
        uint256 tokenBalanceOfBuyerAfter = erc20Mock.balanceOf(buyer);

        assertEq(tokenMarketplaceEthBalanceAfter - tokenMarketplaceEthBalanceBefore, totalPriceToPayToBuyTokens);
        assertEq(tokenBalanceOfBuyerAfter - tokenBalanceOfBuyerBefore, tokensToBuyFromMarketplace);
    }

    function test_RevertsWhenNumberOfTokensToBuyFromMarkeplaceIsZero() public {
        uint256 tokensToBuyFromMarketplace = 0;

        vm.deal(buyer, 10 ether);
        vm.prank(buyer);

        vm.expectRevert(
            abi.encodeWithSelector(TokenMarketplace_ZeroNumberOfTokens.selector, tokensToBuyFromMarketplace)
        );
        tokenMarketplace.buyTokensFromMarketplace{value: 1 ether}(tokensToBuyFromMarketplace);
    }

    function testBuyTokensFromMarketplace_gas() public {
        uint256 tokensToBuyFromMarketplace = 2;
        uint256 tokenPrice = tokenMarketplace.getTokenPrice();
        uint256 totalPriceToPayToBuyTokens = tokensToBuyFromMarketplace * tokenPrice;

        vm.prank(buyer);
        vm.deal(buyer, 10 ether);

        tokenMarketplace.buyTokensFromMarketplace{value: totalPriceToPayToBuyTokens}(tokensToBuyFromMarketplace);

        vm.snapshotGasLastCall("buy tokens from marketplace");
    }
}
