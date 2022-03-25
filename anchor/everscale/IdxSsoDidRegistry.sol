pragma ton-solidity >= 0.58.2;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "libraries/Errors.sol";
import "libraries/Gas.sol";
import "libraries/Aux.sol";
import "interfaces/IIdxSsoDidDocument.sol";
import "IdxSsoDidDocument.sol";

contract IdxSsoDidRegistry 
{
    TvmCell private _templateCode;
    uint256 private _controllerPubKey;
    mapping (address => address[]) private _dids;
    uint8 private ver = 1;

    constructor(TvmCell tplCode) 
        public externalMsg
    {
        require(msg.pubkey() != 0, Errors.AddressOrPubKeyIsNull);
        tvm.accept();
        _controllerPubKey = msg.pubkey();
        _templateCode = tplCode;
    }

    ////// Document management //////

    function issueDid(address didController) 
        external externalMsg responsible
        checkAccessAndAccept
        returns (address didDocAddr) 
    {
        TvmBuilder salt;
        salt.store(tx.timestamp);
        TvmCell saltedCode = tvm.setCodeSalt(_templateCode, salt.toCell());

		TvmCell stateInit = tvm.buildStateInit(
        {
            contr: IdxSsoDidDocument,
            code: saltedCode,
            pubkey: tvm.pubkey(),
            varInit: 
            {
                idxAuthority: address(this)
            }
        });

		address addr = new IdxSsoDidDocument
        {
            stateInit: stateInit, 
            value: Gas.DidDocInitialValue
        }
        ();
        
        if (didController.value != 0)
            IIdxSsoDidDocument(addr).changeController(didController);
        else
            didController = address(this);

        _dids[didController].push(addr);
        
        return (addr);
    }

    function getDidDocs(address controller)
        external responsible
        returns (address[] docs) 
    {
        // external call
        if (msg.pubkey() != 0)
        {
            require(msg.pubkey() == _controllerPubKey, Errors.MessageSenderIsNotController);
            tvm.accept();
            if (controller.value == 0)
                controller = address(this);
        }
        // internal call
        else // if (msg.sender.value != 0)
        {
            require(msg.sender == controller, Errors.MessageSenderIsNotController);
        }

        address[] result;
        result = _dids[controller];
        return result;
    }

    ////// Templating //////
    function setTemplate(TvmCell code) 
        external externalMsg
        checkAccessAndAccept()
    {
        _templateCode = code;
    }

    ////// Access //////
    
    modifier checkAccessAndAccept() 
    {
        require(isController(), Errors.MessageSenderIsNotController);
        tvm.accept();
        _;
    }

    function isController()
        private view
        returns (bool)
    {
        return _controllerPubKey == msg.pubkey();
    }

    function changeController(uint256 newControllerPubKey)
        external
    {
        require(isController(), Errors.MessageSenderIsNotController);
        require(newControllerPubKey != 0, Errors.AddressOrPubKeyIsNull);
        tvm.accept();
        _controllerPubKey = newControllerPubKey;
    }

    ////// General //////
    function transfer(address dest, uint128 amount, bool bounce) 
        public pure
        checkAccessAndAccept()
    {
        dest.transfer(amount, bounce, 0);
    }
}