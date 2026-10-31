import re, sys, json, pathlib
root = pathlib.Path(sys.argv[1])
seen = {}; order = []
lit = re.compile(r'"((?:[^"\\$]|\\.|\$(?![{A-Za-z]))*)"')
for f in sorted(root.rglob('*.kt')):
    if f.name in ('L10n.kt', 'Icons.kt'): continue
    for ln, line in enumerate(f.read_text().splitlines(), 1):
        code = re.sub(r'//.*$', '', line) if '"' not in line.split('//')[0][-1:] else line
        if line.strip().startswith('//') or line.strip().startswith('*') or line.strip().startswith('/**'): continue
        for m in lit.finditer(line):
            s = m.group(1)
            # quitar lo que no es texto para el jugador
            if not re.search(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]{2,}', s): continue
            if re.fullmatch(r'#[0-9a-fA-F]{3,8}', s): continue
            if re.fullmatch(r'[a-z0-9]+(\.[a-z0-9]+)+', s): continue      # iconos y archivos
            if re.fullmatch(r'[a-z][a-z0-9_]*', s) and not re.search(r'[áéíóúñ]', s): continue  # ids
            if re.fullmatch(r'-[a-z]+', s): continue                          # argumentos de capturas
            if re.search(r'/|\.json|\.png|\.ogg|\.m4a|\.jks', s): continue
            if s in ('UTF-8',): continue
            s = re.sub(r'\\u([0-9a-fA-F]{4})', lambda mm: chr(int(mm.group(1), 16)), s).replace('\\"', '"').replace('\\n', '\n').replace('\\$', '$')
            if s not in seen: seen[s] = f'{f.relative_to(root)}:{ln}'; order.append(s)
json.dump({s: seen[s] for s in order}, open(sys.argv[2], 'w'), ensure_ascii=False, indent=0)
print(len(order))
