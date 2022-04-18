pragma ton-solidity >= 0.58.2;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "libraries/Errors.sol";
import "libraries/Aux.sol";
import "interfaces/IIdxSsoDidDocument.sol";


contract IdxSsoDidDocument is IIdxSsoDidDocument  
{   
    // 
    address public controller;
    // presumably IdxSsoDidRegistry
    address static idxAuthority;

    constructor() public internalMsg
    {
        require(msg.sender.value != 0, Errors.AddressOrPubKeyIsNull);
        require(idxAuthority.value != 0, Errors.AddressOrPubKeyIsNull);
        controller = msg.sender;
    }

    ////// IDidDocument impl /////

    function changeController(address newController)
        override external onlyController
    {
        controller = newController;
    }

    ///// Upgrade //////
    function upgrade(TvmCell code) 
        public onlyIdxAuthority
    {
        TvmBuilder state;
        state.store(controller);

        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(state.toCell());
    }

    function onCodeUpgrade(TvmCell data) 
        private 
    {
        tvm.resetStorage();
        TvmSlice slice = data.toSlice();
        controller = slice.decode(address);
    }

    ////// Access //////
    
    modifier onlyController()
    {
        require(msg.sender == controller, Errors.MessageSenderIsNotController);
        _;
    }

    modifier onlyIdxAuthority()
    {
        require(msg.sender == idxAuthority, Errors.MessageSenderIsNotIdxAuthority);
        _;
    }

    ////// General //////
    function transfer(address dest, uint128 amount, bool bounce) 
        public pure onlyController
    {
        dest.transfer(amount, bounce, 0);
    }
}
