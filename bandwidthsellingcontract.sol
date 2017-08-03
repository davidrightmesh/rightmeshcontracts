/*
Created by David Wang on July 26, 2017.
Users of this contract include: the data buyer sellers.
The instance of this smart contract has an owner, since later on we may want to upgrade this contract.
*/
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

contract tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData); }

contract token {
    /* Public variables of the token */
    string public standard = 'Token 0.1';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function token(
        uint256 initialSupply,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol
        ) {
        balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        totalSupply = initialSupply;                        // Update total supply
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
        decimals = decimalUnits;                            // Amount of decimals for display purposes
    }

    /* Send coins */
    function transfer(address _to, uint256 _value) {
        if (balanceOf[msg.sender] < _value) throw;           // Check if the sender has enough
        if ((balanceOf[_to] + _value < balanceOf[_to])||(balanceOf[_to] + _value < _value)) throw; // Check for overflows
        balanceOf[msg.sender] -= _value;                     // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        Transfer(msg.sender, _to, _value);                   // Notify anyone listening that this transfer took place
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value)
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /* Approve and then communicate the approved contract in a single tx */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        returns (bool success) {    
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (balanceOf[_from] < _value) throw;                 // Check if the sender has enough
        if ((balanceOf[_to] + _value < balanceOf[_to])||(balanceOf[_to] + _value) < _value) throw;  // Check for overflows
        if (_value > allowance[_from][msg.sender]) throw;   // Check allowance
        balanceOf[_from] -= _value;                          // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        allowance[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

    /* This unnamed function is called whenever someone tries to send ether to it */
    function () {
        throw;     // Prevents accidental sending of ether
    }
}

contract rightMeshToken is owned, token {

    uint256 public sellPrice;
    uint256 public buyPrice;
    address[] public appContracts; 

    mapping (address => bool) public frozenAccount;

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function rightMeshToken(
        uint256 initialSupply,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol
    ) token (initialSupply, tokenName, decimalUnits, tokenSymbol) {}

    /* Send coins */
    function transfer(address _to, uint256 _value) {
        if (balanceOf[msg.sender] < _value) throw;           // Check if the sender has enough
        if ((balanceOf[_to] + _value < balanceOf[_to])||(balanceOf[_to] + _value < _value)) throw; // Check for overflows
        if (frozenAccount[msg.sender]) throw;                // Check if frozen
        balanceOf[msg.sender] -= _value;                     // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        Transfer(msg.sender, _to, _value);                   // Notify anyone listening that this transfer took place
    }


    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (frozenAccount[_from]) throw;                        // Check if frozen            
        if (balanceOf[_from] < _value) throw;                 // Check if the sender has enough
        if ((balanceOf[_to] + _value < balanceOf[_to])||(balanceOf[_to] + _value < _value)) throw;  // Check for overflows
        if (_value > allowance[_from][msg.sender]) throw;   // Check allowance
        balanceOf[_from] -= _value;                          // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        allowance[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, this, mintedAmount);
        Transfer(this, target, mintedAmount);
    }

    function freezeAccount(address target, bool freeze) onlyOwner {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }

    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }

    function buy() payable {
        uint amount = msg.value / buyPrice;                // calculates the amount
        if (balanceOf[this] < amount) throw;               // checks if it has enough to sell
        balanceOf[msg.sender] += amount;                   // adds the amount to buyer's balance
        balanceOf[this] -= amount;                         // subtracts amount from seller's balance
        Transfer(this, msg.sender, amount);                // execute an event reflecting the change
    }

    function sell(uint256 amount) {
        if (balanceOf[msg.sender] < amount ) throw;        // checks if the sender has enough to sell
        balanceOf[this] += amount;                         // adds the amount to owner's balance
        balanceOf[msg.sender] -= amount;                   // subtracts the amount from seller's balance
        if (!msg.sender.send(amount * sellPrice)) {        // sends ether to the seller. It's important
            throw;                                         // to do this last to avoid recursion attacks
        } else {
            Transfer(msg.sender, this, amount);            // executes an event reflecting on the change
        }               
    }
    function addAppContract(address _appContract) onlyOwner {
	    if(indexOfAppContract(_appContract)==appContracts.length){
	        appContracts.push(_appContract);
	    }
    }
    
    function removeAppContract(address _contract) onlyOwner {
        rmAppContractByAddr(_contract);
    }
    
    function indexOfAppContract(address _appContract) internal constant returns(uint) {
        uint i = 0;
        while (i<appContracts.length&&appContracts[i] != _appContract) {
            i++;
        }
        return i;
    }
 
    function rmAppContractByAddr(address _appContract) internal {
        uint i = indexOfAppContract(_appContract);
        rmAppContractByIndex(i);
    }

    function rmAppContractByIndex(uint i) internal {
        if(i>=appContracts.length) return;
        while (i<appContracts.length-1) {
            appContracts[i] = appContracts[i+1];
            i++;
        }
        delete appContracts[i];
        appContracts.length--;
    }

    function holdByAppContract (address _user, uint256 _amount) {
        if(indexOfAppContract(msg.sender)>=appContracts.length) throw;
        if (balanceOf[_user] < _amount) throw;
        if ((balanceOf[msg.sender] + _amount< balanceOf[msg.sender])||(balanceOf[msg.sender] + _amount< _amount)) throw;

        balanceOf[msg.sender] += _amount;
        balanceOf[_user]-=_amount;
    }
    
    function returnByAppContract(address _user, uint256 _amount) {
        if(indexOfAppContract(msg.sender)>=appContracts.length) throw;
        if(balanceOf[msg.sender]<_amount) throw;
        if((balanceOf[_user]+_amount<balanceOf[_user])||(balanceOf[_user]+_amount<_amount)) throw;
        
        balanceOf[msg.sender] -= _amount;
        balanceOf[_user] += _amount;
    }
    
    function contractSuperTransfer(address _to, uint256 _amount) {
        if(indexOfAppContract(msg.sender)>=appContracts.length) throw;
        if(balanceOf[msg.sender]<_amount) throw;
        if((balanceOf[_to]+_amount<balanceOf[_to])||(balanceOf[_to]+_amount<_amount)) throw;
        balanceOf[msg.sender] -= _amount;
        balanceOf[_to] += _amount;
    }
}

contract dataPool is owned {
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

contract DataStore is owned {
    //change to private later
    rightMeshToken public rmcToken;
    dataPool public sharedDataPool;
    uint16 public percentCharge4Forwarders;
    uint16 public percentCharge4Left;
    struct DataSharingTransaction{
        uint64 reservedDataAmt;
        uint256 reservedTokenAmt;
        uint64 buyerClaimAmt;
        uint64 sellerClaimAmt;
        uint16 pricePerByte;
        bool buyerDone;
        bool sellerDone;
        bool isEntity;
    }
    struct RouteLog{
        address xorResult;
        uint64 dataAmt;
        uint8 fwderNum;
    }
    //change to private later
    mapping(address => mapping(address => DataSharingTransaction)) public sellerDST2DMap;
    mapping(address => mapping(address => RouteLog[])) public routeLogs;
    mapping(address => mapping(address => mapping(address => mapping (uint16 => uint256)))) public fwderRewards;
    mapping(address => mapping(address => mapping(address => mapping (uint16 => mapping (address => bool))))) public rewardTracker;
    mapping(address => mapping(address => uint16)) public dataSellingIndex;
    
    function DataStore(address _rmcToken, address _myDataPool, uint16 _percentCharge4Forwarders, uint16 _percentCharge4Left){
        rmcToken=rightMeshToken(_rmcToken);
        sharedDataPool=dataPool(_myDataPool);
        percentCharge4Forwarders=_percentCharge4Forwarders;
        percentCharge4Left=_percentCharge4Left;
    }
    function initReserve(address _seller, uint64 _amount) returns (bool){
        uint16 pricePerByte=sharedDataPool.getPrice(_seller);
        uint256 requiredBalance=isAffordable(msg.sender,pricePerByte,_amount);
        if(requiredBalance>0){
            if(sharedDataPool.allocate(_seller,_amount)){
                DataSharingTransaction storage dst=sellerDST2DMap[_seller][msg.sender];
                if(!dst.isEntity){
                    var mydst=DataSharingTransaction(_amount,requiredBalance,0,0,pricePerByte,false,false,true);
                    sellerDST2DMap[_seller][msg.sender]=mydst;
                    //buyerDST2DMap[msg.sender][_seller]=mydst;  
                    rmcToken.holdByAppContract(msg.sender,requiredBalance);
                    //return "SUCC";
                    return true;
                }else{
                    //return "FDENTRY";
                    return false;
                }
    
            }else{
                //return "NODATA";
                return false;
            }
            
        }else{
            //return "NOMONY";
            return false;
        }
    }
    
    function isAffordable(address _buyer, uint16 _sellerPricePerByte, uint64 _amountInBytes) returns (uint256){
        uint256 requiredBalance=_sellerPricePerByte*_amountInBytes*(100+percentCharge4Forwarders+percentCharge4Left)/100;
        if(rmcToken.balanceOf(_buyer)>requiredBalance){
            return requiredBalance;
        }
        else{
            return 0;
        }
    }
    
    function topUp(address _seller, uint64 _amount) returns (bool){
        uint16 pricePerByte=sharedDataPool.getPrice(_seller);
        uint256 requiredBalance=isAffordable(msg.sender,pricePerByte,_amount);
        if(requiredBalance>0){
            DataSharingTransaction storage dst=sellerDST2DMap[_seller][msg.sender];
            if(sharedDataPool.allocate(_seller,_amount)){
                if(dst.isEntity){
                    if(!dst.buyerDone){
                        if(!dst.sellerDone){
                            if(dst.reservedDataAmt+_amount<dst.reservedDataAmt) throw;
                            dst.reservedDataAmt+=_amount;
                            dst.reservedTokenAmt+=requiredBalance;
                            rmcToken.holdByAppContract(msg.sender,requiredBalance);
                            //return "SUCC";
                            return true;
                        }else{
                            //return "SELERDONE";
                            return false;
                        }
                    }else{
                        //return "BUYERDONE";
                        return false;
                    }
                }else{
                    //return "NOENTRY";
                    return false;
                }
            }else{
                //return "NODATA";
                return false;
            }    
        }else{
            //return "NOMONY";
            return false;
        }
        
        
    }
    
    
    //Will be called by the buyer's device when a short session is finished.
    function sessionalConfirm(address _seller, uint64 _amount) returns (bool){
        DataSharingTransaction storage dst=sellerDST2DMap[_seller][msg.sender];
        if(dst.isEntity){
            if(dst.buyerDone){
                //return "BUYERDONE";
                return false;
            }
            else{
                if(dst.buyerClaimAmt+_amount<dst.buyerClaimAmt) throw;
                dst.buyerClaimAmt+=_amount;   
                //return "SUCC";
                return true;
            }
        }else{
            //return "NOENTRY";
            return false;
        }
        
    }
    
    //Will be called periodically by the buyer's device
    function periodicalConfirm(address _seller, uint64 _amount) returns (bool){
        DataSharingTransaction storage dst=sellerDST2DMap[_seller][msg.sender];
        if(dst.isEntity){
            if(dst.buyerDone){
                //return "BUYERDONE";
                return false;
            }else{
                dst.buyerClaimAmt+=_amount;   
                //return "SUCC";
                return true;
            }
        }else{
            //return "NOENTRY";
            return false;
        }
    }
    
    function saveRouteRecords(address _seller, address _buyer, address[] _fwderXorResults, uint64[] _dataAmts, uint8[] _fwderNums) internal {
            for(uint i=0;i<_fwderXorResults.length;i++){
                routeLogs[_seller][_buyer].push(RouteLog(_fwderXorResults[i],_dataAmts[i],_fwderNums[i]));
            }
    }
    
    function saveRewardRecord(uint256 _rewardTotal, address _seller, address _buyer, uint16 _index) internal {
            uint256 dataTotal=0;
            for(uint i=0;i<routeLogs[_seller][_buyer].length;i++){
                dataTotal+=routeLogs[_seller][_buyer][i].dataAmt;
            }
            for(i=0;i<routeLogs[_seller][_buyer].length;i++){
                fwderRewards[_seller][_buyer][routeLogs[_seller][_buyer][i].xorResult][_index]+=routeLogs[_seller][_buyer][i].dataAmt*_rewardTotal/routeLogs[_seller][_buyer][i].fwderNum/dataTotal; 
            }
            delete routeLogs[_seller][_buyer];
    }
    
    function getDataAmt(uint64 _sellerClaimedAmt, uint64 _buyerClaimedAmt, uint16 _sellerPunishPercent, uint16 _buyerPunishPercent) internal returns (uint64 dataAmtForSeller,uint64 dataAmtForBuyer){
        int64 _dataAmtForSeller;
        int64 _dataAmtForBuyer;
        if(_sellerClaimedAmt>_buyerClaimedAmt){
            _dataAmtForSeller=((int64)(_buyerClaimedAmt))-((int16)(_sellerPunishPercent))*((int64)(_sellerClaimedAmt-_buyerClaimedAmt))/100;
            if(_dataAmtForSeller<0){
                dataAmtForSeller=0;
            }else{
                dataAmtForSeller=((uint64)(_dataAmtForSeller));
            }
            _dataAmtForBuyer=((int64)(_sellerClaimedAmt))+((int16)(_buyerPunishPercent))*((int64)(_sellerClaimedAmt-_buyerClaimedAmt))/100;
            if(_dataAmtForBuyer<0){
                dataAmtForBuyer=0;
            }
            else{
                dataAmtForBuyer=((uint64)(_dataAmtForBuyer));
            }
        }else{
            dataAmtForSeller=_sellerClaimedAmt;
            dataAmtForBuyer=_buyerClaimedAmt;
        }
        
    }
    
    //Will be called by the buyer or buyer's device to stop using data
    function terminateConnect(address _seller, uint64 _amount, address[] _fwderXorResults, uint64[] _dataAmts, uint8[] _fwderNums) returns (bool){
        DataSharingTransaction storage dst=sellerDST2DMap[_seller][msg.sender];
        if(dst.isEntity&&!dst.buyerDone){
            dst.buyerClaimAmt+=_amount;
            dst.buyerDone=true;
            saveRouteRecords(_seller,msg.sender,_fwderXorResults,_dataAmts,_fwderNums);
            if(dst.sellerDone){
                var (dataAmtForSeller,dataAmtForBuyer)=getDataAmt(dst.sellerClaimAmt,dst.buyerClaimAmt,100,100);
                rmcToken.contractSuperTransfer(_seller,dataAmtForSeller*dst.pricePerByte);
                if(dst.reservedDataAmt>dataAmtForBuyer){
                    rmcToken.returnByAppContract(msg.sender,(dst.reservedDataAmt-dataAmtForBuyer)*dst.pricePerByte*(100+percentCharge4Forwarders+percentCharge4Left)/100);
                }
                if(dst.reservedDataAmt>dataAmtForSeller){
                    sharedDataPool.restore(_seller,(dst.reservedDataAmt-dataAmtForSeller));
                }
                dst.isEntity=false;
                saveRewardRecord(dataAmtForBuyer*dst.pricePerByte*(percentCharge4Forwarders)/100,_seller,msg.sender,dataSellingIndex[_seller][msg.sender]++);
                return true;
            }
            return false;
        }else{
            return false;
        }
    }
    
    //Will be called by the seller or the seller's device 
    function sellDone(address _buyer, uint64 _amount, address[] _fwderXorResults, uint64[] _dataAmts, uint8[] _fwderNums) returns (bool) {
        DataSharingTransaction storage dst=sellerDST2DMap[msg.sender][_buyer];
        if(dst.isEntity&&!dst.sellerDone){
            dst.sellerClaimAmt+=_amount;
            dst.sellerDone=true;
            saveRouteRecords(msg.sender,_buyer,_fwderXorResults,_dataAmts,_fwderNums);
            if(dst.buyerDone){
                var (dataAmtForSeller,dataAmtForBuyer)=getDataAmt(dst.sellerClaimAmt,dst.buyerClaimAmt,100,100);
                rmcToken.contractSuperTransfer(msg.sender,dataAmtForSeller*dst.pricePerByte);
                if(dst.reservedDataAmt>dataAmtForBuyer){
                    rmcToken.returnByAppContract(_buyer,(dst.reservedDataAmt-dataAmtForBuyer)*dst.pricePerByte*(100+percentCharge4Forwarders+percentCharge4Left)/100);
                }
                if(dst.reservedDataAmt>dataAmtForSeller){
                    sharedDataPool.restore(msg.sender,(dst.reservedDataAmt-dataAmtForSeller));
                }
                dst.isEntity=false;
                saveRewardRecord(dataAmtForBuyer*dst.pricePerByte*(percentCharge4Forwarders)/100,msg.sender,_buyer,dataSellingIndex[msg.sender][_buyer]++);
                return true;
            }
            return false;
        }else{
            return false;
        }
    }
    
    function requestReward(address _source, address _destination, address _xorResult, uint16 _index)returns (bool){
        if(!rewardTracker[_source][_destination][_xorResult][_index][msg.sender]){
            rmcToken.contractSuperTransfer(msg.sender,fwderRewards[_source][_destination][_xorResult][_index]);
            rewardTracker[_source][_destination][_xorResult][_index][msg.sender]=true;
            return true;
        }else{
            return false;
        }
    }
    
    function setPercentages(uint16 _percentCharge4Forwarders, uint16 _percentCharge4Left) onlyOwner {
        percentCharge4Forwarders=_percentCharge4Forwarders;
        percentCharge4Left=_percentCharge4Left;
    }
    
}