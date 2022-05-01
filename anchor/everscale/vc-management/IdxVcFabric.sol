pragma ton-solidity >= 0.58.2;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "IdxVc.sol";

contract Issuer 
{
    // update controller
    address static public idxAuthority;
    uint16 public codeVer;

    constructor() public externalMsg
    {
        require(msg.pubkey() != 0, Errors.AddressOrPubKeyIsNull);
        tvm.accept();
        codeVer = 0x0010;
    }
   
    function issueVc(Claim[] claims, TvmCell vcCode) 
        public externalMsg 
        returns (address vcAddress)
    {
        tvm.accept();
        for (uint i = 0; i < claims.length; ++i) 
        {
            Claim c = claims[i];
            tvm.checkSign(c.claim, c.signHighPart, c.signLowPart, tvm.pubkey());    
        }
        
        TvmCell state = tvm.buildStateInit(
        {
            contr: Vc,
            code: _vcBaseImage, 
            pubkey: tvm.pubkey(),
            varInit:
            {
                claims: claims
                // issuerPubKey: tvm.pubkey(),
                // issuer: address(this)
            }
        });
        vcAddress = new Vc{value: 0.1 ever, bounce: true, stateInit: state}();
    }

    ///// Upgrade //////
    function upgrade(TvmCell code, uint16 newCodeVer) 
        public onlyIdxAuthority
    {
        require (newCodeVer > codeVer);
        TvmBuilder state;
        state.store(controller);
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
        controller = slice.decode(address);
        codeVer = slice.decode(uint16);
    }
}