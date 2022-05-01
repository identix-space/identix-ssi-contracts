pragma ton-solidity >= 0.58.2;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../libraries/Errors.sol";
import "../libraries/Aux.sol";
import "../interfaces/IIdxVc.sol";


struct ClaimGroupDesc
{
    // HMAC-secured hashes
    uint256 groupDid;
    uint256 claimGroup;

    // 512 bit long signature of the claimGroup hash
    uint256 signHighPart;
    uint256 signLowPart;
}


contract IdxVc_type1 is IIdxVc
{
    ClaimGroupDesc[] static public claimGroups;
    uint256 public static issuerPubKey;

    constructor() internalMsg public
    {
        issuerPubKey = tvm.pubkey();
    }

    
}