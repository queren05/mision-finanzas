#!/usr/bin/env python3
"""Sube el último .aab de Shrimp Zombies (release zombies-latest) a los canales de prueba de Google Play.
Uso: python3 scripts/subir_play.py "Novedades" [alpha,internal]
Usa la cuenta de servicio subidas-play (~/claves-shrimpzombies/play.json), que solo puede publicar en pruebas."""
import os, sys, urllib.request
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession
NOTES = sys.argv[1] if len(sys.argv) > 1 else "Nueva versión de prueba."
TRACKS = (sys.argv[2] if len(sys.argv) > 2 else "alpha,internal").split(",")
PKG = "es.david.shrimpzombies"
B = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
U = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"
aab = "/tmp/zombies.aab"
urllib.request.urlretrieve("https://github.com/queren05/mision-finanzas/releases/download/zombies-latest/zombies.aab", aab)
c = service_account.Credentials.from_service_account_file(os.path.expanduser("~/claves-shrimpzombies/play.json"), scopes=["https://www.googleapis.com/auth/androidpublisher"])
s = AuthorizedSession(c)
def ok(r):
    if not r.ok: raise SystemExit(f"Error {r.status_code}: {r.text}")
    return r.json()
edit = ok(s.post(f"{B}/edits"))["id"]
with open(aab, "rb") as f:
    b = ok(s.post(f"{U}/edits/{edit}/bundles?uploadType=media", data=f, headers={"Content-Type": "application/octet-stream"}, timeout=1800))
vc = str(b["versionCode"]); print("Subido versionCode", vc)
for t in TRACKS:
    ok(s.put(f"{B}/edits/{edit}/tracks/{t}", json={"track": t, "releases": [{"versionCodes": [vc], "status": "completed",
        "releaseNotes": [{"language": "es-ES", "text": NOTES[:500]}]}]}))
    print("Canal", t, "-> versión", vc)
ok(s.post(f"{B}/edits/{edit}:commit"))
print("Publicado")
