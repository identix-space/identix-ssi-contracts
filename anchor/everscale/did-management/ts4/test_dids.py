from cgi import test
from collections import defaultdict, namedtuple
from http.client import NO_CONTENT
from sys import flags
import urllib.request as ur
import os 
import tonos_ts4.ts4 as ts4
from tonos_ts4.address import Address
from tonos_ts4.global_functions import zero_addr

eq = ts4.eq
ever = ts4.GRAM

class DidContractError:
    MessageSenderIsNotController = 200
    MessageSenderIsNeitherOwnerNorAuthority = 201
    MissingOwnerPublicKeyOrAddressOrBothGiven = 202
    MissingOwnerPublicKey = 203
    AddressOrPubKeyIsNull = 204
    ValueTooLow = 205

KeyPair = namedtuple('KeyPair', 'private public')

# region Setup
# Initialize TS4 by specifying where the artifacts of the used contracts are located
# verbose: toggle to print additional execution info
ts4.init('../', verbose = False)


def check_method_params(abi, method, params):
    assert isinstance(abi, ts4.Abi)

    if method == '.data':
        inputs = abi.json['data']
    else:
        func = abi.find_abi_method(method)
        if func is None:
            raise Exception("Unknown method name '{}'".format(method))
        inputs = func['inputs']
    res = {}
    for param in inputs:
        pname = param['name']
        if pname not in params:
            # THIS IS WHAY THIS WORKABOUTN ABOUT
            if pname == 'answerId':
                params['answerId'] = 0
            else:
            # ENDOF WORKAROUND
                raise Exception("Parameter '{}' is missing when calling method '{}'".format(pname, method))
        res[pname] = ts4.check_param_names_rec(params[pname], ts4.AbiType(param))
    return res

ts4.check_method_params = check_method_params
# endregion

idx_controller = KeyPair(*ts4.make_keypair())
subj1 = KeyPair(*ts4.make_keypair())

idx_registry: ts4.BaseContract = None

def test_deploy_idx_registry():
    global idx_registry
    params = dict(tplCode = ts4.load_code_cell('IdxDidDocument'))
    idx_registry = ts4.BaseContract('IdxDidRegistry', params, balance=20*ever, keypair=idx_controller, nickname='Registry')
    Address.ensure_address(idx_registry.address)
    assert idx_registry.g.codeVer() > 0


def test_issue_doc():
    doc_addr = idx_registry.call_method_signed('issueDidDoc', dict(subjectPubKey = subj1.public, salt = 0, didController = zero_addr(0)))
    ts4.dispatch_one_message()
    doc = ts4.BaseContract('IdxDidDocument', None, address=doc_addr)
    eq(idx_registry.address, doc.g.controller())
    eq(idx_registry.address, doc.g.idxAuthority())
    eq(subj1.public, doc.g.subjectPubKey())
    assert doc.g.codeVer() > 0

# region Update tests

def test_update_idx_registry():
    global idx_registry
    newcode = ts4.load_code_cell('ts4/IdxDidRegistry2')
    idx_registry.call_method_signed('upgrade', dict(code = newcode, nextVer = 0xFF00))
    ts4.dispatch_messages()
    idx_registry = ts4.BaseContract('ts4/IdxDidRegistry2', None, address=idx_registry.address, keypair=idx_controller)
    eq(0xFF00, idx_registry.g.codeVer())
    eq('my upgraded echo', idx_registry.call_method_signed('echo', dict(what = 'my upgraded echo')))


def test_update_doc():
    pass

# endregion

## main test
test_deploy_idx_registry()
test_update_idx_registry()
test_issue_doc()
test_update_doc()

# Ensure we have no undispatched messages
ts4.ensure_queue_empty()

