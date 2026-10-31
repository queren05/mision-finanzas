import json, sys, importlib.util
rows = []
for n in ('tr1', 'tr2', 'tr3'):
    spec = importlib.util.spec_from_file_location(n, n + '.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); rows += m.T
norm = lambda s: s.replace(' ', ' ')
keys = {norm(k) for k in json.load(open('keys.json'))}
en, pt = {}, {}
for es, e, p in rows:
    k = norm(es)
    if k in en and en[k] != e: print('DUP', k)
    en[k] = e; pt[k] = p
    if k not in keys and k not in ('vez', 'veces', 'GOLPES/S'): print('NO EN EL CÓDIGO:', k)
skip_files = ('model/SaveState.kt', 'support/Animal.kt', 'support/Style.kt', 'logic/Sound.kt')
src = json.load(open('keys.json'))
missing = [k for k, v in src.items() if norm(k) not in en and not v.startswith(skip_files)]
print('sin traducir:', len(missing)); print('\n'.join(missing))
out = sys.argv[1]
json.dump(en, open(out + '/en.json', 'w'), ensure_ascii=False, indent=0, sort_keys=True)
json.dump(pt, open(out + '/pt.json', 'w'), ensure_ascii=False, indent=0, sort_keys=True)
print(len(en), 'textos')
