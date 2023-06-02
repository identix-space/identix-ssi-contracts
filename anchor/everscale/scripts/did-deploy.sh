#!/bin/bash

#set -x
set -o errexit
set -o nounset
set -o pipefail

. scripts/lib-contracts.sh

initial_balance=500000000
network=yet_unknown
wallet=cwallet
wallet_abi=SafeMultisigWallet
do_reset=0
idx_signer=idx
idx_pubkey=$(everdev s l | pcregrep -o1 "$idx_signer\s+([0-9a-z]+)")
subj_pubkey=$(everdev s l | pcregrep -o1 "test122021\s+([0-9a-z]+)")
contracts=./did-management

for a in "$@"
do
    if [[ "$network" = "main" ]]
    then
        wallet_addr=$a
    fi
    case $a in
        "se") network=se;;
        "dev") network=dev;;
        "main") network=main;;
        "vtest") network=vtest;;
        "reset") do_reset=1;;
    esac
done

if [[ "$network" = "se" ]] 
then
    giver_arg="-v $initial_balance"
    url_param="-u localhost"
    signer=$idx_signer
    yell SE network
elif [[ "$network" = "dev" ]] 
then
    giver_arg="-v $initial_balance"
    url_param="--url eri01.net.everos.dev"
    signer=$idx_signer
    yell DEV network
elif [[ "$network" = "main" ]] 
then
    giver_arg=""
    url_param="-u eri01.main.everos.dev"
    signer=$idx_signer
    yell MAIN network
elif [[ "$network" = "vtest" ]]
then
    giver_arg=""
    url_param="-u venom-testnet.evercloud.dev"
    signer=$idx_signer
    wallet=vwallet
    wallet_abi=everWallet
    yell VENOM network
else
    die $network is not valid for target network
fi

if [[ "$network" = "se" ]] && [[ "$do_reset" = "1" ]]; then 
    everdev se reset; 
fi

compile "$contracts/IdxDidDocument.sol"
compile "$contracts/IdxDidRegistry.sol"

# everdev sol set -c 0.61.0 -l 0.18.4

if [[ -z "$giver_arg" ]];
then
    # calc the target addr
    caddr=$(tonos-cli genaddr --setkey ~/tonkeys/$signer $contracts/IdxDidRegistry.tvc | grep_deploy_addr)
    assert_not_empty "$caddr" "Cannot generate addr"
    balance=$(get_contract_balance "$caddr")
    if [[ -z "$balance" ]]; 
    then 
        balance="0" 
    fi
    if (( "0" >= "$balance" ));
    then
        #topping up the acc
        yell Balance of "$(f_green "$caddr")" is low: "$(f_red $balance)", topping it up
        #success=$(tonos-cli $url_param multisig send --addr $(cat ~/tonkeys/cwallet_address) --dest $caddr --purpose "deploy" --sign ~/tonkeys/cwallet --value 1000000000 | grep Succeeded)
        success=$(everdev c r -n $network -s "$wallet" scripts/$wallet_abi -a "$(cat ~/tonkeys/${wallet}_address)" sendTransaction -i dest:"$(echo -n "$caddr" | cut -d':' -f2)",value:$initial_balance,bounce:false,flags:0,payload:\"\" | grep_success)
        assert_not_empty "$success" "Cannot top up the acc: $caddr"
        sleep 8s
        balance=$(get_contract_balance "$caddr")
        assert_not_empty "$balance" "Can't get balance. Probably the account is missing"
        #[[ "$balance" -lt "900000000" ]] && die Low balance on the fabric: "$balance"
    fi
    yell "DID registry balance is $(f_green "$balance") at $(f_green "$caddr")"
fi

yell Deploying Identix DID registry
ddcode=$(decode_contract_code $contracts/IdxDidDocument.tvc)
registry_addr=$(deploy_contract $contracts/IdxDidRegistry $network $signer "$giver_arg" -i tplCode:"$ddcode")
assert_not_empty "${registry_addr}" "Cannot deploy registry"
yell Registry deployed "$(f_green "$registry_addr")"

doc_addr=$(everdev c r -n $network -s $signer $contracts/IdxDidRegistry issueDidDoc -i subjectPubKey:0x$subj_pubkey,salt:1,didController:0000000000000000000000000000000000000000000000000000000000000000,answerId:0 | grep didDocAddr | cut -d'"' -f4)
assert_not_empty "$doc_addr" "issueDidDoc failed"
yell Document deployed "$(f_green "$doc_addr")"
sleep 6s
resultcontent=$(everdev c l -n $network -s $signer -a "$doc_addr" $contracts/IdxDidDocument controller | grep controller | cut -d'"' -f4)
if [[ "$registry_addr" != "$resultcontent" ]]
then
    die controller check test failed. Got: \""$resultcontent"\". Exp: \""$registry_addr"\"
fi
yell "$(f_green OK)"