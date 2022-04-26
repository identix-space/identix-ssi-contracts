from functools import cache
import os
import json
from glob import glob
import re
from unittest import removeResult, result
from unittest.loader import VALID_MODULE_NAME
from urllib.parse import urlsplit
from jsonschema import validate
import jsonschema.validators as jsv

BASE_PATH = os.path.abspath(os.getcwd())

def jload(fn: str):
    with open(fn, 'r') as f:
        return json.load(f)

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

idx_pred_validator = jsv.Draft7Validator(predicate_schema)
inherited = idx_pred_validator.resolver.resolve_remote
idx_pred_validator.resolver.resolve_remote = lambda url: local_ref_resolve_remote(inherited, url)
idx_vccs_validator = jsv.Draft7Validator(vccs_schema)
inherited = idx_vccs_validator.resolver.resolve_remote
idx_vccs_validator.resolver.resolve_remote = lambda url: local_ref_resolve_remote(inherited, url)

predicates = list(map(jload, glob('schemas/core/*')))
examples = list(map(jload, glob('schemas/examples/*')))

for p in predicates:
    idx_pred_validator.validate(p)
    print(p['id'])

for vcs in examples:
    idx_vccs_validator.validate(vcs)
    print(vcs['id'])
