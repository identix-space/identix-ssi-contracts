import json

from validate import validate_predicate


def gen_predicate(alias: str, expected_types: list[str], *, schema_prefix: str = None, schema_path: str = None) -> dict:
    with open('predicates/$template', 'r') as f:
        tpl = json.load(f)

    prefix = schema_prefix.removesuffix('/') if schema_prefix else 'https://schemas.identix.space'
    path = schema_path.removesuffix('/') if schema_path else 'predicates'
    tpl['$id'] = f'{prefix}/{path}/{alias}'
    tpl['alias'] = alias
    tpl['object_def']['expected_types'] = expected_types
    validate_predicate(tpl)
    return tpl


def gen_predicates(defs: dict[str, list[str]], *, schema_prefix: str = None, schema_path: str = None) -> dict:
    pp = [gen_predicate(*p, schema_prefix=schema_prefix, schema_path=schema_path) for p in defs.items()]
    for p in pp:
        p['$anchor'] = p['alias']
        del p['$id']
    return {"$defs": pp}


def gen_emiratesid_predicate_files():
    defs = {
            'first_name': ['string'],
            'middle_name': ['string'],
            'last_name': ['string'],
            'gender': ['string'],
            'nationality': ['string'],
            'birth_date': ['datetime'],
            'birth_place': ['string'],
            'idcard_issuance_date': ['datetime'],
            'idcard_expiration_date': ['datetime'],
            'idcard_issuer': ['string']
    }

    em_path = 'emiratesid'

    pp = [(p[0], gen_predicate(*p, schema_prefix='emiratesid', schema_path=em_path)) for p in defs.items()]
    for file, j in pp:
        with open(f'.\\{em_path}\\{file}', mode='w', encoding='utf-8') as f:
            json.dump(j, f, indent=4)


if __name__ == '__main__':
    gen_emiratesid_predicate_files()
    # from pprint import pprint
    # pprint(gen_predicates(
    #     {
    #         'defaultvalue': ['number'],
    #         'displayName': ['string'],
    #         'hidden': ['number'],
    #         'description': ['string'],
    #         'icon': ['url'],
    #         'icongray': ['url'],
    #     }))

