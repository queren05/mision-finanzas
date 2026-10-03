import sys
from playwright.sync_api import sync_playwright
# uso: shot.py "query" out.png [w h]
q, out = sys.argv[1], sys.argv[2]; w = int(sys.argv[3]) if len(sys.argv) > 3 else 844; h = int(sys.argv[4]) if len(sys.argv) > 4 else 390
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    pg = b.new_page(viewport={"width": w, "height": h})
    errs = []; pg.on("pageerror", lambda e: errs.append(str(e))); pg.on("console", lambda m: m.type == "error" and errs.append(m.text))
    pg.goto("http://localhost:8123/index.html?" + q)
    try: pg.wait_for_function("document.title==='LISTO'", timeout=120000)
    except Exception as e: errs.append("timeout")
    pg.screenshot(path=out); print("errores:", errs[:5]); b.close()
