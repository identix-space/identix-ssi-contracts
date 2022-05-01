from functools import cache
import os
import json
from glob import glob
from typing import Any, Callable
from unittest import result
import jsonschema.validators as jsv

BASE_PATH = os.path.abspath(os.getcwd())

class JSONWithCommentsDecoder(json.JSONDecoder):
    def __init__(self, **kw):
        super().__init__(**kw)

    def decode(self, s: str) -> Any:
        s = '\n'.join(l for l in s.split('\n') if not l.lstrip(' ').startswith('//'))
        return super().decode(s)


def jload(fn: str):
    try:
        with open(fn, 'r') as f:
            return json.load(f, cls=JSONWithCommentsDecoder)
    except json.JSONDecodeError as ex:
        print(f'Error in {fn.removeprefix(BASE_PATH)}\n{ex.args[0]}')
        quit(1)

predicate_schema = jload('schemas/meta/predicate')
vccs_schema = jload('schemas/meta/vccs')

cache = {}

def local_ref_resolve_remote(inherited, uri: str):
    result = cache.get(uri)
    if result is not None:
        return result
    if uri.startswith('https://identix.space'):
        result = jload(uri.replace('https://identix.space', BASE_PATH))
        cache[uri] = result
        return result
    return inherited(uri)

idx_pred_validator = jsv.Draft202012Validator(predicate_schema)
inherited = idx_pred_validator.resolver.resolve_remote
idx_pred_validator.resolver.resolve_remote = lambda url: local_ref_resolve_remote(inherited, url)
idx_vccs_validator = jsv.Draft202012Validator(vccs_schema)
inherited = idx_vccs_validator.resolver.resolve_remote
idx_vccs_validator.resolver.resolve_remote = lambda url: local_ref_resolve_remote(inherited, url)

predicates = list(map(jload, glob(BASE_PATH + '/schemas/core/*')))
predicates += list(map(jload, glob(BASE_PATH + '/schemas/officials/*')))
examples = list(map(jload, glob(BASE_PATH + '/schemas/examples/*')))

for p in predicates:
    idx_pred_validator.validate(p)
    print(p['id'])

for vcs in examples:
    idx_vccs_validator.validate(vcs)
    schema: str = vcs["$schema"]
    if schema.endswith('/vccs'):
        print(vcs['id'])
    elif schema.endswith('/vc_jwt_v1'):
        print(vcs['payload']['jti'])
    else:
        print('What the hell are you?')
