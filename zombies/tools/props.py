import sys, base64, json, os
from playwright.sync_api import sync_playwright
ids = sys.argv[1]; dest = sys.argv[2]; size = sys.argv[3] if len(sys.argv) > 3 else "512"; tris = sys.argv[4] if len(sys.argv) > 4 else "6000"
os.makedirs(dest, exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg = b.new_page()
    pg.on("pageerror", lambda e: print("ERR", e)); pg.on("console", lambda m: m.type=="error" and print("CON", m.text))
    pg.goto(f"http://localhost:8124/props.html?ids={ids}&size={size}&tris={tris}")
    pg.wait_for_function("document.title==='DONE'", timeout=400000)
    r = pg.evaluate("window.RESULT")
    for k, v in r.items():
        d = base64.b64decode(v['b64']); open(f"{dest}/{k}.glb", "wb").write(d); print(k, round(len(d)/1024), "KB", v['tris'], "tris", v['size'])
    b.close()
