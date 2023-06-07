import os
import json
from glob import glob
from pathlib import Path
from typing import Any
import jsonschema.validators as jsv

BASE_PATH = os.path.abspath(os.getcwd())


def validate_predicate(predicate: str | Path):
    _idx_pred_validator.validate(predicate)


def validate_vccs(vccs: str | Path):
    _idx_vccs_validator.validate(vccs)


def validate_vc(vc: str | Path):
    _idx_vc_validator.validate(vc)


class JSONWithCommentsDecoder(json.JSONDecoder):
    def __init__(self, **kw):
        super().__init__(**kw)

    def decode(self, s: str, _w=...) -> Any:
        s = '\n'.join(l for l in s.split('\n') if not l.lstrip(' ').startswith('//'))
        return super().decode(s)


def jload(fn: str):
    try:
        with open(fn, 'r') as f:
            return json.load(f, cls=JSONWithCommentsDecoder)
    except json.JSONDecodeError as ex:
        print(f'Error in {fn.removeprefix(BASE_PATH)}\n{ex.args[0]}')
        quit(1)


def jloads(s: str):
    try:
        return json.loads(s, cls=JSONWithCommentsDecoder)
    except json.JSONDecodeError as ex:
        print(f'Error \n{ex.args[0]}')
        quit(1)


_predicate_schema = jload('meta/predicate')
_vccs_schema = jload('meta/vccs')
_vc_schema = jload('meta/vc_jwt_v1')

_cache = {}


def _local_ref_resolve_remote(base_impl, uri: str):
    result = _cache.get(uri)
    if result:
        return result
    if uri.startswith('https://schemas.identix.space'):
        result = jload(uri.replace('https://schemas.identix.space', BASE_PATH))
        _cache[uri] = result
        return result
    return base_impl(uri)


_idx_pred_validator = jsv.Draft202012Validator(_predicate_schema)
_inherited = _idx_pred_validator.resolver.resolve_remote
_idx_pred_validator.resolver.resolve_remote = lambda url: _local_ref_resolve_remote(_inherited, url)

_idx_vccs_validator = jsv.Draft202012Validator(_vccs_schema)
_inherited1 = _idx_vccs_validator.resolver.resolve_remote
_idx_vccs_validator.resolver.resolve_remote = lambda url: _local_ref_resolve_remote(_inherited1, url)

_idx_vc_validator = jsv.Draft202012Validator(_vc_schema)
_inherited2 = _idx_vc_validator.resolver.resolve_remote
_idx_vc_validator.resolver.resolve_remote = lambda url: _local_ref_resolve_remote(_inherited2, url)


if __name__ == '__main__':

    predicates = [jload(f) for f in glob(BASE_PATH + '/predicates/*') if '$template' not in f]
    vccs_examples = [jload(f) for f in glob(BASE_PATH + '/emiratesid/*') if '$template' not in f]
    vc_examples = [jload(f) for f in glob(BASE_PATH + '/examples/*') if '$template' not in f]

    for p in predicates:
        print(p['$id'], end='')
        validate_predicate(p)
        print(' VALID')

    for vccs in vccs_examples:
        print(vccs['$id'], end='')
        validate_vccs(vccs)
        print(' VALID')

    for vc in vc_examples:
        print(vc['payload']['jti'], end='')
        validate_vc(vc)
        print(' VALID')
