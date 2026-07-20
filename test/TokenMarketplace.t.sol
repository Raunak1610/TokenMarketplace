// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.34;  

import {Test} from "forge-std/Test.sol";
import {TokenMarketplace} from "../src/TokenMarketplace.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import  "forge-std/console.sol";
import {OrderInfo} from "../src/types/Trade.sol";


contract TokenMarketplaceTest is Test {
    uint256 constant DEFAULT_NUMBER_OF_MINTED_TOKENS = 1000;
    TokenMarketplace public tokenMarketplace;
    ERC20Mock public erc20Mock;

    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");

    error TokenMarketplace_ZeroNumberofTokens(uint256 numberofTokens);
    error TokenMarketplace_InsufficientEthPayment(uint256 expectedPayment,uint256 actualPayment);
    error TokenMarketplace_InsufficientTokenBalance(uint256 actualTokens,uint256 expectedTokens);
    error TokenMarketplace_InsufficientAllowance(uint256 allowedTokens,uint256 tokensToTransfer);

    function _mintSLVTokens(address addr, uint256 numberOfTokensToMint) internal {  // to mint the slvtoken to the address
        erc20Mock.mint(addr, numberOfTokensToMint);
    }

   function _approveTokens(address tokenOwner,address spender,uint256 approvalAmount) internal{   // If the seller want that if it's tokens  was handle by smartcontrat
        vm.prank(tokenOwner);
        erc20Mock.approve(spender, approvalAmount);
    }

    function setUp() public{ // setup function is caled before ever test function 
        address owner=makeAddr("owner");// I can write anything instead of owner and it will give me address
        erc20Mock=new ERC20Mock();
        tokenMarketplace = new TokenMarketplace(address(erc20Mock),owner);    
        _mintSLVTokens(address(tokenMarketplace), DEFAULT_NUMBER_OF_MINTED_TOKENS);
        //erc20Mock.mint(address(tokenMarketplace),1000); // minting the tokens to marketplace address
    }

    function testBuyTokensFromMarketplace() public{  // unit testing
        //ARRANGE 
        uint256 tokensToBuyFromMarketplace = 2;
        uint256 tokenPrice = tokenMarketplace.TOKEN_PRICE();//1 ether
        uint256 totalPriceToPayToBuyTokens = tokensToBuyFromMarketplace*tokenPrice;// 2 eth
        uint256 tokenMarketplaceEthBalanceBefore = address(tokenMarketplace).balance;//0 Eth
        // console.log(tokenMarketplaceEthBalanceBefore);
        uint256 buyerEthBalanceBefore = erc20Mock.balanceOf(buyer);
        
        //ACT
        vm.prank(buyer);
        vm.deal(buyer, 10 ether); // giving the buyer 10 eth
        tokenMarketplace.buyTokensFromMarketplace{value: totalPriceToPayToBuyTokens}(tokensToBuyFromMarketplace);
        // console.log(tokenMarketplaceEthBalanceAfter);
        uint256 tokenMarketplaceEthBalanceAfter = address(tokenMarketplace).balance;//2 ETH
        uint256 buyerEthBalanceAfter = erc20Mock.balanceOf(buyer);
        
        //ASSERT
        assertEq(tokenMarketplaceEthBalanceAfter-tokenMarketplaceEthBalanceBefore, totalPriceToPayToBuyTokens);
        assertEq(buyerEthBalanceAfter-buyerEthBalanceBefore,tokensToBuyFromMarketplace);

    }

    function test_RevertsWhenNumberOfTokensToBuyFromMarketplaceIsZero() public{ // sad path testing
        uint256 tokensToBuyFromMarketplace = 0;
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);

        vm.expectRevert(abi.encodeWithSelector(TokenMarketplace_ZeroNumberofTokens.selector,tokensToBuyFromMarketplace));// here selector is used to get the function hash code of the function and abi.encode is used to encode the data in bytes
        tokenMarketplace.buyTokensFromMarketplace{value:1 ether}(tokensToBuyFromMarketplace);

    }

    function test_FuzzBuyTokensFromMarketplace(uint256 tokensToBuyFromMarketplace) public{ // in Fuzz testing earlier only at 2ether we're testing but now tis can test at any number of ether 1,2,3,....
        // go to foundary.toml in dasboard
        //ARRANGE 
        // vm.assume(tokensToBuyFromMarketplace<1000);
        tokensToBuyFromMarketplace=bound(tokensToBuyFromMarketplace,1,1000); // this is used to bound the value of tokensToBuyFromMarketplace between 1 and 1000
        uint256 tokenPrice = tokenMarketplace.TOKEN_PRICE();//1 ether
        uint256 totalPriceToPayToBuyTokens = tokensToBuyFromMarketplace*tokenPrice;// 2 eth
        uint256 tokenMarketplaceEthBalanceBefore = address(tokenMarketplace).balance;//0 Eth
        // console.log(tokenMarketplaceEthBalanceBefore);
        uint256 buyerEthBalanceBefore = erc20Mock.balanceOf(buyer);
        
        //ACT
        vm.prank(buyer);
        vm.deal(buyer,totalPriceToPayToBuyTokens); // giving the buyer 10 eth
        tokenMarketplace.buyTokensFromMarketplace{value: totalPriceToPayToBuyTokens}(tokensToBuyFromMarketplace);
        // console.log(tokenMarketplaceEthBalanceAfter);
        uint256 tokenMarketplaceEthBalanceAfter = address(tokenMarketplace).balance;//2 ETH
        uint256 buyerEthBalanceAfter = erc20Mock.balanceOf(buyer);
        
        //ASSERT
        assertEq(tokenMarketplaceEthBalanceAfter-tokenMarketplaceEthBalanceBefore, totalPriceToPayToBuyTokens);
        assertEq(buyerEthBalanceAfter-buyerEthBalanceBefore,tokensToBuyFromMarketplace);

    } 

     function test_fuzz_buyTokensFromMarketplace_revertsWrongEth(
        uint256 numberOfTokensToBuy,
        uint256 ethAmount
    ) public {
        numberOfTokensToBuy = bound(numberOfTokensToBuy, 1, 1000);

        uint256 correctEthAmount = numberOfTokensToBuy * 1 ether;

        ethAmount = bound(ethAmount, 0, 10_000 ether);
        vm.assume(ethAmount != correctEthAmount);

        vm.deal(buyer, ethAmount);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(TokenMarketplace_InsufficientEthPayment.selector, correctEthAmount, ethAmount)
        );
        tokenMarketplace.buyTokensFromMarketplace{value: ethAmount}(numberOfTokensToBuy);
    }

    function test_fuzz_buyTokensFromMarketplace_revertsWhenAmountExceedsInventory(
        uint256 numberOfTokensToBuy
    ) public {
        numberOfTokensToBuy = bound(numberOfTokensToBuy, DEFAULT_NUMBER_OF_MINTED_TOKENS + 1, 10_000);
        uint256 ethAmount = numberOfTokensToBuy * 1 ether;
        vm.deal(buyer, ethAmount);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenMarketplace_InsufficientTokenBalance.selector,
                DEFAULT_NUMBER_OF_MINTED_TOKENS,
                numberOfTokensToBuy
            )
        );
        tokenMarketplace.buyTokensFromMarketplace{value: ethAmount}(numberOfTokensToBuy);
    }

     function test_fuzz_createSellOrder(uint256 numberOfTokensToSell,uint256 numberOfTokensToApprove,uint256 numberOfTokensToMint) public {
        numberOfTokensToMint = bound(numberOfTokensToMint, 1, 1000);
        numberOfTokensToApprove = bound(numberOfTokensToApprove, 1, numberOfTokensToMint);
        numberOfTokensToSell = bound(numberOfTokensToSell, 1, numberOfTokensToApprove);
         _mintSLVTokens(seller, numberOfTokensToMint);// mint tokens to seller
         _approveTokens(seller,address(tokenMarketplace),numberOfTokensToApprove);// tokenmarketplace is aboutu to spend tokens

        vm.prank(seller);
        tokenMarketplace.createSellOrder(numberOfTokensToSell);

        uint256 createdOrderId = tokenMarketplace.getNumberOfCreatedOrders() - 1;
        OrderInfo memory order = tokenMarketplace.getCreatedOrderById(createdOrderId);
        
        assertEq(createdOrderId, order.orderId);
        assertEq(seller, order.seller);
        assertEq(true, order.isActive);
        assertEq(numberOfTokensToSell, order.numberOfTokensToSell);
        assertEq(erc20Mock.allowance(seller, address(tokenMarketplace)), numberOfTokensToApprove - numberOfTokensToSell);
    }

    function test_fuzz_createSellOrder_revertsWhenSellAmountExceedsBalance(
        uint256 numberOfTokensToSell,
        uint256 numberOfTokensToMint
    ) public {
        numberOfTokensToMint = bound(numberOfTokensToMint, 0, 1000);
        numberOfTokensToSell = bound(numberOfTokensToSell, numberOfTokensToMint + 1, 10_000);
        _mintSLVTokens(seller, numberOfTokensToMint);

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenMarketplace_InsufficientTokenBalance.selector,
                numberOfTokensToMint,
                numberOfTokensToSell
            )
        );
        tokenMarketplace.createSellOrder(numberOfTokensToSell);
    }

    function test_fuzz_createSellOrder_revertsWhenSellAmountExceedsAllowance(
        uint256 numberOfTokensToSell,
        uint256 numberOfTokensToApprove,
        uint256 numberOfTokensToMint
    ) public {  
        numberOfTokensToMint = bound(numberOfTokensToMint, 1, 1000);
        numberOfTokensToSell = bound(numberOfTokensToSell, 1, numberOfTokensToMint);
        numberOfTokensToApprove = bound(numberOfTokensToApprove, 0, numberOfTokensToSell - 1);
        _mintSLVTokens(seller, numberOfTokensToMint);
        _approveTokens(seller,address(tokenMarketplace),numberOfTokensToApprove);

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenMarketplace_InsufficientAllowance.selector,
                numberOfTokensToApprove,
                numberOfTokensToSell
            )
        );
        tokenMarketplace.createSellOrder(numberOfTokensToSell);
    }

    
    function test_fuzz_buyTokenFromSeller(uint256 numberOfTokensToSell,uint256 numberOfTokensToApprove,uint256 numberOfTokensToMint,uint256 numberOfTokensToBuy) public {
        numberOfTokensToMint = bound(numberOfTokensToMint, 1, 1000);
        numberOfTokensToApprove = bound(numberOfTokensToApprove, 1, numberOfTokensToMint);
        numberOfTokensToSell = bound(numberOfTokensToSell, 1, numberOfTokensToApprove);
        numberOfTokensToBuy = bound(numberOfTokensToBuy,1,numberOfTokensToSell);
        _mintSLVTokens(seller, numberOfTokensToMint);
        _approveTokens(seller,address(tokenMarketplace),numberOfTokensToApprove);
        vm.prank(seller);
        tokenMarketplace.createSellOrder(numberOfTokensToSell);
        uint256 orderId = tokenMarketplace.getNumberOfCreatedOrders() - 1;
        uint256 ethAmount = numberOfTokensToBuy * 1 ether;
        uint256 buyerTokenBeforeBalance = erc20Mock.balanceOf(buyer);//0
 
        vm.deal(buyer, ethAmount);//10
        vm.prank(buyer);
        tokenMarketplace.buyTokensFromSellOrderCreated{value: ethAmount}(orderId, numberOfTokensToBuy);//6
    
        uint256 buyerTokenAfterBalance = erc20Mock.balanceOf(buyer);//4 
        OrderInfo memory order = tokenMarketplace.getCreatedOrderById(orderId);
        assertEq(buyerTokenAfterBalance - buyerTokenBeforeBalance, numberOfTokensToBuy);
        assertEq(order.numberOfTokensToSell, numberOfTokensToSell - numberOfTokensToBuy);
        assertEq(order.isActive, numberOfTokensToBuy < numberOfTokensToSell);
    }

    function test_fuzz_buyTokensFromSeller_revertsWrongEth(
        uint256 numberOfTokensToSell,
        uint256 numberOfTokensToApprove,
        uint256 numberOfTokensToMint,
        uint256 numberOfTokensToBuy,
        uint256 ethAmount
    ) public {
        numberOfTokensToMint = bound(numberOfTokensToMint, 1, 1000);
        numberOfTokensToApprove = bound(numberOfTokensToApprove, 1, numberOfTokensToMint);
        numberOfTokensToSell = bound(numberOfTokensToSell, 1, numberOfTokensToApprove);
        numberOfTokensToBuy = bound(numberOfTokensToBuy, 1, numberOfTokensToSell);
        uint256 correctEthAmount = numberOfTokensToBuy * 1 ether;
        ethAmount = bound(ethAmount, 0, 10_000 ether);
        vm.assume(ethAmount != correctEthAmount);

        _mintSLVTokens(seller, numberOfTokensToMint);
        _approveTokens(seller,address(tokenMarketplace),numberOfTokensToApprove);
        vm.prank(seller);
        tokenMarketplace.createSellOrder(numberOfTokensToSell);
        uint256 orderId = tokenMarketplace.getNumberOfCreatedOrders() - 1;
        vm.deal(buyer, ethAmount);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(TokenMarketplace_InsufficientEthPayment.selector,correctEthAmount, ethAmount)
        );
        tokenMarketplace.buyTokensFromSellOrderCreated{value: ethAmount}(orderId, numberOfTokensToBuy);
    }

}