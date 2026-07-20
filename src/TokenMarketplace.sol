// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.34;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";// interface is used to get the power of IERC20 to slvToken and we can use all the functions of IERC20 in slvToken
import{Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrderInfo} from "./types/Trade.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenMarketplace is Ownable,Pausable,ReentrancyGuard{
    using SafeERC20 for IERC20; // this is used to get the power of safeERC20 to IERC20
    //state variable
    uint256 public constant TOKEN_PRICE = 1 ether;  // uint means unsigned integer and only positive value can be assigned
    uint256 private reservedTokens=256;
    IERC20 public slvToken;

    mapping(uint256=>OrderInfo) private orders;
    OrderInfo[] private orderList;//dynamic datatype because the data size is not fixed here and it takes more gas
    uint256 private nextOrderId; // initial value of this is bydefault is 0 because we do nto assign any value
    
    error TokenMarketplace_ZeroNumberofTokens(uint256 numberofTokens);
    error TokenMarketplace_InsufficientEthPayment(uint256 ExpectedPayment,uint256 ActualPayment);
    error TokenMarketplace_InsufficientTokenBalance(uint256 ExpectedTokens,uint256 ActualTokens);
    error TokenMarketplace_InsufficentSellerTokenBalance(uint256 AvailableTokens,uint256 RequiredTokens); 
    error TokenMarketplace_InsufficientAllowance(uint256 allowedTokens,uint256 tokenstoTransfer);
    error TokenMarketplace_OrderIsNotActive(uint256  orderId);
    error TokenMarketplace_NotEnoughTokensInOrder(uint256 AvailableTokens,uint256 RequiredTokens);
    error TokenMarketplace_EthTransferFailed();
    error SLVTokenMarketPlace_InvalidOredrId();
    error TokenMarketPlace_UnauthorisedSeller(address caller,uint256 orderId);
    error TokenMarketplace_InvalidOwner();

    event buyTokens(address indexed buyer,uint256 indexed numberofTokensBought); 

    // int external i can't use them in contract brt i can use them out of the extrenal but
    // i wnat the ether from contract so i made the function which give me ether and i use 'payable' to pay me the ether

    constructor(address _slvToken,address _owner)Ownable(_owner){
        slvToken=IERC20 (_slvToken); // this method is used to get all the powers to slvtoken from IERC20 
    }

    function _getSlvTokenBalanceofMarketPlace() internal view returns(uint256){
        return slvToken.balanceOf(address(this)); // address(this) is used as the address of marketplace and use this 
    }
    function _isNumberofTokensZero(uint256 numberofTokens) internal pure{
        // if in a internal function we are not using the state variable so we use 'pure' otherwise we use 'view'
        if(numberofTokens==0){
            revert TokenMarketplace_ZeroNumberofTokens(numberofTokens); //it is used to give the error in terminal
        }    
    }
 
    function _checkEthPayment(uint256 numberofTokens) internal view{
        if(numberofTokens*TOKEN_PRICE!=msg.value){
            revert TokenMarketplace_InsufficientEthPayment(numberofTokens*TOKEN_PRICE,msg.value);
        }
    }
    function buyTokensFromMarketplace(uint256 numberofTokens)external payable whenNotPaused nonReentrant{
        _isNumberofTokensZero(numberofTokens);
        _checkEthPayment(numberofTokens);

        if(_getSlvTokenBalanceofMarketPlace()<numberofTokens){// to check the balance of token markte place
            revert TokenMarketplace_InsufficientTokenBalance(numberofTokens,_getSlvTokenBalanceofMarketPlace());
        }

        slvToken.safeTransfer(msg.sender,numberofTokens); // to send the token to buyer
        emit buyTokens(msg.sender, numberofTokens);

    }

    function _checkSellerSlvTokenBalance(address account,uint256 numberofTokensToSell) internal view{
        uint256 balance =slvToken.balanceOf(account);

        if(balance< numberofTokensToSell){ 
            revert  TokenMarketplace_InsufficentSellerTokenBalance(balance,numberofTokensToSell);
        }
    }

    function createSellOrder(uint256 numberofTokensToSell) external {
        _isNumberofTokensZero(numberofTokensToSell);
        _checkSellerSlvTokenBalance(msg.sender,numberofTokensToSell);
        uint256 allowance= slvToken.allowance(msg.sender,address(this));

        if(allowance<numberofTokensToSell){
            revert TokenMarketplace_InsufficientAllowance(allowance,numberofTokensToSell);
        }
        OrderInfo memory order=OrderInfo({
         orderId:nextOrderId,
         seller:msg.sender,
         numberofTokensToSell:numberofTokensToSell,
         isActive:true 
        });
        orders[nextOrderId]=order;
        nextOrderId++;

        slvToken.safeTransferFrom(msg.sender,address(this),numberofTokensToSell); // from to amount  buyer=sender here
        reservedTokens+=numberofTokensToSell;
        orderList.push(order);
    }

    function getNumberofCreatedOrders() public view  returns(uint256) { // gives me total number of created orders
        return nextOrderId;
    }
    
    function _validateOrderId(uint256 orderId) internal view{
        uint256 totalNumberOfCreatedOrder=getNumberofCreatedOrders();
        if(orderId>totalNumberOfCreatedOrder){
            revert SLVTokenMarketPlace_InvalidOredrId();
        }
    }

    function buyTokensFromSellOrderCreated(uint256 orderId,uint256 numberofTokensToBuy)external payable{
        
        _validateOrderId(orderId);
        _isNumberofTokensZero(numberofTokensToBuy);
        _checkEthPayment(numberofTokensToBuy);

        OrderInfo storage order=orders[orderId];  //storage change in the original one but memory change in duplicate one but not in original
        if(order.isActive==false){
            revert TokenMarketplace_OrderIsNotActive(orderId);
        }
        if(order.numberofTokensToSell< numberofTokensToBuy){  
            revert TokenMarketplace_NotEnoughTokensInOrder(order.numberofTokensToSell,numberofTokensToBuy);
        }
        order.numberofTokensToSell-=numberofTokensToBuy;
        if(order.numberofTokensToSell==0){
            order.isActive=false;
        }
        // token transfer brom marketplace/contract  to buyer
        slvToken.safeTransfer(msg.sender,numberofTokensToBuy);

        //transfer ETH from contract to seller account 
        (bool success,)=order.seller.call{value:msg.value}("");
        if(!success){
            revert TokenMarketplace_EthTransferFailed();
        }
    }

    function cancelSellOrder(uint256 orderId) external  {
        _validateOrderId(orderId);
        OrderInfo storage order=orders[orderId];
        if(order.seller!=msg.sender){
            revert TokenMarketPlace_UnauthorisedSeller(msg.sender,orderId);
        }

        //algorithm
        order.isActive=false;
        reservedTokens-=order.numberofTokensToSell;
        slvToken.transfer(order.seller,order.numberofTokensToSell);
    }
    
    function getCreatedOrderById(uint256 orderId) external  view returns(OrderInfo memory){
        _validateOrderId(orderId);
        return orders[orderId];
    }

    // function getAllOrders() external view returns(OrderInfo[] memory){
    //     OrderInfo[] memory allOrder=new OrderInfo[] (nextOrderId);//here nextOredrId is telling us the size  
    //     for(uint256 i=0;i<nextOrderId;i++){
    //         allOrder[i]=orders[i];
    //     }
    //     return allOrder;
    // }

    function getAllOrders() external view returns(OrderInfo[] memory){
        return orderList;
    }

    function pause() external onlyOwner{
        _pause();
    }
    function unpause() external onlyOwner{
        _unpause();
    }

    function getAvailableMarketplaceTokens() external view returns(uint256){
        return slvToken.balanceOf(address(this));
    }
}