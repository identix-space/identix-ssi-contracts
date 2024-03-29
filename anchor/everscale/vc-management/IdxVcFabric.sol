pragma ton-solidity >= 0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../libraries/Errors.sol";
import "IdxVc_type1.sol";

contract Issuer 
{
    TvmCell private _vcBaseImage;
    // update controller
    uint256 private _idxControllerPubKey;
    uint16 public codeVer;

    constructor() public
    {
        require(msg.pubkey() != 0, 200);
        require(msg.pubkey() != 0, Errors.AddressOrPubKeyIsNull);
        tvm.accept();
        _idxControllerPubKey = msg.pubkey();
        codeVer = 0x0012;
    }

    function setVcBaseImage(TvmCell vcBaseImage)
        public externalMsg checkAccessAndAccept
    {
        _vcBaseImage = vcBaseImage;
    }
   
    function issueVc(ClaimGroup[] claims, uint256 issuerPubKey) 
        public externalMsg view responsible
        returns (address vcAddress)
    {
        require(isController(msg.pubkey()), Errors.MessageSenderIsNotController);
        require(claims.length > 0, Errors.InvalidArgument);
        tvm.accept();
        // for (uint i = 0; i < claims.length; ++i) 
        // {
        //     Claim c = claims[i];
        //     tvm.checkSign(c.claim, c.signHighPart, c.signLowPart, tvm.pubkey());    
        // }
        
        TvmCell state = tvm.buildStateInit(
        {
            contr: IdxVc_type1,
            code: _vcBaseImage, 
            pubkey: tvm.pubkey(),
            varInit:
            {
                claimGroups: claims,
                issuerPubKey: issuerPubKey
            }
        });
        // 0.015 is enough for everscale se/dev
        vcAddress = new IdxVc_type1{value: 0.02 ever, bounce: true, stateInit: state}();
    }

    ///// Upgrade //////
    function upgrade(TvmCell code, uint16 newCodeVer) 
        public checkAccessAndAccept
    {
        require (newCodeVer > codeVer);
        TvmBuilder state;
        state.store(_vcBaseImage);
        state.store(_idxControllerPubKey);
        state.store(newCodeVer);

        tvm.accept();
        tvm.commit();
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(state.toCell());
    }

    function onCodeUpgrade(TvmCell data) 
        private 
    {
        tvm.resetStorage();
        TvmSlice slice = data.toSlice();
        _vcBaseImage = slice.decode(TvmCell);
        _idxControllerPubKey = slice.decode(uint256);
        codeVer = slice.decode(uint16);
    }

    ////// Access //////
    modifier checkAccessAndAccept() 
    {
        require(isController(msg.pubkey()), Errors.MessageSenderIsNotController);
        tvm.accept();
        _;
    }

    function isController(uint256 pubkey)
        private view returns (bool)
    {
        return pubkey == _idxControllerPubKey;
    }

    ////// General //////
    function transfer(address dest, uint128 value, bool bounce)
        public pure checkAccessAndAccept
    {
        dest.transfer(value, bounce, 0);
    }
}