# Misión Finanzas

Tu app de finanzas personales: cuentas, gastos e ingresos, objetivos, presupuestos, recurrentes,
cripto y acciones en tiempo real, divisas, importación de extractos del banco y sincronización
entre la web y el iPhone.

> **Documentación técnica completa (estructura, datos, despliegue, GitHub Pages, TestFlight): [DOCUMENTACION.md](DOCUMENTACION.md).**

```
dist/                      ← la web, lista para subir tal cual
  index.html               ← toda la app en un archivo
  manifest.webmanifest, sw.js, icon-*.png
  supabase/functions/quotes/index.ts   ← proxy de cotizaciones (acciones)
ios-app/                   ← proyecto Capacitor (la misma web dentro de una app nativa)
.github/workflows/ios.yml  ← compila la app en la nube y la manda a TestFlight
src/                       ← código fuente por partes (edita aquí y ejecuta ./build.sh)
build.sh                   ← junta src/ en dist/index.html y lo copia a ios-app/www
```

---

## 1 · Poner la web en tu servidor

**GitHub Pages:** el workflow `pages.yml` la publica sola en cada push a `main` (Settings → Pages → Source: GitHub Actions; repo público en cuentas gratuitas).

O sube el contenido de `dist/` (menos la carpeta `supabase/`) a cualquier hosting estático:
Nicalia, Netlify o tu servidor Debian con CasaOS (Nginx/Caddy).

- Tiene que ir por **HTTPS** para que funcione el modo sin conexión e instalarla en el móvil.
- En tu servidor casero, un contenedor de Nginx apuntando a la carpeta basta. Si lo expones con
  Cloudflare Tunnel o Nginx Proxy Manager tendrás HTTPS gratis.

## 2 · Sincronizar web e iPhone (Supabase)

1. Crea un proyecto en supabase.com (plan gratis).
2. **SQL Editor** → pega el SQL que aparece en la app en *Más → Sincronización* (también abajo) → Run.
3. **Authentication → Providers → Email**: si no quieres confirmar el correo, desactiva *Confirm email*.
4. En la web: *Más → Sincronización* → pega Project URL y la clave *anon public* → **Crear cuenta**.
5. En el iPhone (y en cualquier otro navegador): lo mismo pero con **Entrar**.

Cómo funciona: una fila por usuario con todo tu estado; gana el último cambio. Si dos dispositivos
cambian a la vez, el que pierde guarda una copia local (`mision.copia-antes-de-sincronizar`).
Se sincroniza a los 2–3 s de cada cambio, al volver a la app y cada 45 s.

```sql
create table if not exists public.mision_state (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.mision_state enable row level security;
drop policy if exists "solo mi fila" on public.mision_state;
create policy "solo mi fila" on public.mision_state
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create or replace function public.mision_touch() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists mision_touch on public.mision_state;
create trigger mision_touch before insert or update on public.mision_state
  for each row execute function public.mision_touch();
```

## 3 · Precios en tiempo real

| Qué | Fuente | Configuración |
|---|---|---|
| Cripto | WebSocket de Binance (cada cambio) + CoinGecko (cada minuto, cualquier moneda) | Ninguna |
| Divisas | ExchangeRate-API, respaldo Frankfurter (BCE) | Ninguna |
| Acciones y ETF, cualquier bolsa | Yahoo Finance a través del proxy | Desplegar la función |
| Acciones EE. UU. (alternativa) | Finnhub, con WebSocket | Clave gratis en finnhub.io |

**Proxy de Yahoo** (en tu proyecto de Supabase, con la CLI instalada):

```bash
cd dist            # la carpeta que contiene supabase/
supabase login
supabase link --project-ref TU_REF
supabase functions deploy quotes --no-verify-jwt
```

Pega `https://TU_REF.supabase.co/functions/v1/quotes` en *Más → Fuentes de precios* y pulsa
**Probar proxy**. Tickers de Yahoo: `SAN.MC` (Madrid), `ITX.MC`, `VWCE.DE` (Xetra), `AAPL`, `IWDA.AS`…

## 4 · App de iPhone sin Mac (GitHub Actions → TestFlight)

Un Mac de GitHub compila y firma la app con tu cuenta de desarrollador y la sube a TestFlight.
Usa un **repositorio privado**: solo sirve para compilar, no publica nada.

**Una sola vez (unos 15 minutos, todo desde el navegador):**

1. **Crea un repo privado** en GitHub y sube esta carpeta entera (incluida la carpeta oculta
   `.github`). Con GitHub Desktop es arrastrar y «Publish repository» marcando *Keep this code private*.
2. **Registra el identificador**: developer.apple.com → Certificates, IDs & Profiles → Identifiers →
   `+` → App IDs → App → Bundle ID explícito `es.david.mision` (o el que quieras).
3. **Crea la app** en appstoreconnect.apple.com → Apps → `+` → Nueva app → iOS, nombre «Misión»
   (si está cogido, «Misión Finanzas DR»), el Bundle ID de antes y cualquier SKU.
4. **Crea una clave de API**: App Store Connect → Usuarios y acceso → Integraciones → App Store
   Connect API → `+`, rol **Admin**. Descarga el `.p8` (solo se puede una vez) y apunta *Key ID* e
   *Issuer ID*.
5. En el repo → Settings → Secrets and variables → Actions:
   - Secrets: `APPLE_TEAM_ID` (developer.apple.com → Membership), `ASC_KEY_ID`, `ASC_ISSUER_ID`,
     `ASC_KEY_P8` (abre el .p8 con el Bloc de notas y pega todo el texto).
   - Variables: `BUNDLE_ID` solo si no usas `es.david.mision`.

**Cada versión:** Actions → **App de iPhone** → Run workflow → `testflight`. En 15–20 minutos te
llega a la app TestFlight del iPhone (la primera vez Apple tarda un poco más en procesarla). El
número de compilación sube solo. Las compilaciones de TestFlight caducan a los 90 días: vuelve a
lanzar el workflow y listo.

*Opción `adhoc`:* genera un `.ipa` descargable (Artifacts) solo para iPhones registrados por UDID;
necesitas una herramienta para instalarlo, así que TestFlight es más cómodo.

**Qué gana la app frente a la web:** acciones de cualquier bolsa en directo sin proxy (peticiones
nativas), avisos del día antes de cada cargo, vibración, y los enlaces `mision://` para Atajos.

## 4 bis · Atajos de iPhone

Todo está explicado dentro de la app en *Más → Atajos de iPhone* (con botones para copiar).

- **Apple Pay:** automatización *Transacción* → *Codificar URL* (Comerciante) → *Abrir URL*
  `mision://nuevo?importe=[Importe]&concepto=[URL codificada]&tarjeta=[Tarjeta o pase]`.
  Cada pago se apunta solo en la cuenta de esa tarjeta y con la categoría que le toque.
- **Siri / dictado:** `mision://rapido?texto=…` con frases como «12,50 mercadona» o
  «3 café en efectivo ayer».
- **Botón de acción / widget:** `mision://plantilla?nombre=Café`.
- **Abrir una pantalla:** `mision://abrir?pantalla=inversiones`.

## 5 · Conectar el banco

Hoy: **importar el extracto** en CSV o Excel (*Más → Importar del banco*), con detección de columnas,
duplicados y clasificación por palabras clave.

Conexión automática (PSD2): la opción gratuita para uso personal es **Enable Banking** en modo
restringido (solo tus cuentas). Requiere un pequeño backend que firme las peticiones con tu clave
privada — encaja como otra Edge Function de Supabase. GoCardless Bank Account Data (antes Nordigen)
no admite registros nuevos.

## Privacidad

Sin sincronización, todo vive en el almacenamiento del navegador/app. Con sincronización, en tu
propio proyecto de Supabase protegido por RLS. Haz una copia de vez en cuando en
*Más → Copia de seguridad*.
