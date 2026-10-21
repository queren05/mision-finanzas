# Caudal · Inventario para el port a Android

Fase 1: análisis de la app de iPhone (`native/`, SwiftUI, unas 5.900 líneas). Aquí todavía no hay código Android.
Fecha: 22 de octubre de 2026.

---

## 0. Lo esencial en 10 líneas

- **Sin backend.** Todo vive en un único JSON local (`Documents/caudal.json`) con el `AppState` entero. Se guarda 0,4 s después de cada cambio.
- **Sin iCloud ni cuentas de usuario.** Solo hay dos cosas en red:
  - las cotizaciones de **Yahoo Finance**, usando su API pública no oficial;
  - el **servidor de casa** (por Tailscale), que sirve solo para los widgets.
- **5 pestañas:** Inicio · Movimientos · Cuentas (deudas con amigos) · Inversiones · Más.
- **Módulos:** cuentas, movimientos, categorías con presupuesto, recurrentes, objetivos, inversiones, «Cuentas claras» (deudas), horas trabajadas (ETT), análisis, inicio configurable, widgets, gastos automáticos (Apple Pay vía Atajos), Face ID y copias de seguridad.
- **Compatibilidad entre las dos apps:** al no haber backend, se consigue con **el mismo formato de copia de seguridad JSON**. Android exporta e importa exactamente el `AppState` de iOS (mismas claves y mismos ids).

---

## 1. Modelos de datos

Todas las fechas son texto: `yyyy-MM-dd`. Las horas también son texto (`HH:mm`), salvo en turnos y deudas, que se indica. Los colores son `#rrggbb` y los iconos son emojis.

| Modelo (Swift) | Campos | Room (Android) |
|---|---|---|
| `Account` | id, name, type (`corriente/ahorro/efectivo/tarjeta/exchange/broker/activo/deuda/otro`), currency, initial, color, icon, includeInTotal, archived, order, note | `AccountEntity` |
| `Category` | id, kind (`expense/income`), name, icon, color, budget, keywords (separadas por comas), hidden. **El orden en la lista es el orden visual** | `CategoryEntity` + columna `position` (+ `parentId` nuevo, ver §8) |
| `Tx` (movimiento) | id, type (`expense/income/transfer/adjust`), amount (siempre positivo salvo los ajustes, que llevan signo), accountId, toAccountId?, categoryId?, date, time, title, note, excluded, recurringId? | `TxEntity` con índices en (date), (accountId), (categoryId) |
| `Recurring` | id, name, type (`expense/income/transfer/invest`), amount, accountId, toAccountId?, categoryId?, assetId?, freq (`weekly/monthly/yearly`), day, next, active | `RecurringEntity` |
| `Asset` | id, kind (`stock/crypto`), symbol, ySymbol (símbolo de Yahoo), name, isin, accountId?, manualPrice, color, archived, ops[] | `AssetEntity` |
| `AssetOp` | id, side (`buy/sell/reward`), qty, price, fee, date, cashAccountId? | `AssetOpEntity` (FK → asset) |
| `Goal` | id, name, icon, color, target, saved, deadline, accountId? (si lo tiene, lo ahorrado es el valor de esa cuenta) | `GoalEntity` |
| `Settings` | name, accent, hideAmountsOnLaunch, faceID, monthStart (1–28) | **DataStore** |
| `Quote` | price, previousClose, currency, updated (clave: ySymbol) | `QuoteEntity` (caché) |
| `Snapshot` | d, v (histórico de patrimonio; existe en el modelo pero **hoy no se usa**) | se mantiene para que la importación no pierda nada |
| `Person` | id, name, emoji, color, nick, phone, photo (Data / base64) | `PersonEntity` (foto en un archivo interno) |
| `DebtMove` | id, personId, amount (>0 te debe, <0 le debes), kind (`owe/debt/split/theypaid/pay/ipay`), concept, date, created (Date), group?, total? | `DebtEntity` |
| `Company` | id, name, color, normalRate, nightRate, nightStart/nightEnd (minutos), ssPct, irpfPct, accountId? | `CompanyEntity` |
| `Shift` (turno) | id, companyId, date, start/end (minutos), breakMin, note, status (`pendiente/pagado`), paidDate, normalRate?, nightRate? | `ShiftEntity` |
| `HomeItem` | id, on (orden y visibilidad de las tarjetas de inicio) | DataStore (lista ordenada) |
| `AppState` | version, seed, todas las listas anteriores, quotes, snapshots, home, accountsStyle | – (solo existe como formato de copia) |

**Lectura tolerante.** Si a un JSON antiguo le faltan campos, iOS usa los valores por defecto. En Android: `kotlinx.serialization` con `ignoreUnknownKeys` y `coerceInputValues`, y valores por defecto en todas las clases.

---

## 2. Lógica de negocio y cálculos (deben dar exactamente lo mismo)

Con tests unitarios en `domain/`. Todos son funciones puras: entran listas y sale un resultado.

1. **Efecto de un movimiento sobre una cuenta.**
   - Gasto: −importe en su cuenta.
   - Ingreso y ajuste: +importe (el ajuste ya lleva su signo).
   - Transferencia: −importe en el origen y +importe en el destino.
2. **Saldo de una cuenta** (opcionalmente hasta una fecha). Es `initial` + los efectos de los movimientos + las operaciones de inversión pagadas desde esa cuenta:
   - compra: −(qty × price + fee);
   - venta: +(qty × price − fee);
   - recompensa: 0.
3. **Valor de una cuenta:** su saldo + el valor de las inversiones asignadas a ella que no estén archivadas.
4. **Patrimonio:** la suma del valor de las cuentas activas que tienen `includeInTotal`. **Efectivo:** lo mismo, pero solo con los saldos.
5. **Serie de patrimonio de 30 días:** el efectivo de cada día + las inversiones **al valor de hoy**.
6. **Posición de una inversión (coste medio).** Se recorren las operaciones por fecha:
   - compra: suma cantidad y coste (incluida la comisión);
   - recompensa: suma cantidad sin coste;
   - venta: realizado += q × (precio − medio) − comisión, y se resta q × medio del coste.

   El precio es la cotización de Yahoo o, si no hay, `manualPrice`. El cambio del día es precio ÷ cierre anterior − 1. La «rentabilidad de hoy» de la cartera es Σ qty × (precio − cierre anterior).
7. **Mes financiero.** `monthStart` va de 1 a 28. El periodo que contiene la fecha D:
   - si el día de D es menor que monthStart, empieza en el mes anterior;
   - el rango va del inicio a inicio + 1 mes − 1 día.
8. **Gastado e ingresado del periodo:** solo gastos o ingresos con `excluded == false`. Por categoría, ordenado de mayor a menor; lo que no tiene categoría va a «Sin categoría».
9. **Comparación con el mes pasado.** Se compara con el mismo número de días transcurridos del periodo anterior. Solo se muestra si el mes pasado completo llegó a 100 € o más.
10. **Presupuesto total:** la suma de los presupuestos de las categorías de gasto. Las barras se ponen naranjas a partir del 80 % y rojas por encima del 100 %.
11. **Recurrentes.**
    - Al abrir la app y al volver a ella se apuntan todos los cargos con `next <= hoy` (máximo 60 seguidos), con hora 08:00 y el `recurringId`.
    - Si el tipo es `invest`, se compra importe ÷ precio participaciones del activo.
    - Siguiente fecha: semanal +7 días; anual +12 meses; mensual = mes siguiente con el día `day`, recortado al último día de ese mes.
    - «Próximos cargos»: los de los próximos 14 días, como mucho 10 por recurrente.
12. **Adivinar la categoría.** El concepto se pasa a minúsculas y sin tildes. Si tiene 3 letras o más, gana la primera categoría visible, en el orden de la lista, que tenga una palabra clave (de 2 letras o más) contenida en el concepto.
13. **Ajuste de saldo:** apunta un movimiento `adjust` por la diferencia (redondeada a céntimos) si es de al menos 0,005.
14. **Importes.**
    - Al teclear: solo números y una coma, con 2 decimales como máximo y 9 dígitos enteros como máximo.
    - Al leer texto (`AutoInbox.parse`): «12,50 €», «€12.50» y «1.234,56» se convierten en número. El último separador seguido de 2 dígitos o menos se toma como decimal.
15. **Horas trabajadas.**
    - Si el turno cruza la medianoche, la salida se toma como del día siguiente.
    - Las horas nocturnas son las que caen en el tramo de la empresa (por defecto de 22:00 a 06:00), mirando el día anterior, el del turno y el siguiente.
    - El descanso se descuenta primero de las horas normales y luego de las nocturnas.
    - Bruto = horas normales × precio normal + horas nocturnas × precio nocturno. Se usa el precio del turno si tiene uno propio, y se redondea a céntimos.
    - Neto = bruto × (1 − (SS % + IRPF %) ÷ 100).
    - «Cobrar el mes» marca como pagados los turnos pendientes y puede apuntar el ingreso «Nómina <empresa>» en la categoría `i_nomina`.
16. **Cuentas claras.**
    - Saldo con una persona: la suma de sus movimientos, redondeada.
    - «A medias»: el importe entre N personas (contándote a ti o no), con un movimiento por persona y el mismo `group`.
    - «Pagó otro»: −importe ÷ N.
    - «Saldar»: apunta `pay` o `ipay` por el total o por una parte.
    - Orden de la lista: primero quien tiene saldo pendiente, por importe; después el resto por nombre.
    - Mensaje de recordatorio con el detalle de las últimas 8 deudas, por WhatsApp (`wa.me`, añadiendo +34 si el número tiene 9 dígitos) o copiado.
17. **Estadísticas** (pestaña de análisis):
    - gastado, ingresado, % de ahorro = (ingresos − gastos) ÷ ingresos;
    - media diaria = gastado ÷ días transcurridos;
    - gráfico de donut por categoría, barras de los últimos meses, presupuestos y los 6 conceptos donde más se gasta.

---

## 3. Pantallas y flujos → equivalente en Android

Navegación: **Navigation Compose** con una barra inferior de 5 destinos y un **botón flotante (+)** en Inicio y Movimientos.

| iOS | Qué hace | Android (Compose + M3) |
|---|---|---|
| **RootView** (TabView + FAB + aviso «Deshacer») | Pestañas; botón + para apuntar; deshacer el último borrado durante 5 s | `Scaffold` + `NavigationBar` + `FloatingActionButton` + `Snackbar` con acción «Deshacer» |
| **HomeView** | Saludo, ojo para ocultar importes y tarjetas configurables: patrimonio con gráfico de 30 días (se puede tocar para ver cada día), cuentas (5 estilos: cuadrícula, carrusel, lista, pequeño, grande), horas, resumen del mes, en qué gastas (donut), próximos cargos, últimos movimientos, inversiones y cuentas claras | `HomeScreen` con `LazyColumn` de tarjetas según la configuración. Gráfico con **Vico** (gráficos Compose, mantenida). Carrusel con `HorizontalPager` |
| **HomeCustomizer** | Ordenar, quitar o añadir tarjetas; estilo y orden de las cuentas | Hoja inferior con lista reordenable (arrastrar en `LazyColumn`, o la librería `reorderable` si hace falta) |
| **TransactionsView** | Meses en chips, resumen de gastos e ingresos, lista agrupada por día con total, búsqueda (concepto, nota, categoría, importe), filtros por tipo y cuenta, deslizar para editar, duplicar o eliminar (con confirmación) | `TransactionsScreen` con **Paging 3** desde Room, `SearchBar`, `FilterChip` y `SwipeToDismissBox` + diálogo de confirmación |
| **TxEditor** | Tipo (gasto, ingreso o transferencia; ajuste solo al editar), importe grande con teclado numérico, cuadrícula de categorías, cuenta (o desde/hacia), concepto con sugerencias de conceptos anteriores y categoría automática, nota, fecha y hora, «excluir de estadísticas», eliminar | Pantalla completa o hoja con `TextField` numérico oculto (`KeyboardType.Decimal`), `FlowRow` de categorías, `DatePicker`/`TimePicker` M3 y sugerencias en chips |
| **StatsView** | Mes anterior y siguiente, indicadores, donut por categoría (gastos o ingresos), barras por meses, presupuestos y top de conceptos | `StatsScreen` con Vico |
| **DebtsView / PersonDetail / DebtEditor / PersonEditor** | Lo que te deben y lo que debes, personas, últimos movimientos, apuntar (me debe, le debo, a medias, pagó otro), saldar total o parcial, recordar por WhatsApp, importar desde la web de Cuentas Claras, foto o emoji de la persona | Pantallas equivalentes; foto con el **Photo Picker** del sistema; WhatsApp con un `Intent` a `https://wa.me/…`; copiar con `ClipboardManager` |
| **InvestView / AssetDetail / AssetEditor / OpEditor** | Cartera (valor, rentabilidad, hoy, invertido), reparto, cada activo con gráfico 1S/1M/3M/1A/5A, compra/venta/recompensa desde una cuenta, «Comprobar precio» | Pantallas equivalentes; precios con **Ktor client** o OkHttp + `kotlinx.serialization`; actualización periódica con WorkManager |
| **WorkView / ShiftEditor / CompanyEditor / PayMonthSheet** | Horas del mes por empresa, normales y nocturnas, bruto y neto, pagado o pendiente, apuntar varios días a la vez, precio propio de cada turno, cobrar el mes | Pantallas equivalentes; varios días con un calendario de selección múltiple propio (M3 no tiene uno de selección múltiple) |
| **MoreView** | Gestión (horas, cuentas, categorías con presupuesto, recurrentes, objetivos), iPhone (widgets, gastos automáticos), ajustes (nombre, Face ID, abrir ocultando importes, día de inicio del mes, color), datos (exportar, importar también desde la web, volver a los datos de partida, borrar todo, todo con confirmación) | `MoreScreen` + `SettingsScreen` |
| **AccountsList / AccountDetail / AccountEditor** | Cuentas activas y archivadas, detalle con movimientos, ajustar saldo, eliminar (borra sus movimientos, con confirmación) | Equivalentes |
| **CategoriesList / CategoryEditor / EmojiSheet** | Gastos o ingresos, ordenar arrastrando, emoji, color, presupuesto, palabras clave, ocultar | Equivalentes; selector de emojis propio (cuadrícula) o `androidx.emoji2.emojipicker` (de Google, mantenido) |
| **RecurringList / RecurringEditor** | Activar o pausar, tipo (también «invertir»), frecuencia, próximo cargo | Equivalentes |
| **GoalsList / GoalEditor** | Objetivos con meta, fecha y origen (manual o una cuenta) | Equivalentes |
| **LockView** | Pantalla de bloqueo con Face ID o código del iPhone | **BiometricPrompt** con `BIOMETRIC_STRONG or DEVICE_CREDENTIAL` |

**Detalles de comportamiento que hay que mantener:**
- Todo lo que borra pide confirmación.
- Respuesta háptica en las acciones (`HapticFeedback` / `View.performHapticFeedback`).
- Importes ocultos con «•••• €».
- Sin barra de scroll visible y sin textos de ayuda tipo pie de página (es preferencia tuya).

---

## 4. Persistencia, red y tareas

| iOS | Android |
|---|---|
| JSON único en Documentos, guardado con retardo de 0,4 s | **Room** (una tabla por modelo) + **DataStore** (ajustes, inicio, estilo de las cuentas). Flows reactivos |
| Exportar copia (`caudal.json` con ShareLink) | Exportar el **mismo JSON** de `AppState` con el selector de archivos del sistema o compartir. Además la copia cifrada nueva (§8) |
| Importar: copia nativa, copia de la versión web (Misión Finanzas / Caudal 2.x) y JSON de Cuentas Claras | Los tres importadores portados tal cual, con tests usando archivos reales |
| `Seed.migrate` (versiones de semilla 4 a 7) | Migraciones de Room desde la versión 1 de Android. Las semillas de iOS no hacen falta (ver pregunta 1) |
| Yahoo Finance: `query1.finance.yahoo.com/v8/finance/chart/{símbolo}` | Igual, con Ktor/OkHttp. Actualización al abrir y con **WorkManager** periódico (cada 30–60 min, solo con red) |
| Recurrentes al abrir y al volver a la app | Igual, y además un **WorkManager** diario para que se apunten aunque no abras la app |

---

## 5. Notificaciones, widgets e integración con el sistema

| iOS | Android |
|---|---|
| **Widgets WidgetKit** (cuentas, gastos del mes también en la pantalla de bloqueo, inversiones, grande) que reciben los datos **por tu servidor de casa** porque KSign no deja compartir datos entre app y widget | **Glance**: el widget lee **directamente de Room**, sin servidor ni red. Widgets: gasto del mes, presupuesto restante, añadir gasto rápido, más saldo y cuentas e inversiones para mantener la paridad. Se refrescan al guardar (`GlanceAppWidget.updateAll`) |
| `AddExpenseIntent` + automatización de Atajos «Transacción» (Apple Pay) → buzón `inbox.json` | Lo sustituye la **Fase 3** (`NotificationListenerService`). Además: **accesos directos** de la app (`ShortcutManager`), **mosaico de ajustes rápidos** (`TileService`) y un `Intent` para apuntar un gasto desde fuera |
| `AppShortcutsProvider` (Siri) | Accesos directos estáticos o dinámicos. «Ok Google» es opcional y no hace falta |
| Notificaciones: **no tiene** (Caudal iOS no avisa de nada) | Nuevas, de la Fase 4: presupuesto al 80 % y al 100 %, cargo recurrente próximo y gasto apuntado solo. Canales de notificación y permiso `POST_NOTIFICATIONS` (Android 13+) |
| Face ID (`LAContext`) | BiometricPrompt, con PIN propio como alternativa (Fase 4.11) |
| Teclado numérico del iPhone para importes | `KeyboardOptions(keyboardType = Decimal)` sin tocar el diseño |
| Swift Charts | Vico |
| Fotos de personas (`Data` en el JSON) | Archivo en `filesDir`. Se convierte a base64 solo al exportar, para que la copia siga siendo compatible |

---

## 6. Lo que no tiene traducción directa

| iOS | Problema | Propuesta |
|---|---|---|
| **Widgets por el servidor de casa** | En Android no hace falta: el widget comparte proceso y base de datos con la app | Glance leyendo Room. **El servidor no se usa en Android** (en iOS se queda como está) |
| **Apple Pay + Atajos** | No existe en Android | Lector de notificaciones del banco (Fase 3), que es mejor: vale para cualquier banco, no solo para Apple Pay |
| **Face ID** | – | BiometricPrompt (huella o cara) + PIN |
| **Siri / App Intents** | – | Accesos directos, mosaico de ajustes rápidos y widget «añadir gasto» |
| **Formato de fechas fijo es_ES y euros fijos** | La Fase 4 pide poder configurarlos | El formato interno se queda como en iOS (`yyyy-MM-dd`, `Double`). Solo cambia **cómo se muestra**. Ver la pregunta 4 sobre las monedas |
| **Haptics de iOS** | – | `HapticFeedbackType` de Compose |
| **Datos de partida «David»** | Son tus cuentas y movimientos reales de octubre de 2026, metidos en el código | **No pueden ir en una app pública de Play.** Ver la pregunta 1 |

---

## 7. Dependencias externas

| iOS | Uso | Android |
|---|---|---|
| Ninguna librería de terceros | – | Solo AndroidX, Google y JetBrains: Compose BOM, Material 3, Navigation, Hilt, Room, DataStore, WorkManager, Glance, Biometric, Paging, kotlinx.serialization y coroutines, Vico, Ktor u OkHttp (uno de los dos), y Apache POI-lite o FastExcel para el Excel (ver §8.12) |
| Yahoo Finance (API no oficial) | Precios | Igual (ver la pregunta 3) |
| Tailscale y servidor de casa | Widgets de iOS | No hace falta |
| WhatsApp (`whatsapp://send`) | Recordar deudas | `https://wa.me/<tel>?text=…` |

---

## 8. Funciones nuevas y su encaje con el modelo de iOS

Para que una copia de Android se pueda abrir en iOS y al revés:
- todo lo nuevo se guarda en **campos nuevos y opcionales** del mismo JSON;
- iOS los ignora sin romperse, porque ya lee de forma tolerante. Eso sí, si guardas desde iOS, se pierden.

Si quieres paridad en las dos direcciones, habría que añadirlos también a iOS. Ver la pregunta 6.

| Nº | Función | Dónde se guarda |
|---|---|---|
| 3 | Gastos automáticos por notificaciones | Nueva tabla `bank_notifications` (huella para detectar duplicados) + `templates` (plantillas que le enseñas) |
| 4.1–4.2 | Reglas por comercio y aprendizaje de correcciones | Nueva lista `rules` (patrón, categoría, prioridad, origen manual o aprendido). Son una capa encima de las `keywords` de iOS, que se siguen usando |
| 4.3 | Subcategorías | `Category.parentId` (opcional) |
| 4.4 | Presupuesto por periodo | `Category.budgetPeriod` (por defecto mensual = como en iOS) + avisos |
| 4.6 | Detección de suscripciones | Se sugieren `Recurring` a partir del historial (mismo comercio y mismo importe, más o menos, con cadencia semanal, mensual o anual) |
| 4.7 | Etiquetas | `Tx.tags: [String]`. Ojo: la importación de la versión web ya convertía etiquetas en `#etiqueta` dentro de la nota; al importar se recuperan como etiquetas |
| 4.10 | Temas claro, oscuro y AMOLED + Dynamic Color | DataStore (iOS solo tiene modo oscuro y color de acento) |
| 4.11 | PIN | Hash con sal en DataStore, nunca el PIN en claro |
| 4.12 | CSV, Excel y copia cifrada | CSV con SAF; Excel `.xlsx` con una librería ligera; copia cifrada con AES-GCM y clave derivada de una contraseña (PBKDF2 o Argon2) |
| 4.13 | Moneda, formato de fecha, primer día | `monthStart` ya existe; se añaden la moneda que se muestra y el formato de fecha |

---

## 9. Requisitos técnicos ya comprobados

- **targetSdk.** Desde el 31 de agosto de 2026, las apps nuevas y las actualizaciones tienen que apuntar a **Android 16 (API 36)** o superior. Usaré `compileSdk = 36` y `targetSdk = 36`; si al compilar ya hay herramientas estables para API 37, subo las dos a 37. `minSdk = 26`.
- **Permiso de notificaciones de bancos.** `BIND_NOTIFICATION_LISTENER_SERVICE` exige que la persona lo active a mano en los ajustes del sistema. En Play hay que explicarlo en el formulario de permisos y mostrar un aviso claro antes de pedirlo. Todo el procesamiento se hace en el móvil.
- **Compilación.** Este servidor no tiene Java ni el SDK de Android. Tengo dos opciones:
  - compilar con **GitHub Actions**, como las apps de iPhone;
  - instalar aquí JDK 17 + el SDK de línea de comandos.

---

## 10. Preguntas antes de la Fase 2

Me pediste que preguntara antes de inventar. Estas son las dudas:

1. **Datos de partida.** La app de iPhone arranca con tus cuentas y movimientos reales.
   - Para Play propongo empezar **vacía**, con una bienvenida: nombre, primera cuenta y categorías por defecto.
   - Tus datos los pasarías **importando la copia de iPhone**.
   - ¿Vale?
   - Aparte, aviso de que el repositorio `mision-finanzas` es **público** y `Seed.swift` contiene tus movimientos reales. Quizá te convenga hacerlo privado.
2. **Horas trabajadas (ETT) y Cuentas claras.** ¿Van en la versión de Play para todo el mundo, o las dejamos como módulos que se activan en Ajustes? Yo las pondría desactivadas por defecto.
3. **Yahoo Finance.** Es una API no oficial y sus condiciones no permiten usarla en apps comerciales. Para uso personal funciona, pero en Play es un riesgo. Opciones:
   - **(a)** mantenerla, avisando de que son «precios orientativos»;
   - **(b)** un proveedor con licencia, que suele necesitar clave y tener coste;
   - **(c)** solo precio manual.
4. **Moneda.** ¿Basta con elegir **una** moneda para mostrar? ¿O quieres de verdad **varias monedas** por cuenta, con conversión? Lo segundo es bastante más trabajo y en iOS no existe.
5. **Nombre en Play.** ¿«Caudal» a secas, o «Caudal: gastos y presupuesto» para el ASO? Otra cosa: ¿la app será gratis, de pago o con compras dentro? Afecta al formulario de seguridad de datos y a la ficha.
6. **Compatibilidad en las dos direcciones.** ¿Quieres que después añada a la app de iPhone los campos nuevos (etiquetas, subcategorías, reglas…)? Así una copia viaja entre las dos apps sin perder nada.
7. **Dónde va el código.** Propongo la carpeta `android/` del mismo repositorio (rama `caudal`), compilada con GitHub Actions. Te dejaría un APK de prueba y el AAB sin firmar; la firma para Play la haces tú con tu clave. ¿O prefieres un repositorio aparte y privado?

---

Fuentes de los requisitos de Play: [Requisito de API de destino (developer.android.com)](https://developer.android.com/google/play/requirements/target-sdk) · [Ayuda de Play Console](https://support.google.com/googleplay/android-developer/answer/11926878)
