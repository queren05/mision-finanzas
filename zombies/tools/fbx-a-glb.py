import sys, base64, json
from playwright.sync_api import sync_playwright
size = sys.argv[1] if len(sys.argv) > 1 else '1024'
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg = b.new_page()
    pg.on("pageerror", lambda e: print("ERR", e)); pg.on("console", lambda m: m.type=="error" and print("CON", m.text))
    pg.goto("http://localhost:8124/conv.html?size=" + size)
    pg.wait_for_function("document.title==='DONE'", timeout=240000)
    r = pg.evaluate("window.RESULT"); open("zombie_city.glb", "wb").write(base64.b64decode(r["b64"]))
    print(json.dumps({k: v for k, v in r.items() if k != "b64"}, indent=1)); b.close()
