# Formato de la copia de seguridad de Caudal

Caudal para iPhone y para Android guardan la misma copia: un único archivo JSON (`caudal-AAAA-MM-DD.json`).
Así puedes pasar tus datos de una app a otra.

- **Versión actual del formato:** `formatVersion: 1`
- **Código que lo lee y lo escribe:**
  - Android: `app/src/main/java/es/david/caudal/data/backup/BackupCodec.kt`
  - iPhone: `native/Caudal/Model/Models.swift` (`AppState`)

## Reglas

1. **Campos desconocidos.** Cada app ignora los campos que no conoce, sin dar error.
2. **No se pierde nada al pasar por Android.** Android guarda los campos desconocidos tal cual (en la columna `extra` de cada tabla y, para el nivel superior y los ajustes, en DataStore) y los vuelve a escribir al exportar. Una copia que pasa por Android conserva así todo lo que traía.
3. **iPhone no conserva los campos desconocidos.** Los lee sin romperse, pero no los guarda: si exportas desde iPhone, se pierden los campos que solo existen en Android. Para evitarlo habría que añadir a iPhone la misma columna `extra`; está pendiente porque, por ahora, la app de iPhone no se toca.
4. **iPhone exige todas sus claves.** Las apps de iPhone usan `Codable` sintetizado, que obliga a que estén todas las claves no opcionales. Por eso Android escribe siempre todas las claves de la tabla de abajo, aunque tengan su valor por defecto.
5. **Los campos nuevos son opcionales.** Todo campo nuevo tiene que ser opcional y tener un valor por defecto. Nunca se cambia el significado de un campo que ya existe; si hace falta, se crea uno nuevo.
6. **Cuándo se sube `formatVersion`.** Solo cuando un cambio no se puede leer con las reglas anteriores. Una app que lee una versión mayor que la suya intenta leerla igualmente con estas reglas.

## Nivel superior

| Clave | Tipo | Notas |
|---|---|---|
| `format` | texto | Siempre `"caudal-backup"` (lo añade Android). |
| `formatVersion` | entero | `1`. Si no está, es una copia de iPhone anterior: se lee como `1`. |
| `app` | texto | Quién la escribió, p. ej. `"android 1.0.0"`. Es informativo. |
| `version` | entero | `3`: la versión del modelo en iPhone. |
| `seed` | entero | Versión de los datos de partida de iPhone (`7`). |
| `accounts`, `categories`, `txs`, `recurring`, `assets`, `goals`, `people`, `debts`, `companies`, `shifts` | listas | Ver abajo. |
| `settings` | objeto | Ver abajo. |
| `quotes` | objeto | Clave = símbolo → `{price, previousClose, currency, updated}`. |
| `snapshots` | lista | `{d, v}`. Ninguna de las dos apps lo usa todavía, pero se conserva. |
| `home` | lista | `{id, on}`: tarjetas de inicio, en orden. |
| `accountsStyle` | texto | `cuadricula`, `carrusel`, `lista`, `pequeno` o `grande`. |

## Tipos

- **Fechas:** texto `yyyy-MM-dd`.
- **Horas:** texto `HH:mm`.
- **Importes:** número decimal en la moneda, p. ej. `12.5`. Android los guarda en céntimos y los convierte al leer y al escribir.
- **Marcas de tiempo** (`created`, `updated`): número de **segundos desde el 1 de enero de 2001** (el formato por defecto de Swift).
- **Colores:** `#rrggbb`.
- **Iconos:** un emoji.

## Listas

Las claves en **negrita** son obligatorias para iPhone. Las que llevan `?` son opcionales y no se escriben si están vacías.

| Lista | Campos |
|---|---|
| `accounts` | **id, name, type, currency, initial, color, icon, includeInTotal, archived, order, note**. `type` es uno de: `corriente`, `ahorro`, `efectivo`, `tarjeta`, `exchange`, `broker`, `activo`, `deuda`, `otro`. |
| `categories` | **id, kind** (`expense` o `income`), **name, icon, color, budget, keywords** (separadas por comas), **hidden**. El orden de la lista es el orden en pantalla. |
| `txs` | **id, type** (`expense`, `income`, `transfer` o `adjust`), **amount** (positivo salvo en `adjust`, que lleva signo), **accountId**, toAccountId?, categoryId?, **date, time, title, note, excluded**, recurringId?. Android añade `currency`, `mood` («¿valió la pena?»: un emoji) y `tags` (lista de etiquetas sin «#»); iPhone los ignora. |
| `recurring` | **id, name, type** (`expense`, `income`, `transfer` o `invest`), **amount, accountId**, toAccountId?, categoryId?, assetId?, **freq** (`weekly`, `monthly` o `yearly`), **day, next, active**. |
| `assets` | **id, kind** (`stock` o `crypto`), **symbol, ySymbol, name, isin**, accountId?, **manualPrice, color, archived, ops**. |
| `assets[].ops` | **id, side** (`buy`, `sell` o `reward`), **qty, price, fee, date**, cashAccountId?. |
| `goals` | **id, name, icon, color, target, saved, deadline** (vacío si no hay), accountId?. |
| `people` | **id, name, emoji, color, nick, phone**, photo? (JPEG en base64). |
| `debts` | **id, personId, amount** (>0: te debe; <0: le debes), **kind** (`owe`, `debt`, `split`, `theypaid`, `pay` o `ipay`), **concept, date, created**, group?, total?. |
| `companies` | **id, name, color, normalRate, nightRate, nightStart, nightEnd** (minutos desde las 00:00), **ssPct, irpfPct**, accountId?. |
| `shifts` | **id, companyId, date, start, end** (minutos), **breakMin, note, status** (`pendiente` o `pagado`), **paidDate**, normalRate?, nightRate?. |

## `settings`

| Clave | Quién la usa | Notas |
|---|---|---|
| **name, accent, hideAmountsOnLaunch, faceID, monthStart** | iPhone y Android | En Android, `faceID` es el bloqueo con huella o código. `monthStart` va de 1 a 28. |
| `currency` | Android | Código ISO de la moneda que se enseña (`EUR`…). |
| `theme`, `dynamicColor` | Android | `system`, `light` o `dark`; colores del fondo de pantalla. |
| `modules` | Android | `{work, debts, invest}`. Si no está (copia de iPhone), se encienden los módulos que tienen datos. |

## Otras copias que Android sabe leer

- **Versión web** (Misión Finanzas / Caudal 2.x). Se reconoce por los campos `excl`, `recId` o `tags` en los movimientos, o porque les falta `time`. Se convierte igual que en iPhone (`WebImport`).
- **Cuentas Claras web** (`{"people": […], "moves": […]}`). Se añade a lo que ya hay; no sustituye nada.

## Multimoneda (preparado, no activo)

Cada movimiento y cada cuenta ya llevan su `currency`. Para activar la multimoneda bastaría con:

- elegir la moneda en cada cuenta;
- convertir los totales a la moneda principal con una tabla de cambios (nueva clave opcional `rates`).

No hace falta tocar los datos que ya existen.

## Copia cifrada

Desde Datos se puede exportar la copia protegida con contraseña. Es un JSON con estas claves:

| Clave | Valor |
|---|---|
| `format` | `"caudal-backup-encrypted"` |
| `formatVersion` | `1` |
| `kdf` | `"PBKDF2WithHmacSHA256"` |
| `iterations` | iteraciones de PBKDF2 (210 000 por defecto) |
| `cipher` | `"AES-256-GCM"` |
| `salt` | 16 bytes aleatorios, en base64 |
| `iv` | 12 bytes aleatorios, en base64 |
| `data` | la copia normal (este mismo formato) cifrada con AES-256-GCM, etiqueta de 128 bits incluida, en base64 |

- **Clave:** PBKDF2-HMAC-SHA256(contraseña, `salt`, `iterations`), 256 bits.
- **Datos adicionales autenticados (AAD):** el texto `caudal-backup-encrypted`.
- **Al importar:** Android la reconoce por `format`, pide la contraseña y, si es correcta, la trata como una copia normal.
- **Si se olvida la contraseña,** no hay forma de abrirla.
- **iPhone** todavía no lee este formato.
