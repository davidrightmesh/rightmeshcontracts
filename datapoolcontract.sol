pragma solidity ^0.4.2;
contract owned {
    address public owner;
    
    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }
    
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract DataPool is owned {
    struct Share{
        uint256 totalBytes;      //bits
        uint16 pricePerByte;    //price
        uint256 hasUsed;           //bits have been used
        bool isEntity;     
    }
    mapping (address =>Share) public pool;
   
    function share(uint256 _totalBytes,uint16 _pricePerByte){
        if(pool[msg.sender].isEntity){
            pool[msg.sender].totalBytes+=_totalBytes;
            pool[msg.sender].pricePerByte=_pricePerByte;
        }
        else{
            pool[msg.sender]=Share(_totalBytes,_pricePerByte,0,true);
        }
    }
    
    function allocate(address _seller, uint64 _amount) returns (bool) {
        if(!pool[_seller].isEntity||(pool[_seller].totalBytes<_amount+pool[_seller].hasUsed)){
            return false;
        }
        else{
            pool[_seller].hasUsed+=_amount;
            return true;
        }
    }

    function restore(address _seller, uint64 _amount) returns (bool) {
        if(!pool[_seller].isEntity){
            return false;
        }
        else if(pool[_seller].hasUsed<_amount){
            return false;
        }else{
            pool[_seller].hasUsed-=_amount;
            return true;
        }
    }
    
    function getPrice(address _seller) constant returns (uint16){
        if(pool[_seller].isEntity){
            return pool[_seller].pricePerByte;
        }
        else{
            throw;
        }
    }
}