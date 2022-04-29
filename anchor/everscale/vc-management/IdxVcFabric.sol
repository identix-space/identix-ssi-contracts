pragma ton-solidity >= 0.58.2;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "IdxVc.sol";

contract Issuer 
{
    TvmCell private _vcBaseImage;

    constructor() public
    {

    }

    function setVcBaseImage(TvmCell image) public 
    {
        tvm.accept();
        _vcBaseImage = image;
    }
    
    function issueVc(Claim[] claims) public externalMsg returns (address vcAddress)
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
}