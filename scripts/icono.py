#!/usr/bin/env python3
"""Genera iconos PNG de 1024x1024 sin dependencias (solo zlib).
Uso: python3 scripts/icono.py bolita salida.png
     python3 scripts/icono.py coche salida.png
El dibujo se hace por píxel con antialias por supermuestreo (2x2)."""
import math, struct, sys, zlib

N = 1024


def png(path, px):
    raw = b''.join(b'\x00' + bytes(row) for row in px)
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', N, N, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def mix(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
def over(dst, src, a): return mix(dst, src, max(0.0, min(1.0, a)))


def bolita(x, y):
    # fondo degradado violeta
    c = mix((58, 44, 110), (27, 24, 48), y / N)
    # halo
    d = math.hypot(x - 512, y - 540)
    c = over(c, (120, 150, 255), 0.25 * max(0, 1 - d / 520))
    # sombra
    sd = ((x - 512) / 250) ** 2 + ((y - 900) / 40) ** 2
    if sd < 1: c = over(c, (10, 8, 25), 0.45 * (1 - sd))
    # cuerpo
    r = 360; cx, cy = 512, 520
    d = math.hypot(x - cx, y - cy)
    if d < r:
        t = math.hypot(x - (cx - 120), y - (cy - 150)) / (r * 1.5)
        body = mix((200, 232, 255), (111, 182, 255), min(1, t * 1.6)) if t < .6 else mix((111, 182, 255), (63, 134, 224), min(1, (t - .6) * 2.5))
        c = over(c, body, min(1, (r - d)))
        # brillo
        g = ((x - 390) / 120) ** 2 + ((y - 330) / 70) ** 2
        if g < 1: c = over(c, (255, 255, 255), .75 * (1 - g))
        # ojos
        for ex in (400, 624):
            e = ((x - ex) / 46) ** 2 + ((y - 500) / 62) ** 2
            if e < 1: c = (31, 27, 51)
            if math.hypot(x - (ex + 16), y - 478) < 16: c = (255, 255, 255)
        # mofletes
        for bx in (310, 714):
            b = ((x - bx) / 56) ** 2 + ((y - 610) / 34) ** 2
            if b < 1: c = over(c, (255, 122, 168), .45)
        # sonrisa
        m = math.hypot(x - 512, y - 590)
        if 58 < m < 80 and y > 610: c = (31, 27, 51)
    return c


def coche(x, y):
    # fondo azul noche con suelo reflectante
    c = mix((34, 44, 70), (12, 16, 28), y / N)
    d = math.hypot(x - 512, y - 560)
    c = over(c, (90, 140, 220), .22 * max(0, 1 - d / 560))
    # silueta de coche compacto (blanca)
    def inside(px, py):
        # carrocería baja
        if 170 < px < 854 and 520 < py < 690:
            k = 1
            if px < 230: k = (py - 520) > (230 - px) * 1.2
            if px > 800: k = (py - 520) > (px - 800) * .9
            return k
        # techo/cabina
        if 300 < py <= 520:
            left = 330 - (py - 300) * .45 if py > 300 else 330
            right = 690 + (py - 300) * .75
            if py < 330: return 360 < px < 660
            return left < px < right
        return False
    wheel = any(math.hypot(x - wx, y - 690) < 92 for wx in (320, 710))
    s = 0
    for ox in (-.25, .25):
        for oy in (-.25, .25):
            s += inside(x + ox, y + oy)
    if s:
        body = mix((255, 255, 255), (205, 215, 230), (y - 300) / 400)
        c = over(c, body, s / 4)
        # ventanillas
        if 340 < y < 505:
            l = 355 - (y - 330) * .45; r = 675 + (y - 330) * .7
            if l < x < r and abs(x - 520) > 10: c = mix((40, 60, 95), (90, 120, 170), (y - 340) / 170)
        # faro y línea
        if 540 < y < 570 and 790 < x < 845: c = (255, 230, 160)
        if 590 < y < 596 and 240 < x < 800: c = (190, 200, 215)
    if wheel:
        for wx in (320, 710):
            w = math.hypot(x - wx, y - 690)
            if w < 92: c = (22, 24, 30)
            if w < 52: c = (170, 178, 190)
            if w < 18: c = (60, 64, 72)
    # reflejo del suelo
    if y > 790: c = over(c, (255, 255, 255), .05 * max(0, 1 - (y - 790) / 120))
    return c


def main():
    kind, out = sys.argv[1], sys.argv[2]
    f = {'bolita': bolita, 'coche': coche}[kind]
    px = []
    for y in range(N):
        row = []
        for x in range(N):
            c = f(x, y)
            row += [int(max(0, min(255, round(v)))) for v in c]
        px.append(row)
    png(out, px)


main()
