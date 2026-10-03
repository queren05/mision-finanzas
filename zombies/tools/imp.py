import sys, base64, json, os
from playwright.sync_api import sync_playwright
ids = sys.argv[1]; dest = sys.argv[2]; os.makedirs(dest, exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg = b.new_page()
    pg.on("pageerror", lambda e: print("ERR", e))
    pg.goto(f"http://localhost:8124/imp.html?ids={ids}")
    pg.wait_for_function("document.title==='DONE'", timeout=550000)
    r = pg.evaluate("window.RESULT"); info = {}
    for k, v in r.items():
        for i, im in enumerate(v['views']): open(f"{dest}/{k}_{i}.png", "wb").write(base64.b64decode(im))
        info[k] = {'w': v['w'], 'h': v['h']}; print(k, info[k])
    json.dump(info, open(dest + '/info.json', 'w')); b.close()
