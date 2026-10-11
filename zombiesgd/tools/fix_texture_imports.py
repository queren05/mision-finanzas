#!/usr/bin/env python3
"""Pone compresión de GPU (VRAM), mipmaps y límite de tamaño a todas las texturas 3D (assets/ menos ui y fuentes).
Normal maps: límite 512 y marcados como normal map. Ejecutar tras añadir modelos nuevos y volver a importar."""
import glob, re, os
n = 0
for f in glob.glob('assets/**/*.import', recursive=True):
    if '/ui/' in f or '/fonts/' in f: continue
    s = open(f).read()
    if 'importer="texture"' not in s: continue
    o = s
    def setk(k, v):
        global s
        if re.search(r'^' + re.escape(k) + '=.*$', s, re.M): s = re.sub(r'^' + re.escape(k) + '=.*$', f'{k}={v}', s, flags=re.M)
        else: s = s.replace('[params]\n', f'[params]\n\n{k}={v}\n', 1)
    base = os.path.basename(f[:-7]).lower()
    normal = 'normal' in base or re.search(r'_n\.(jpg|png)$', base) or '_nor' in base
    setk('compress/mode', '2'); setk('mipmaps/generate', 'true'); setk('process/size_limit', '512' if normal else '1024')
    if normal: setk('compress/normal_map', '1')
    if s != o: open(f, 'w').write(s); n += 1
print('texturas ajustadas:', n)
