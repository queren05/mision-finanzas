# Misión Finanzas — Documentación técnica completa

> Documento de traspaso. Explica **qué es** la aplicación, **qué pidió el usuario**, **cómo está construida**,
> **qué se configuró**, **cómo se compila y despliega** (web en GitHub Pages + app de iPhone por TestFlight)
> y **cómo seguir trabajando** con ella. Está pensado para que otra persona o un agente con acceso a GitHub
> pueda subir el proyecto, publicarlo y compilarlo sin más contexto.

**Propietario:** David (Coslada, Madrid) · iPhone + cuenta de Apple Developer · **sin Mac**
**Versión:** 2.0 · **Idioma de la interfaz:** español (España) · **Moneda por defecto:** EUR

---

## Índice

0. [Resumen para quien lo va a desplegar](#0-resumen-para-quien-lo-va-a-desplegar)
1. [Lo que pidió el usuario (requisitos)](#1-lo-que-pidió-el-usuario-requisitos)
2. [Funcionalidades](#2-funcionalidades)
3. [Arquitectura y decisiones](#3-arquitectura-y-decisiones)
4. [Estructura de carpetas](#4-estructura-de-carpetas)
5. [Compilación (build.sh)](#5-compilación-buildsh)
6. [Módulos del código](#6-módulos-del-código)
7. [Modelo de datos](#7-modelo-de-datos)
8. [Lógica de negocio](#8-lógica-de-negocio)
9. [Precios en tiempo real](#9-precios-en-tiempo-real)
10. [Atajos de iPhone y enlaces `mision://`](#10-atajos-de-iphone-y-enlaces-mision)
11. [Importar extractos del banco](#11-importar-extractos-del-banco)
12. [Sincronización con Supabase (opcional)](#12-sincronización-con-supabase-opcional)
13. [Proxy de cotizaciones de Yahoo (opcional)](#13-proxy-de-cotizaciones-de-yahoo-opcional)
14. [Web instalable (PWA)](#14-web-instalable-pwa)
15. [App de iPhone (Capacitor)](#15-app-de-iphone-capacitor)
16. [GitHub: repositorio, Pages y compilación de la app](#16-github-repositorio-pages-y-compilación-de-la-app)
17. [Diseño](#17-diseño)
18. [Pruebas](#18-pruebas)
19. [Cómo trabajar con el código](#19-cómo-trabajar-con-el-código)
20. [Limitaciones conocidas y pendientes](#20-limitaciones-conocidas-y-pendientes)
21. [Checklist final de despliegue](#21-checklist-final-de-despliegue)

---

## 0. Resumen para quien lo va a desplegar

**Qué hay que hacer (en orden):**

1. Subir esta carpeta a un repositorio de GitHub (rama `main`).
2. Activar **GitHub Pages** con origen *GitHub Actions* → el workflow `pages.yml` publica la web.
3. Configurar los **secrets de Apple** y lanzar el workflow `ios.yml` → compila la app de iPhone y la sube a **TestFlight**.
4. (Opcional, más adelante) Supabase para sincronizar web y app, y el proxy de Yahoo para acciones en la web.

**Reglas de oro del código:**

- La app es **HTML + CSS + JavaScript sin framework ni bundler**. Todo acaba en **un único archivo** `dist/index.html`.
- **Nunca editar `dist/index.html` ni `ios-app/www/`** a mano: se generan con `sh build.sh` a partir de `src/`.
- Tras cualquier cambio en `src/`: `sh build.sh` (valida la sintaxis con `node --check`) y, si se puede, `node tests/smoke.mjs`.
- No hay secretos en el código. Las claves de Apple van en GitHub Secrets; las del usuario (Finnhub, Supabase) se guardan en su dispositivo.

**Comandos rápidos (servidor con `git` y `gh` autenticado):**

```bash
cd mision
git init -b main && git add -A && git commit -m "Misión Finanzas 2.0"
gh repo create mision-finanzas --public --source=. --push      # --private si hay GitHub Pro (ver §16.2)
gh api -X POST repos/{owner}/mision-finanzas/pages -f build_type=workflow   # activa Pages por Actions
gh workflow run pages.yml
# Secrets de Apple (ver §16.3) y luego:
gh workflow run ios.yml -f destino=testflight
gh run watch
```

---

## 1. Lo que pidió el usuario (requisitos)

Recopilación literal de lo pedido a lo largo de la conversación, para que nada se pierda:

**Petición inicial**
- Una aplicación de gastos **"híper mega completa"**, como una que vio en un vídeo. Como tiene iPhone, **vale una página web**.
- Llevar más control de sus gastos. Si se puede, **acceso a sus cuentas del banco**; si no, **añadir a mano el balance, los gastos y los ingresos**.
- **Acciones**: poner lo que tiene y ver cómo **sube y baja en tiempo real**.
- **Criptomonedas** y acciones con valor **actualizado en tiempo real** ("muy importante").
- **Mucha personalización**: añadir y eliminar **categorías**, añadir y eliminar **varias cuentas**.
- Poder montarse vistas como: *todas las cuentas X €*, *cuenta principal de gastos X €*, *dinero en cripto X €*, *dinero en acciones X €*, configurables por él.
- Ver **cuánto dinero tiene en otras monedas**.

**Durante el desarrollo**
- **Objetivos**, **resumen del mes**, **resumen del día**, **resumen de gasto** y de **lo ganado**.
- Una **pestaña que sea el resumen de todo**: objetivos, cuentas, lo invertido, el **rendimiento de las inversiones**…
- **Tema claro y oscuro**.
- Además de la web, una **app .ipa para iPhone** (tiene cuenta de desarrollador) y **sincronización** entre la web (en su servidor) y la app.
- **No tiene Mac** → se compila con **GitHub** (acepta un repositorio en GitHub para compilar).
- Segunda vuelta: **mucho más extenso y personalizable**, inspirándose en otras apps del estilo, lo más completo posible.
- La gestionará con **Atajos de iPhone** (se ha resuelto con enlaces `mision://` y la automatización de Apple Pay).
- Ahora: subirlo a GitHub, **publicarlo en GitHub Pages** y **compilar la app** desde su servidor, con esta documentación.

**Aplazado por decisión del usuario:** montar Supabase (sincronización) y su servidor propio. La app funciona sin ellos.

---

## 2. Funcionalidades

### 2.1 Pestañas

| Pestaña | Contenido |
|---|---|
| **Resumen** | Patrimonio total con saludo y gráfico de 30 días, más secciones configurables (ver abajo). |
| **Movimientos** | Lista agrupada por días o **calendario** con el gasto de cada día; navegación por periodos, búsqueda (texto, `#etiqueta`, `>50`, `<10`) y filtros por tipo, cuenta y categoría. |
| **Inversiones** | Cartera total, rentabilidad, cambio del día, reparto, activos con precio en vivo y parpadeo al cambiar, y **lista de seguimiento**. |
| **Análisis** | Vista **mensual o anual**: KPIs, donut por categoría, ingresos contra gastos a 12 meses, origen de los ingresos, qué días gastas más, dónde gastas más, gasto por cuenta, dinero en cuentas, patrimonio, mayores gastos, etiquetas y presupuestos. |
| **Más** | Todas las pantallas de gestión y configuración. |

### 2.2 Secciones del Resumen (activables y ordenables en *Más → Personalizar el resumen*)

`period` Resumen del periodo (Hoy/Semana/Mes/Año: ganado, gastado, balance, tasa de ahorro, media diaria, top categorías) ·
`today` Hoy (gastado hoy frente a tu media; "puedes gastar hoy" si hay presupuesto total) ·
`quick` Accesos rápidos (plantillas de un toque) ·
`goals` Objetivos ·
`groups` Tus bloques (sumas personalizadas) ·
`invest` Rendimiento de inversiones (valor, rentabilidad, hoy, realizada, reparto, mejor y peor) ·
`networth` Desglose del patrimonio (cuentas, cripto, acciones, bienes, deudas, endeudamiento) ·
`accounts` Cuentas ·
`budgets` Presupuestos ·
`upcoming` Próximos cargos (14 días) ·
`watch` Seguimiento de mercados ·
`fx` En otras monedas ·
`recent` Últimos movimientos (3/6/10/15).

### 2.3 Gestión

- **Cuentas.** Tipos: corriente, ahorro, efectivo, tarjeta de crédito (con límite y crédito disponible), exchange/wallet cripto, bróker, **bien** (casa o coche, valor manual), **préstamo o hipoteca** (saldo negativo) y otro.
  - Cada cuenta tiene moneda propia, icono emoji, color y nota.
  - Tiene un **nombre de tarjeta en Wallet** (para Atajos), puede sumar o no al patrimonio, se puede archivar, reordenar y **ajustar su saldo** (como ajuste o como gasto/ingreso).
- **Movimientos.**
  - Tipos: gasto, ingreso, transferencia (entre monedas, con importe de destino) y ajuste.
  - Campos: fecha, concepto con autocompletado, etiquetas y repetición al crearlo.
  - **Divididos** en varias categorías.
  - **Excluidos** de las estadísticas.
  - Se pueden duplicar, guardar como plantilla y **deshacer** justo después de guardar.
- **Apunte rápido.** Se escribe en lenguaje natural: «12,50 mercadona», «+1680 nómina», «3 café en efectivo ayer».
- **Categorías** de gasto e ingreso, con **subcategorías**, emoji, color, orden, opción de ocultar, **palabras clave** (clasifican lo que llega de importaciones y de Atajos) y presupuesto.
- **Presupuestos.**
  - Uno **total** por periodo y otro por categoría, que incluye sus subcategorías.
  - **Arrastre** de lo que sobra o falta al periodo siguiente.
  - Marca de "hoy" en la barra.
  - Cuánto te queda al día y **avisos al 80 % y al 100 %**.
- **Recurrentes.** Diario, semanal, mensual o anual, cada N periodos, con fecha de fin y pausa. Se apuntan solos al abrir la app. Hay un resumen de gasto fijo al mes y al año.
- **Plantillas.** Botones de un toque. Si no tienen importe, lo piden.
- **Objetivos.**
  - Se miden por el patrimonio, un bloque, una cuenta, toda la cripto, todas las acciones o **aportaciones manuales** (se suman o restan).
  - Tienen fecha límite, calculan **cuánto apartar al mes** y cuánto tardarás a tu ritmo actual.
- **Bloques.** Tarjetas del resumen con la suma de lo que elijas: todo, todas las cuentas, toda la cripto, todas las acciones, un tipo de cuenta, cuentas concretas (con sus inversiones) o activos concretos.
- **Inversiones.**
  - Cripto y acciones/ETF.
  - Operaciones: **compra, venta, recompensa/staking y salida**, con comisión y moneda.
  - Opción de mover el dinero de una cuenta.
  - Calcula precio medio, coste, rentabilidad no realizada y realizada, peso y comisiones.
  - **Gráfico histórico 1D/1S/1M/3M/1A/5A** que se recorre con el dedo.
  - Precio manual como alternativa.
- **Divisas.**
  - Dinero por moneda, incluida la exposición de las acciones a su moneda de cotización.
  - Patrimonio convertido a monedas favoritas (también BTC/ETH), conversor y tabla de tipos.

### 2.4 Configuración

- **Apariencia:** tema automático, claro, oscuro o **negro puro (OLED)**, 9 acentos o uno personalizado, tamaño de letra (4 niveles), ocultar céntimos, nombre para el saludo, pantalla al abrir y número de movimientos recientes.
- **Ajustes:** moneda principal, **día de inicio del mes** (1–28, para ir de nómina a nómina), inicio de la semana, abrir con los importes ocultos, **avisos locales** (solo en la app) y datos (ejemplo, borrar todo).
- **Seguridad:** **PIN de 4 dígitos** (guardado como hash SHA-256), bloqueo al salir (al momento o tras 1, 5, 15 o 60 minutos) y botón de "ojo" para difuminar importes.
- **Fuentes de precios:** Binance activado o no, clave de Finnhub, URL del proxy de Yahoo y frecuencia de actualización.
- **Copia de seguridad:** exportar JSON completo o CSV de movimientos, copiar al portapapeles y restaurar desde JSON.
- **Importar del banco:** CSV/XLS/XLSX/ODS (ver §11).
- **Sincronización** con Supabase (ver §12).
- **Atajos de iPhone** (ver §10).

---

## 3. Arquitectura y decisiones

| Decisión | Por qué |
|---|---|
| **Vanilla JS, sin framework ni bundler** | Un solo archivo que funciona en cualquier hosting estático, en GitHub Pages y dentro de la app nativa sin cambios. Cero dependencias en tiempo de ejecución. |
| **Código en `src/` en varios archivos y concatenado** | Mantenible por partes. `build.sh` los junta en el orden correcto en `dist/index.html`. Todo comparte ámbito global (un solo `<script>`). |
| **Estado en `localStorage`** | Privacidad: los datos financieros no salen del dispositivo. La sincronización con Supabase es opcional. |
| **Renderizado por plantillas de texto** | Cada pantalla es una función `VIEWS[ruta](P)` que devuelve HTML. Los clics se delegan con `data-action` / `data-go` / `data-tab` → objeto `ACT`. |
| **Gráficos SVG propios** (`charts.js`) | Sin librerías; funcionan sin conexión y respetan el tema. |
| **Capacitor para iOS** | Envuelve la misma web en una app nativa. Con `CapacitorHttp` las peticiones van por HTTP nativo (sin CORS), así que **Yahoo Finance funciona directamente** en la app. |
| **Compilación en GitHub Actions (macOS)** | El usuario no tiene Mac. Firma automática con una clave de API de App Store Connect → TestFlight. |
| **Supabase para sincronizar** | El usuario ya trabaja con Supabase. Una fila JSON por usuario con RLS. Sin servidor propio. |

**Única dependencia externa opcional en tiempo de ejecución:** SheetJS (`xlsx 0.18.5` desde cdnjs), que se carga **solo** al importar un Excel.
**Fuentes:** Google Fonts (*Martian Mono* para cifras y *Onest* para texto), con fuentes del sistema como respaldo.

---

## 4. Estructura de carpetas

```
mision/
├── DOCUMENTACION.md              ← este documento
├── README.md                     ← guía corta de uso y despliegue
├── build.sh                      ← junta src/ → dist/index.html y copia a ios-app/www/
├── .gitignore                    ← node_modules/, ios-app/ios/, ios-app/node_modules/
├── .github/workflows/
│   ├── pages.yml                 ← publica la web en GitHub Pages (push a main)
│   └── ios.yml                   ← compila la app en macOS y la sube a TestFlight (manual)
├── src/                          ← CÓDIGO FUENTE (editar aquí)
│   ├── head.html                 ← <head>, metas PWA/iOS, fuentes y TODO el CSS (tokens, temas, componentes)
│   ├── body.html                 ← esqueleto: cabecera, <main id="view">, botón +, pestañas, hoja inferior, toast
│   ├── core.js                   ← utilidades, formato, constantes, estado, cálculos, datos de ejemplo
│   ├── prices.js                 ← divisas, cripto (Binance/CoinGecko), acciones (Yahoo/Finnhub), históricos
│   ├── charts.js                 ← gráficos SVG: spark, lineChart (con scrub), barsChart, bars1, donut
│   ├── views.js                  ← router, render, iconos y todas las pantallas y secciones del resumen
│   ├── import.js                 ← importación CSV/Excel del banco
│   ├── forms.js                  ← hojas y formularios, acciones ACT, tema, init()
│   ├── extra.js                  ← Atajos (mision://), apunte rápido, plantillas, PIN, avisos, apariencia, histórico
│   ├── sync.js                   ← sincronización con Supabase
│   └── main.js                   ← init();
├── dist/                         ← WEB PUBLICABLE (generada)
│   ├── index.html                ← toda la app en un archivo (~340 KB)
│   ├── manifest.webmanifest      ← PWA
│   ├── sw.js                     ← service worker (sin conexión)
│   ├── icon-192.png, icon-512.png, apple-touch-icon.png, icon-1024.png
│   └── supabase/functions/quotes/index.ts   ← proxy de Yahoo (Edge Function, opcional)
├── ios-app/                      ← PROYECTO CAPACITOR
│   ├── package.json              ← Capacitor 7 + plugins app, haptics, local-notifications, status-bar
│   ├── capacitor.config.json     ← appId es.david.mision, webDir www, CapacitorHttp activado
│   ├── resources/icon.png        ← icono 1024×1024 (fuente para @capacitor/assets)
│   └── www/                      ← copia de dist (generada por build.sh)
└── tests/
    └── smoke.mjs                 ← prueba de humo con Playwright
```

---

## 5. Compilación (`build.sh`)

```sh
sh build.sh
```

1. Concatena, **en este orden** (importa):
   `core.js → prices.js → charts.js → views.js → import.js → forms.js → extra.js → sync.js → main.js`
2. Valida la sintaxis con `node --check` (falla el build si hay error).
3. Genera `dist/index.html` = `head.html` + `body.html` + `<script>…</script>` + `</body></html>`.
4. Copia la web y los iconos a `ios-app/www/`.

**Por qué el orden:** `extra.js` sobrescribe `applyTheme` y añade entradas a `ACT`, que se definen en `forms.js`. `sync.js` usa `ACT` y `TITLES`. `main.js` llama a `init()` al final, cuando todo está declarado.

Requisito: **Node.js ≥ 18** (solo para `node --check`; la app no usa Node).

---

## 6. Módulos del código

### `core.js`
- **Utilidades:** `$`, `$$`, `uid`, `esc` (escapar HTML, **usar siempre** al pintar datos del usuario) y fechas (`ymd`, `today`, `parseYmd`, `addDays`, `addMonths`, `monthEnd`, `dayLabel`, `shortDate`, `ago`).
- **Números:**
  - `parseMoney` entiende formato español, «1.234,56», «-12,50 €», paréntesis y guiones Unicode.
  - `parseQty` acepta coma o punto decimal y no admite separador de miles.
  - `fmt(n, ccy, {sign, dec, compact})` usa `Intl` es-ES, respeta *ocultar céntimos* y admite cripto como moneda.
  - También `fmtPrice`, `fmtQty`, `fmtPct` y `pcls` (clase pos/neg).
- **Constantes:** `ACC_TYPES`, `ACC_ICONS`, `PALETTE`, `CG_IDS` (ticker → id de CoinGecko), `STABLES`, `HOME_SECTIONS`, `FALLBACK_FX`.
- **Estado:** `S` (global), `blankState()`, `migrate()` (rellena los campos nuevos al cargar datos antiguos), `load()`, `save()` (con retardo) y `saveNow()` (que también llama a `Sync.schedule()`).
- **Cálculos:**
  - Saldos y patrimonio: `balances(upto)` y `portfolio()`, la foto completa del patrimonio en moneda base.
  - Inversiones: `holding(asset)` (precio medio) y `priceOf` / `resolveProvider`.
  - Divisas: `conv(n, from, to)`.
  - Bloques y objetivos: `groupValue` y `goalInfo`.
  - Mes financiero y periodos: `FR(mk)`, `mkOf(date)`, `curMk()`, `periodRange(p)`.
  - Flujos y presupuestos: `flows(from, to)` (incluye divisiones y excluidos), `catSpend` (incluye subcategorías) y `budgetAvail` (con arrastre).
  - Recurrentes: `nextDate` y `runRecurring`.
  - Históricos: `cashHistory`, `recordSnapshot` y `nwSeries`.
- **Datos de ejemplo:** `demoState()`. Se cargan en el primer arranque; el aviso "Empezar de cero" los borra.

### `prices.js`
Estado `PX` (estado de cada fuente, ticks por activo, parpadeos, WebSockets, temporizadores).
- `NATIVE` indica si corre dentro de la app de Capacitor. `yahooOK()` indica si hay proxy o está en la app nativa.
- Tipos de cambio: `refreshFx`.
- Cripto: `pollCrypto` (CoinGecko) y `connectBinance` (WebSocket).
- Acciones: `pollYahoo`, `yahooQuotes`, `yahooChart`, `pollFinnhub` y `connectFinnhub`.
- Búsqueda y proxy: `searchCrypto`, `searchStocks` y `testProxy`.
- Gráficos históricos: `priceHistory(asset, rango)`, con caché de 5 minutos y un máximo de unas 240 muestras.
- Ciclo: `startPrices()` y `restartFeeds()`. El indicador de la cabecera («En directo») se actualiza con `liveState`/`updateLive`.

### `charts.js`
- `spark`: línea mínima.
- `lineChart(series, {scrub, cls})`: con ejes. Con `scrub`, expone las coordenadas en `data-pts` para recorrerla con el dedo.
- `barsChart`: ingresos contra gastos.
- `bars1`: una sola serie, con línea de media.
- `donut`.
- `niceTicks` y `axisFmt`: escalas.

### `views.js`
- **Router:**
  - `UI.route`: `home`, `txs`, `inv`, `stats`, `more`, `more/<sub>`.
  - `go(ruta, {reset, acc, cat, month})`, `back()`.
  - `render()` repinta la vista actual; `renderLive()` repinta cuando llegan precios, sin romper un campo con el foco.
- **Tablas de pantallas:** `VIEWS[ruta](P) → html`, `AFTER[ruta]()` (enlaza eventos de inputs) y `HOME[clave](P) → sección del resumen`.
- **Piezas:** `txRow`, `accRow`, `assetRow`, `watchRow`, `goalCard`, `groupCard`, `budgetRows`, `recRow`, `calHtml`, `catTree` (padres seguidos de hijas), `allocHtml`, `hbars`, `ICONS`/`svg()`, `ACCENTS`.

### `forms.js`
- **Hoja inferior:** `openSheet({title, html, onMount, live})` y `closeSheet()`.
- **Aviso:** `toast(msg, {label, fn})`, con botón de acción.
- **Formularios:** `openTxForm` (divisiones, apunte rápido, plantilla), `openAccountForm`, `openAccount`, `openAdjust`, `openGoalForm`, `openGoal`, `openGroupForm`, `openGroup`, `openCatForm`, `openRecForm`, `openAssetNew`, `openAssetDetails`, `openAsset` (con histórico), `openOpForm`, `openAssetEdit` y `openPriceStatus`.
- **Exportar e importar:** `download`, `exportJson`, `exportCsv`, `pickFile`.
- **Confirmaciones:** `arm(el)` pide "toca otra vez" en los botones `data-confirm`; `confirmSheet()`. No se usa `confirm()`.
- **`ACT`:** todas las acciones (lista en §19.3).
- **`applyTheme()`** (sobrescrita en `extra.js`) e **`init()`**.

### `extra.js`
- **Atajos:** `parseLink`, `handleLink`, `initLinks` (hash de la web y `appUrlOpen` / `getLaunchUrl` de Capacitor, con protección contra enlaces duplicados).
- **Interpretar texto:**
  - `parseQuick(texto)` (apunte rápido).
  - Detección de cuenta y categoría: `matchAccount`, `findCat`, `guessCat` (palabras clave) y `prevCatFor` (categoría usada la última vez con ese concepto).
- **Plantillas:** `useTemplate`, `openTplForm`.
- **Seguimiento:** `addWatch`.
- **Histórico de precios:** `histHtml` y `bindScrub`.
- **Evolución de una categoría:** `openCatStats(id)`.
- **Apariencia:** `applyLook()` inyecta `<style id="lookCss">` con el acento, su variante clara y `--z` (tamaño de letra).
- **PIN:** `LOCK`, `hashPin`, `lockUI`, `lockNow`, `startSetPin`, `pinKey`.
- **Presupuestos:** `budgetAlert(movimiento)`.
- **Avisos y vibración:** `scheduleNotifs()` (avisos locales, ids 1000–1999) y `haptic()`.
- **Pantallas:** `more/shortcuts` (con generador de enlaces) y `more/install`.

### `import.js`
`parseCSV` (detecta el delimitador), `readSheetFile` (CSV o Excel con SheetJS bajo demanda), `guessImport` (fila de cabecera y columnas), `parseDateAny`, `importItems` (duplicados y categoría) y `doImport`.

### `sync.js`
Objeto `Sync` (login y registro con la API de Auth, refresco de token, `run()`, `push()`, `apply()`, `schedule()`), `SYNC_SQL` y la pantalla `more/sync`.

---

## 7. Modelo de datos

Todo el estado vive en el objeto global `S`, que se serializa en `localStorage["mision.finanzas.v1"]`.

```js
S = {
  v: 1, demo: bool, createdAt: 'YYYY-MM-DD',
  settings: {
    base: 'EUR', theme: 'auto'|'light'|'dark'|'black', privacy: bool,
    finnhubKey: '', yahooProxy: '', refreshSec: 30, binance: true,
    favCcy: ['USD','GBP','CHF','BTC'],
    home: [{ k: 'period', on: true }, …],          // orden y visibilidad del resumen
    period: 'day'|'week'|'month'|'year',
    name: '', accent: 'malva'|'azul'|'verde'|'ambar'|'coral'|'lila'|'turquesa'|'rojo'|'mono'|'custom', customAccent: '#hex',
    textSize: 's'|'m'|'l'|'xl', hideCents: bool, weekStart: 1|0|6, monthStart: 1..28,
    startTab: 'home'|'txs'|'inv'|'stats', recentCount: 6,
    pinHash: '', lockAfter: 0 (minutos), notifyRecurring: true, notifyHour: 9,
    budgetTotal: 0, budgetAlerts: true, shortcutMode: 'auto'|'confirm',
  },
  accounts:   [{ id, name, type, currency, initial, color, icon, includeInTotal, archived, order, cardAlias, note, limit }],
  categories: [{ id, kind: 'expense'|'income', name, icon, color, budget, keywords: 'a, b', parentId, rollover, hidden }],
  txs:        [{ id, type: 'expense'|'income'|'transfer'|'adjust', amount (>0; en ajuste lleva signo), accountId,
                 toAccountId, toAmount, categoryId, date, note, tags: [],
                 splits: [{ categoryId, amount }], excl, recId, imp, src: 'atajo'|'plantilla' }],
  recurring:  [{ id, name, tpl: {…campos de movimiento sin id ni fecha…}, freq: 'daily'|'weekly'|'monthly'|'yearly',
                 interval, day (ancla), next: 'YYYY-MM-DD', end, active }],
  assets:     [{ id, kind: 'crypto'|'stock', symbol, name, cgId, ySymbol, provider: 'auto'|'coingecko'|'yahoo'|'finnhub'|'manual',
                 quoteCcy, accountId, manualPrice, manualAt, color, archived, watch,
                 ops: [{ id, side: 'buy'|'sell'|'reward'|'out', qty, price, fee, ccy, date, cashAccountId }] }],
  groups:     [{ id, name, color, items: [{ t: 'all' } | { t: 'cash' } | { t: 'kind', v: 'crypto'|'stock' } | { t: 'atype', v } | { t: 'account', id } | { t: 'asset', id }] }],
  goals:      [{ id, name, icon, color, target, ccy, deadline, source: { t: 'nw'|'group'|'account'|'kind'|'manual', id?, v? }, manual }],
  templates:  [{ id, name, icon, tpl: { type, amount (0 = preguntar), accountId, toAccountId, categoryId, note, tags } }],
  snapshots:  [{ d: 'YYYY-MM-DD', v: patrimonio, c: moneda }],   // uno por día, máximo 1500
  cache: { fx: { rates (por 1 USD), t, upd, src }, prices: { [assetId]: { p, ccy, ch, pc, t, src } } },
  lastAcc: id                                                   // última cuenta usada
}
```

**Otras claves de `localStorage`:**
- `mision.sync.v1`: sesión de Supabase de este dispositivo (**no** va en la copia de seguridad).
- `mision.lastLink`: protección contra enlaces duplicados.
- `mision.copia-antes-de-sincronizar`: copia local si la nube sobrescribe.

**Migraciones:** al añadir un campo, ponle su valor por defecto en `blankState()`; `migrate()` rellena los ajustes que falten. Si es una lista nueva, añádela a la lista de arrays de `migrate()`. Las secciones nuevas de `HOME_SECTIONS` se añaden solas al final del orden guardado.

---

## 8. Lógica de negocio

- **Saldo de una cuenta.** `initial` + ingresos − gastos − transferencias salientes + transferencias entrantes (`toAmount`) + ajustes, **más** el efecto de las operaciones de inversión con `cashAccountId`: una compra resta qty×precio+comisión y una venta suma qty×precio−comisión, convertidas a la moneda de la cuenta.
- **Préstamo o hipoteca.** Se guarda con saldo inicial **negativo**; en el formulario se escribe en positivo y se invierte al crearla. Las cuotas son **transferencias** hacia la cuenta de deuda, que la acercan a 0.
- **Patrimonio.** Suma de las cuentas no archivadas con `includeInTotal`, convertidas a la moneda base, más el valor de los activos (no los de seguimiento) cuya cuenta sume al total.
- **Inversiones (precio medio).**
  - Compra: suma cantidad y coste.
  - Recompensa: suma cantidad a coste 0.
  - Venta: resta cantidad y coste medio proporcional, y apunta la ganancia realizada.
  - Salida: resta cantidad y coste sin ganancia realizada.
  - El coste se convierte a la moneda base **al cambio actual**.
- **Cambio del día.** Sale del `%` de 24 h (cripto) o del cierre anterior (acciones) de la fuente en vivo.
- **Conversión de divisas.** `conv()` usa tipos por 1 USD. Los códigos cripto (BTC, ETH…) se convierten con su precio en vivo.
- **Mes financiero.** Con `monthStart = N > 1`, el periodo `YYYY-MM` va del día N de ese mes al día N−1 del siguiente. Afecta al resumen del mes, los presupuestos, el análisis, la navegación de movimientos y el calendario.
- **Flujos y estadísticas.** Solo gastos e ingresos no excluidos. Las divisiones reparten el importe entre categorías, y las subcategorías suman en su categoría principal (`byParent`).
- **Presupuestos.** `budgetAvail(c, periodo)` es el presupuesto más, si hay arrastre, lo que sobró o faltó del periodo anterior (de forma recursiva, hasta 12 periodos y no antes de `createdAt`). Se avisa al cruzar el 80 % y el 100 %.
- **Recurrentes.** En cada arranque y al volver a la app, `runRecurring()` crea los movimientos pendientes hasta hoy y avanza `next`. Los mensuales conservan el día ancla (el 31 pasa a 30 o a 28 según el mes).
- **Instantáneas.** El patrimonio del día se guarda a los 20 s de abrir, cada 20 s si cambian los precios y al salir. El gráfico de 30 días usa las instantáneas o, si aún no hay, el saldo en cuentas calculado.

---

## 9. Precios en tiempo real

| Qué | Fuente | Endpoint | Frecuencia |
|---|---|---|---|
| Divisas | ExchangeRate-API (abierto) | `https://open.er-api.com/v6/latest/USD` | cada hora (caché 55 min) |
| Divisas (respaldo) | Frankfurter / BCE | `https://api.frankfurter.dev/v1/latest?base=USD` | si falla la anterior |
| Cripto en vivo | Binance WebSocket | `wss://stream.binance.com:9443/stream?streams=btcusdt@miniTicker/…` (alternativa `wss://data-stream.binance.vision`) | cada tick |
| Cripto (cualquiera) | CoinGecko | `/api/v3/simple/price?ids=…&vs_currencies=usd&include_24hr_change=true` | máx(60 s, ajuste) |
| Búsqueda cripto | CoinGecko | `/api/v3/search?query=` | al escribir |
| Histórico cripto | CoinGecko | `/api/v3/coins/{id}/market_chart?vs_currency=usd&days=N` | caché 5 min |
| Acciones | Yahoo Finance | `https://query1.finance.yahoo.com/v8/finance/chart/{SYM}?range=…&interval=…` | ajuste (15–300 s) |
| Búsqueda acciones | Yahoo Finance | `https://query1.finance.yahoo.com/v1/finance/search?q=` | al escribir |
| Acciones EE. UU. (alternativa) | Finnhub (clave gratis) | `/api/v1/quote`, `/api/v1/search`, `wss://ws.finnhub.io` | ajuste y ticks |

**Reglas:**
- **Yahoo** se llama **directamente en la app** (CapacitorHttp evita CORS). En la **web** necesita el **proxy** (§13) porque Yahoo no permite CORS.
- `resolveProvider(asset)`:
  - Cripto: `crypto` (Binance + CoinGecko), `coingecko` o `manual`.
  - Acciones: `yahoo` si hay proxy o está en la app; si no, `finnhub` si hay clave y el ticker es de EE. UU.; si no, `manual`.
- Precios en peniques (`GBp`, `ZAc`, `ILA`) se dividen entre 100 (`normCcy`).
- Si Binance tiene un precio de menos de 30 s, no se sobrescribe con CoinGecko.
- Con la app en segundo plano se pausan WebSockets y consultas; al volver se reconecta.
- El atributo de ExchangeRate-API («Rates By Exchange Rate API») aparece en *Divisas*, como exige su licencia.

---

## 10. Atajos de iPhone y enlaces `mision://`

La app registra el esquema **`mision://`** (en `ios.yml`, con `CFBundleURLTypes`). En la web, lo mismo funciona con el *hash*: `https://…/index.html#nuevo?importe=…`, aunque Safari y la app no comparten datos.

| Enlace | Acción |
|---|---|
| `mision://nuevo?importe=12,50&concepto=Mercadona&tarjeta=Visa%20BBVA` | Apunta un gasto. |
| `mision://ingreso?importe=1680&concepto=Nómina` | Apunta un ingreso (también `tipo=ingreso`). |
| `mision://transferencia?importe=250&cuenta=Principal&destino=Ahorro` | Apunta una transferencia. |
| `mision://rapido?texto=3%20café%20en%20efectivo%20ayer` | Apunte en lenguaje natural. |
| `mision://plantilla?nombre=Café` (opcional `&importe=`) | Usa una plantilla. |
| `mision://abrir?pantalla=inversiones` | Abre una pantalla: resumen, movimientos, inversiones, analisis, presupuestos, objetivos, cuentas, divisas. |

**Parámetros de `nuevo`:**
- `importe` (formato libre; el signo da igual), `concepto` o `comercio`, `tipo` (gasto, ingreso o transferencia).
- `cuenta` (nombre de la cuenta), `tarjeta` (se busca en el campo *Nombre de la tarjeta en Wallet* de cada cuenta, admite varios separados por comas), `destino`.
- `categoria` (nombre), `fecha` (hoy, ayer, dd/mm/aaaa o aaaa-mm-dd), `etiquetas` y `confirmar` (1 abre el formulario, 0 guarda directo).

**Comportamiento:**
- **Categoría automática:** la última usada con ese concepto; si no hay, por palabras clave de las categorías; si no, «Otros».
- **Modo** (en *Más → Atajos*):
  - *Guardar directo*: se apunta y sale un aviso con «Editar».
  - *Revisar antes*: se abre el formulario rellenado.
  - Si falta el importe, siempre se abre el formulario.
- El mismo enlace recibido dos veces en 90 s se ignora (iOS a veces lo entrega doble al arrancar).
- Con el PIN activo, el enlace espera a que se desbloquee.

**Automatización de Apple Pay** (Atajos → Automatización → + → **Transacción**):
1. Elegir las tarjetas, dejar todas las categorías, marcar **Ejecutar inmediatamente** y desactivar «Notificar al ejecutar». Pulsar *Nueva automatización en blanco*.
2. Añadir la acción **Codificar URL** con la variable *Comerciante* (*Merchant*).
3. Añadir **Abrir URL**: `mision://nuevo?importe=[Importe]&concepto=[URL codificada]&tarjeta=[Tarjeta o pase]`.
4. En la app, en *Más → Atajos*, poner a cada cuenta el nombre exacto de su tarjeta en Cartera.

**Otros atajos:**
- **Siri:** Solicitar entrada → Codificar URL → `mision://rapido?texto=…`.
- **Botón de acción o widget:** `mision://plantilla?nombre=…`.

---

## 11. Importar extractos del banco

*Más → Importar del banco*. Todo se procesa en el dispositivo.

- **Formatos:** CSV (detecta `;` `,` tabulador `|` y codificación Windows-1252) y **XLS, XLSX, ODS** (carga SheetJS 0.18.5 desde cdnjs solo en ese momento).
- **Detección:** busca la fila de cabecera (la primera con «fecha» y 3 o más celdas) y las columnas de fecha, concepto e importe (o **cargo y abono** separados). Todo se puede corregir a mano.
- **Opciones:** cuenta de destino, invertir signos y **saltar duplicados** (misma cuenta, fecha e importe).
- **Clasificación** por palabras clave de las categorías (vienen precargadas para Mercadona, Lidl, Repsol, Netflix, Iberdrola, etc.).
- Vista previa de 12 filas con el recuento de importados, duplicados e ignorados. Los importados se marcan `imp: 1`.

**Conexión directa con el banco (PSD2):** no implementada. La opción gratuita para uso personal es **Enable Banking** en modo restringido (solo cuentas propias). Necesita un backend que firme las peticiones con una clave privada, por ejemplo otra Edge Function de Supabase. GoCardless Bank Account Data (Nordigen) no admite registros nuevos.

---

## 12. Sincronización con Supabase (opcional)

**Estado:** implementada y **desactivada** hasta que el usuario la configure en *Más → Sincronización*. Aplazada por decisión suya.

**SQL** (SQL Editor de Supabase; también se puede copiar desde la app):

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

**Configuración en Supabase:** Authentication → Providers → Email (desactivar *Confirm email* si no se quiere confirmar el correo). En la app se usan la **Project URL** y la clave **anon public**.

**Funcionamiento:**
- **API sin librería:**
  - Autenticación: `POST /auth/v1/signup`, `POST /auth/v1/token?grant_type=password|refresh_token`.
  - Datos: `GET /rest/v1/mision_state?select=updated_at` y `POST /rest/v1/mision_state?on_conflict=user_id` con `Prefer: resolution=merge-duplicates,return=representation`.
- **Qué se sube:** todo `S` menos `cache`. Solo se sube si cambió algo distinto de las instantáneas.
- **Cuándo:** a los 2,5 s de un cambio, al volver a la app y cada 45 s.
- **Conflictos:** gana el cambio más reciente (`updated_at` del servidor frente a la hora del cambio local). Si la nube sobrescribe cambios locales, se guarda una copia en `mision.copia-antes-de-sincronizar`. Las instantáneas se **fusionan** por fecha.
- **Primer inicio de sesión:** si hay datos en los dos lados, pregunta cuáles conservar.

---

## 13. Proxy de cotizaciones de Yahoo (opcional)

Solo hace falta para que las **acciones se actualicen solas en la web**; la app de iPhone no lo necesita.
Está en `dist/supabase/functions/quotes/index.ts` (Deno, Supabase Edge Function):

```bash
cd dist                          # la carpeta que contiene supabase/
supabase login
supabase link --project-ref TU_REF
supabase functions deploy quotes --no-verify-jwt
```

**Endpoints:**
- `?symbols=AAPL,SAN.MC` → `{ quotes: [{ symbol, price, prevClose, currency, name, marketState, time }] }`
- `?search=inditex` → `{ results: [{ symbol, name, exchange, type }] }`
- `?chart=SAN.MC&range=1mo&interval=1d` → `{ result }`, el objeto *chart* de Yahoo para los históricos.

La URL `https://TU_REF.supabase.co/functions/v1/quotes` se pega en *Más → Fuentes de precios* y se comprueba con **Probar proxy**. Funcionaría igual como Cloudflare Worker adaptando el `Deno.serve` a `export default { fetch }`.

---

## 14. Web instalable (PWA)

- **`manifest.webmanifest`:** nombre «Misión Finanzas», `start_url` y `scope` `./` (rutas relativas, funciona en subcarpetas como GitHub Pages), `display: standalone`, colores `#0e0c11` e iconos de 192 y 512 px (este último también *maskable*).
- **`sw.js`** (caché `mision-v1`):
  - Mismo origen: red primero y caché si no hay conexión.
  - Fuentes y cdnjs: caché primero.
  - APIs de precios: siempre a la red.
  - Solo se registra en `https:` o `localhost`. Si cambia la lista de archivos del *shell*, sube la versión de `CACHE`.
- **iOS:** metas `apple-mobile-web-app-*`, `viewport-fit=cover` y márgenes con `env(safe-area-inset-*)`.
- **Instalar desde Safari:** Compartir → Añadir a pantalla de inicio.
- **Iconos:** barras horizontales que se desvanecen con la central en malva, un guiño al fondo de pantalla del usuario («FOCUS ON THE MISSION»). Generados con Pillow.

---

## 15. App de iPhone (Capacitor)

**`ios-app/capacitor.config.json`**
```json
{
  "appId": "es.david.mision", "appName": "Misión", "webDir": "www",
  "backgroundColor": "#0e0c11",
  "ios": { "contentInset": "never", "backgroundColor": "#0e0c11", "limitsNavigationsToAppBoundDomains": false },
  "plugins": { "CapacitorHttp": { "enabled": true }, "LocalNotifications": { "iconColor": "#e4b3cb" } }
}
```
> No poner `ios.scheme` = «mision»: chocaría con el esquema de enlaces `mision://`.

**Plugins** (Capacitor 7, `package.json`):
- `@capacitor/app`: enlaces entrantes (`appUrlOpen`, `getLaunchUrl`).
- `@capacitor/haptics`: vibración al guardar y en avisos.
- `@capacitor/local-notifications`: aviso el día antes de cada cargo recurrente, a la hora elegida; hasta 60 pendientes con ids 1000–1999.
- `@capacitor/status-bar`: color de la barra según el tema.

El código accede a ellos por `window.Capacitor.Plugins.*` (no hay imports) y todo se comprueba antes de usarlo, así que la web funciona igual sin Capacitor.

**Cambios en `Info.plist`** (los aplica `ios.yml` con PlistBuddy tras `npx cap add ios`):
- `CFBundleURLTypes` → esquema `mision`.
- `ITSAppUsesNonExemptEncryption = false` (evita la pregunta de cifrado en TestFlight).
- `CFBundleDisplayName = Misión` y `UIStatusBarStyle`.

**La carpeta `ios-app/ios/` no se sube** (`.gitignore`): se genera en cada compilación.

**Si alguna vez hay un Mac:**
```bash
sh build.sh && cd ios-app && npm install && npx cap add ios && npm run icons && npm run sync && npm run open
```
y firmar en Xcode.

---

## 16. GitHub: repositorio, Pages y compilación de la app

### 16.1 Subir el repositorio
```bash
cd mision
git init -b main
git add -A
git commit -m "Misión Finanzas 2.0"
gh repo create mision-finanzas --public --source=. --push     # ver 16.2 para privado
```

### 16.2 GitHub Pages (web)
- Workflow: **`.github/workflows/pages.yml`**. Se ejecuta en cada push a `main` que toque `src/`, `dist/` o `build.sh`, y también a mano.
  - Pasos: `sh build.sh`, copia a `_site/` solo la web (sin `supabase/` ni el icono de 1024) y la publica.
- **Activación, una vez:** Settings → Pages → *Source: GitHub Actions*, o bien:
  ```bash
  gh api -X POST repos/OWNER/mision-finanzas/pages -f build_type=workflow
  ```
- **URL:** `https://OWNER.github.io/mision-finanzas/`.
- **Importante:** en cuentas **gratuitas**, GitHub Pages **solo funciona con repositorios públicos**. Para un repo privado con Pages hace falta GitHub Pro/Team.
  - El código no contiene secretos ni datos del usuario (los datos viven en su dispositivo y las claves de Apple en Secrets), así que un repo público es seguro.
  - Si se quiere privado sin Pro, alternativa: repo privado para compilar y la web en su servidor (copiar `dist/`).
- **Dominio propio (opcional):** Settings → Pages → Custom domain, más un `CNAME` en el DNS.

### 16.3 App de iPhone → TestFlight
Workflow: **`.github/workflows/ios.yml`** (manual, `workflow_dispatch`, entrada `destino`: `testflight` | `adhoc`). Runner `macos-15`.

**Qué hace:**
1. `sh build.sh`.
2. En `ios-app`: sustituye el Bundle ID, `npm install`, `npx cap add ios`, genera los iconos (`@capacitor/assets`), `npx cap sync ios` y los cambios de `Info.plist` (§15).
3. Escribe la clave `.p8` en `~/private_keys/`.
4. `xcodebuild archive` con **firma automática** y `-allowProvisioningUpdates` más la clave de API. Parámetros: `MARKETING_VERSION=2.0`, `CURRENT_PROJECT_VERSION=${{ github.run_number }}`.
5. `xcodebuild -exportArchive`:
   - `testflight`: `method=app-store-connect`, `destination=upload`, se sube directamente a App Store Connect.
   - `adhoc`: `method=release-testing`, y el `.ipa` queda como artefacto.

**Preparación en Apple (una vez, desde el navegador):**
1. developer.apple.com → Identifiers → `+` → App ID explícito **`es.david.mision`** (u otro; entonces definir la variable `BUNDLE_ID`).
2. appstoreconnect.apple.com → Apps → `+` → Nueva app iOS con ese Bundle ID (nombre «Misión» o «Misión Finanzas DR» si está ocupado).
3. App Store Connect → Usuarios y acceso → Integraciones → **App Store Connect API** → `+` con rol **Admin** → descargar el `.p8` y anotar *Key ID* e *Issuer ID*.
4. *Team ID* en developer.apple.com → Membership.

**Secrets del repositorio:**
```bash
gh secret set APPLE_TEAM_ID  --body "XXXXXXXXXX"
gh secret set ASC_KEY_ID     --body "XXXXXXXXXX"
gh secret set ASC_ISSUER_ID  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
gh secret set ASC_KEY_P8     < AuthKey_XXXXXXXXXX.p8
gh variable set BUNDLE_ID    --body "es.david.mision"     # solo si cambia
```

**Compilar y seguir la ejecución:**
```bash
gh workflow run ios.yml -f destino=testflight
gh run list --workflow ios.yml --limit 1
gh run watch
gh run view --log-failed          # si falla
gh run download -n Mision-ipa     # solo con destino=adhoc
```

**Tras subir a TestFlight:**
- Apple procesa la compilación (entre 5 y 30 minutos).
- En App Store Connect → TestFlight hay que añadir al usuario como **probador interno** y responder al cumplimiento de exportación si lo pide (ya se declara que no usa cifrado propio).
- Se instala desde la app **TestFlight**. Las compilaciones caducan a los **90 días**; basta con relanzar el workflow.

**Errores típicos:**

| Síntoma | Solución |
|---|---|
| `No Accounts` o `authentication` | Revisar `ASC_KEY_ID`, `ASC_ISSUER_ID` y `ASC_KEY_P8` (el contenido completo del .p8, con BEGIN y END). |
| `No profiles for 'es.david.mision'` | Registrar el App ID (paso 1) o comprobar que el rol de la clave es Admin. |
| El upload falla con «No suitable application records» | Falta crear la app en App Store Connect (paso 2). |
| Número de compilación duplicado | Relanzar (`run_number` sube) o cambiar `MARKETING_VERSION`. |
| Capacitor 8 o SPM | El workflow detecta si hay `.xcworkspace` (CocoaPods) o solo `.xcodeproj`. |

---

## 17. Diseño

- **Identidad:** oscura por defecto, inspirada en la pantalla de bloqueo del usuario (reloj malva sobre negro y texto monoespaciado «FOCUS ON THE MISSION»). Las cifras grandes van en **Martian Mono** con el color de acento; el texto, en **Onest**.
- **Tokens CSS** (`src/head.html`): `--bg --surface --surface-2 --line --fg --muted --faint --accent --accent-ink --accent-soft --pos --neg --warn (+ -soft) --scrim --shadow --f-num --f-body --r`.
  - Oscuro en `:root`.
  - Claro en `@media (prefers-color-scheme: light) :root:not([data-theme="dark"]):not([data-theme="black"])` y en `:root[data-theme="light"]`.
  - Negro puro en `:root[data-theme="black"]`.
  - El acento y el tamaño de letra (`--z`, que se aplica con `zoom` en `main` y en la hoja) los sobrescribe `applyLook()` en `<style id="lookCss">`.
- **Colores semánticos:** verde para lo positivo, rojo para lo negativo y ámbar para avisos. Los gastos se muestran en color neutro y los ingresos en verde.
- **Componentes:** `.card`, `.list` + `.row`, `.kpis` + `.kpi`, `.seg` (controles segmentados con `aria-pressed`), `.chip`, `.bar` (con `.budget`), `.gcard` (bloques), `.qchip` (plantillas), `.cal` + `.cday` (calendario), `.catgrid` + `.catbtn`, `.sheet` (hoja inferior), `.btn` (`.primary`, `.danger`, `.armed`, `.sm`, `.block`), `.code-box`, `#lock` (teclado del PIN).
- **Móvil primero:** ancho máximo de 760 px, márgenes laterales de 16 px, pestañas y botón + fijos con zonas seguras. Los inputs usan 16 px para que iOS no haga zoom. Se respeta `prefers-reduced-motion`.
- **Privacidad visual:** todo importe va dentro de `.amt`; con `body.privacy` se difumina.

---

## 18. Pruebas

**Prueba de humo automática** (`tests/smoke.mjs`, Playwright + Chromium):
```bash
npm i -D playwright && npx playwright install chromium
sh build.sh && node tests/smoke.mjs
```
- Carga los datos de ejemplo en tema claro y oscuro y recorre **las 24 pantallas** (todas las entradas de `TITLES`).
- Abre y cierra 18 formularios, comprueba que `mision://nuevo` apunta un gasto y que `parseQuick` interpreta bien.
- Falla si hay errores de JavaScript o **scroll horizontal**.
- Devuelve código 1 si algo falla, así que sirve en CI.

**Probado durante el desarrollo** (Chromium, 390×844, claro y oscuro):
- Todas las pantallas y formularios sin errores de consola y sin desbordamiento horizontal.
- Crear gastos, transferencias entre monedas con autoconversión y gastos divididos (validación de la suma).
- Importar un CSV español con cargo y abono, fechas dd/mm/aaaa y miles con punto.
- Enlaces `nuevo`, `plantilla` y `rapido` (importe con `€` y espacio duro, tarjeta a cuenta, comercio a categoría).
- Calendario, análisis anual, mes financiero con inicio el día 25, tema negro, acento y tamaño de letra.
- Crear, bloquear y desbloquear el PIN.

**No se ha podido probar en el entorno de desarrollo** (sin salida a esas APIs ni macOS):
- Las respuestas reales de Binance, CoinGecko, Yahoo, Finnhub y los tipos de cambio (el código tolera fallos y usa caché o precio manual).
- La sincronización real con Supabase.
- **La ejecución de `ios.yml`** y el comportamiento dentro de iOS (enlaces, avisos, HTTP nativo).
- Revisar esto en la primera ejecución real.

---

## 19. Cómo trabajar con el código

### 19.1 Flujo
1. Editar en `src/`.
2. `sh build.sh`
3. `node tests/smoke.mjs`
4. Abrir `dist/index.html` en el navegador para verlo.
5. `git commit && git push`: Pages se publica solo.
6. `gh workflow run ios.yml -f destino=testflight` para una nueva versión de la app. Para cambiar la versión visible, editar `MARKETING_VERSION` en `ios.yml`.

### 19.2 Recetas
- **Nueva pantalla:**
  1. Añadir `TITLES['more/x'] = 'Título'`.
  2. Crear `VIEWS['more/x'] = P => html` y, si tiene inputs, `AFTER['more/x'] = () => { …listeners… }`.
  3. Enlazarla desde *Más* con `linkRow('more/x', 'icono', 'Título', 'subtítulo')`.
  4. La prueba de humo la recorrerá sola.
- **Nueva sección del Resumen:** añadir la clave a `HOME_SECTIONS` (en `core.js`) y `HOME.clave = P => html` (o `''` para ocultarla si no hay datos).
- **Nueva acción de botón:** usar `data-action="mi-accion"` (y `data-id=…`) en el HTML y `ACT['mi-accion'] = el => {…}`. Para pedir confirmación, añadir `data-confirm="¿Seguro? Toca otra vez"`.
- **Nuevo ajuste:** añadirlo con su valor por defecto en `blankState().settings`, pintarlo en su vista y guardarlo con `S.settings.x = …; save();`.
- **Nuevo campo de datos:** añadirlo con su valor por defecto y tenerlo en cuenta en `migrate()` si es una lista.
- **Repintar tras un cambio:** `save(); render();`. Para una hoja que debe refrescarse con los precios, pasar `live: () => …` a `openSheet`.
- **Nuevo icono:** añadir el trazo SVG de 24×24 en `ICONS` (`views.js`) y usarlo con `svg('clave')`.

### 19.3 Acciones disponibles (`data-action`)
```
acc-adjust acc-del acc-edit acc-move acc-new acc-open acc-transfer acc-txs accent add-tx asset-del asset-edit
asset-new asset-open back calday cat-del cat-edit cat-move cat-new cat-new-inline cat-open cat-txs catkind
close-sheet copy-json copy-sql cv-swap export-csv export-json fav-add fav-del fx-refresh goal-del goal-edit
goal-new goal-open goal-sub group-del group-edit group-move group-new group-open home-move imp-file imp-go
imp-reset import-json invf load-demo lock-now notif-test op-del op-edit op-new period pin-off pin-set
price-status privacy proxy-test rec-del rec-edit rec-new reconnect sc-copy sc-mode sc-test start-fresh
statsmode stm sync-in sync-now sync-out sync-up tag-txs textsize theme toggle-theme tpl-del tpl-edit tpl-move
tpl-new tpl-use tx-del tx-dup tx-edit tx-more txm txm-all txview watch-new wipe
```
Navegación: `data-go="ruta"` y `data-tab="home|txs|inv|stats|more"`.

### 19.4 Rutas (`TITLES`)
`home txs inv stats more more/accounts more/goals more/groups more/home more/categories more/budgets more/recurring more/fx more/import more/bank more/backup more/prices more/settings more/install more/look more/shortcuts more/security more/templates more/sync`

---

## 20. Limitaciones conocidas y pendientes

- **Datos por dispositivo.** Sin sincronización, la web (cada navegador) y la app tienen datos separados. Se pasan con Copia de seguridad o activando Supabase.
- **Yahoo Finance** es una API no oficial y puede cambiar. En la web requiere el proxy. Las cotizaciones de algunas bolsas llegan con 15 minutos de retraso.
- **CoinGecko** sin clave tiene límites de peticiones (se consulta como mucho una vez por minuto).
- **Avisos:** solo en la app. iOS permite 64 notificaciones pendientes (se programan hasta 60, a 60 días vista).
- **Rentabilidad en otra moneda:** el coste de compras en otra moneda se convierte al cambio actual, no al de la fecha de compra.
- **TestFlight:** cada compilación dura 90 días.
- **Fuentes:** sin conexión se usan las del sistema.
- **Pendiente (ideas):**
  - Conexión bancaria con Enable Banking (Edge Function).
  - Widgets nativos de iOS e intents de Siri sin abrir la app (Swift o App Intents).
  - Face ID (plugin de biometría).
  - Adjuntar fotos de tickets.
  - Deudas entre personas (tipo Splitwise).
  - Alertas de precio en segundo plano.
  - Presupuestos semanales.
  - Comparativa con índices.

---

## 21. Checklist final de despliegue

- [ ] `sh build.sh` sin errores y `node tests/smoke.mjs` en verde.
- [ ] Repo creado en GitHub con la rama `main` (público o privado con Pro, según §16.2).
- [ ] Pages activado con *GitHub Actions* y el workflow «Web en GitHub Pages» en verde; la URL abre la app con los datos de ejemplo.
- [ ] En el iPhone, desde Safari: Compartir → Añadir a pantalla de inicio (opcional, mientras llega la app).
- [ ] App ID `es.david.mision` registrado y la app creada en App Store Connect.
- [ ] Clave de API con rol Admin y los secrets `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID` y `ASC_KEY_P8` configurados.
- [ ] `gh workflow run ios.yml -f destino=testflight` en verde; compilación visible en App Store Connect → TestFlight.
- [ ] Usuario añadido como probador interno; app instalada desde TestFlight.
- [ ] En la app: *Más → Atajos de iPhone* → asignar los nombres de las tarjetas y crear la automatización de Apple Pay.
- [ ] En la app: pulsar «Empezar de cero» y crear las cuentas reales.
- [ ] (Más adelante) Supabase: tabla (§12), iniciar sesión en la web y en la app; y el proxy de Yahoo (§13) si se quieren acciones en la web.
