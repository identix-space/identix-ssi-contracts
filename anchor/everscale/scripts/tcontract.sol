pragma ton-solidity >= 0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

contract TContract
{
    constructor() public externalMsg { tvm.accept(); }
}