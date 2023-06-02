#!/bin/bash

#set -x
set -o errexit
set -o nounset
set -o pipefail

. scripts/lib-contracts.sh

initial_balance=250000000
network=yet_unknown
wallet=cwallet
wallet_abi=SafeMultisigWallet
do_reset=0
idx_signer=idx
# shellcheck disable=SC2034
idx_pubkey=$(everdev s l | pcregrep -o1 "$idx_signer\s+([0-9a-z]+)")
subj_pubkey=$(everdev s l | pcregrep -o1 "test122021\s+([0-9a-z]+)")
contracts=./vc-management

alias grep_vc_address="pcregrep -o1 'vcAddress\"\: \"(0:[0-9a-z]+)\"'"

for a in "$@"
do
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
    #url_param="-u localhost"
    signer=$idx_signer
    yell SE network
elif [[ "$network" = "dev" ]]
then
    giver_arg=""
    #url_param="--url eri01.net.everos.dev"
    signer=$idx_signer
    yell DEV network
elif [[ "$network" = "main" ]]
then
    giver_arg=""
    #url_param="-u eri01.main.everos.dev"
    signer=$idx_signer
    yell MAIN network
elif [[ "$network" = "vtest" ]]
then
    giver_arg=""
    #url_param="--url venom-testnet.evercloud.dev"
    signer=$idx_signer
    wallet=vwallet
    wallet_abi=everWallet
    yell VENOM network
else
    die $network is not valid for target network
fi

if [[ "$network" = "se" ]] && [[ "$do_reset" = "1" ]]; 
then 
    everdev se reset; 
fi

# everdev sol set -c 0.61.0 -l 0.18.4


if [[ -z "$giver_arg" ]]
then
    # calc the target addr
    caddr=$(tonos-cli genaddr --setkey ~/tonkeys/$signer $contracts/IdxVcFabric.tvc | grep_deploy_addr)
    assert_not_empty "$caddr" "Cannot generate addr"
    balance=$(get_contract_balance "$caddr")
    if [[ -z "$balance" ]];
    then
        balance="0"
    fi
    if (( "0" == "$balance" ));
    then
        #topping up the acc
        yell Balance of "$(f_green "$caddr")" is low: "$(f_red $balance)", topping it up
        success=$(everdev c r -n $network -s "$wallet" scripts/$wallet_abi -a "$(cat ~/tonkeys/${wallet}_address)" sendTransaction -i dest:"$(echo -n "$caddr" | cut -d':' -f2)",value:"$initial_balance",bounce:false,flags:0,payload:\"\" | grep_success)
        assert_not_empty "$success" "Cannot top up the acc: $caddr"
        sleep 6s
        balance=$(get_contract_balance "$caddr")
        assert_not_empty "$balance" "Can't get balance. Probably the account is missing"
        #[[ "$balance" -lt "900000000" ]] && die Low balance on the fabric: "$balance"
    fi
    yell "VC fabric balance is $(f_green "$balance") at $caddr"
fi
# Deploying Identix VC fabric
ddcode=$(decode_contract_code $contracts/IdxVc_type1.tvc)
fabric_addr=$(deploy_contract $contracts/IdxVcFabric $network $signer "$giver_arg")
yell "Fabric deployed $(f_green "$fabric_addr")"
yell "Setting VC base image..."
success=$(everdev c r -n $network -s $signer $contracts/IdxVcFabric setVcBaseImage -i vcBaseImage:"$ddcode" | grep_success)

yell "Testing VC issuance..."
claim1='{"hmacHigh_groupDid":"1","hmacHigh_claimGroup":"2","signHighPart":"3","signLowPart":"4"}'
args="{\"claims\":[$claim1],\"issuerPubKey\":\"0x$subj_pubkey\",\"answerId\":\"0\"}"
vc_addr=$(everdev c r -n $network -s $signer $contracts/IdxVcFabric issueVc -i "${args}" | grep_vc_address)
assert_not_empty "$vc_addr" "issueVc failed"
balance=$(get_contract_balance "$vc_addr")
yell "VC deployed $(f_green "$vc_addr"), balance $(f_green "$balance")"
yell "Waiting for the tx to complete..."
sleep 2s
resultcontent=$(everdev c l -n $network -s $signer -a "$vc_addr" $contracts/IdxVc_type1 issuerPubKey | grep issuerPubKey | cut -d'"' -f4)
if [[ "0x$subj_pubkey" != "$resultcontent" ]]
then
    die "VC check test failed. Got: \"$resultcontent\". Exp: \"$subj_pubkey\""
fi
yell "$(f_green All OK)"