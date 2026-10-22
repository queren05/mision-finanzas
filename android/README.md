# Caudal para Android

Caudal es una app de finanzas personales nativa: Kotlin, Jetpack Compose y Material 3. Es la versión Android de la app de iPhone (`../native`), con los mismos cálculos y la misma copia de seguridad.

## Compilar

**Requisitos:**
- JDK 21.
- SDK de Android con la plataforma 37 (para compilar) y build-tools 36.1. La app apunta (`targetSdk`) a la API 36 y funciona desde la API 26.

```bash
cd android
echo "sdk.dir=$HOME/android-sdk" > local.properties   # ruta a tu SDK
./gradlew :app:testDebugUnitTest        # pruebas
./gradlew :app:assembleDebug            # APK de prueba (es.david.caudal.debug)
./gradlew :app:assembleRelease          # APK de release (R8)
./gradlew :app:bundleRelease            # AAB para Google Play
```

**En GitHub Actions** (`.github/workflows/android.yml`), cada cambio en `android/` hace esto:
- pasa las pruebas;
- compila el APK y el AAB de release, firmado si los secretos están puestos;
- publica el APK de prueba en la release `caudal-android-latest`;
- deja el AAB en los artefactos de la ejecución.

El `versionCode` es el número de ejecución del workflow, así que siempre sube.

## Firmar para Google Play (paso a paso)

Google Play usa **Play App Signing**:
- Google guarda la clave con la que se firma la app que reciben los usuarios.
- Tú solo tienes una **clave de subida** (*upload key*) para firmar los AAB que subes.
- Si pierdes la clave de subida, se puede cambiar desde la Play Console (Configuración → Integridad de la app). Aun así, guárdala bien.

### 1. Crear la clave de subida (una sola vez)

En el servidor, que ya tiene Java:

```bash
keytool -genkeypair -v \
  -keystore ~/caudal-upload.jks \
  -alias caudal \
  -keyalg RSA -keysize 4096 -validity 10000
```

- Te pide una contraseña para el almacén y otra para la clave. Pueden ser la misma; que sea larga.
- Luego pide nombre, organización, ciudad… Basta con tu nombre y `ES` como país.
- **Guarda una copia** de `caudal-upload.jks` y de las contraseñas en un gestor de contraseñas y en un sitio fuera del servidor, por ejemplo un USB.
- **No lo subas nunca a git.** El `.gitignore` ya ignora `*.jks`.

### 2. Pasarla a texto para GitHub

```bash
base64 -w0 ~/caudal-upload.jks > ~/caudal-upload.b64
```

### 3. Crear los secretos en GitHub

En el repositorio: **Settings → Secrets and variables → Actions → New repository secret**. Crea estos cuatro:

| Nombre | Valor |
|---|---|
| `CAUDAL_KEYSTORE_BASE64` | Todo el contenido de `caudal-upload.b64` (`cat ~/caudal-upload.b64`) |
| `CAUDAL_KEYSTORE_PASSWORD` | La contraseña del almacén |
| `CAUDAL_KEY_ALIAS` | `caudal` |
| `CAUDAL_KEY_PASSWORD` | La contraseña de la clave |

Después borra `~/caudal-upload.b64`; el `.jks` guárdalo.

### 4. Compilar y subir

1. **Actions → «Caudal Android (AAB)» → Run workflow.** En el registro debe poner `firmado: sí`.
2. Descarga el artefacto `caudal-android-N` y dentro está `app-release.aab`.
3. En la **Play Console**:
   1. Crea la app.
   2. Ve a **Pruebas → Prueba interna** (o cerrada) y crea una versión nueva.
   3. Sube el `.aab`. La primera vez, acepta **Play App Signing**: viene activado por defecto.

### Firmar en local (opcional)

Crea `android/keystore.properties` (está fuera de git):

```properties
storeFile=/home/david/caudal-upload.jks
storePassword=…
keyAlias=caudal
keyPassword=…
```

## Estructura

```
app/src/main/java/es/david/caudal/
├── core/            Day (fechas yyyy-MM-dd) y Money (céntimos, leer y teclear importes)
├── domain/
│   ├── model/       modelos (los mismos que en iPhone)
│   └── calc/        cálculos puros: Ledger (saldos, periodos, inversiones…), Recurrences, Hours, Debts
├── data/
│   ├── db/          Room: entidades, DAO (con la lista paginada) y base de datos
│   ├── repo/        FinanceRepository (todo lo que cambia datos), SettingsRepository (DataStore), SessionState
│   ├── backup/      copia de seguridad compatible con iPhone, versión web, Cuentas Claras y categorías de partida
│   ├── prices/      PriceProvider: hoy precio a mano; aquí entraría un proveedor con licencia
│   └── billing/     Entitlements: hoy todo gratis; aquí entraría Google Play Billing
├── di/              módulos de Hilt
├── work/            RecurringWorker (recurrentes cada día con WorkManager)
├── widget/          widgets de Glance (patrimonio, gastos del mes, inversiones)
└── ui/              Compose + MVVM: theme, common (componentes y ViewModel común), charts (gráficos propios),
                     nav (rutas con tipos), home, txs, stats, debts, invest, work, more, onboarding, lock
```

**Textos:** todos están en `res/values/strings*.xml`, con un archivo por módulo. El idioma de las fechas y los importes sale de `locale_tag` en `strings.xml`.

**Copia de seguridad:** ver [BACKUP_FORMAT.md](BACKUP_FORMAT.md).

## Quitar los datos personales del historial de git

Tus datos reales ya no están en el código: `native/Caudal/Resources/seed-personal.json` está fuera de git y GitHub Actions lo pone desde el secreto `CAUDAL_SEED_JSON`. Pero siguen en los commits antiguos de `native/Caudal/Model/Seed.swift`.

Para borrarlos del todo hay que reescribir el historial. **Antes de nada, ten en cuenta que:**
- reescribe **todas** las ramas del repositorio, incluidas las de los juegos, porque es el mismo repositorio;
- cambian los identificadores de todos los commits;
- cualquier otra copia que tengas clonada habrá que volver a clonarla.

**Pasos** (en el servidor, con todo subido y sin cambios a medias):

```bash
# 1) copia de seguridad completa por si algo sale mal
git clone --mirror https://github.com/queren05/mision-finanzas.git ~/mision-finanzas-backup.git

# 2) herramienta oficial recomendada por GitHub
sudo apt install git-filter-repo

# 3) trabajar sobre un clon limpio
git clone --mirror https://github.com/queren05/mision-finanzas.git ~/limpieza.git && cd ~/limpieza.git

# 4) dejar Seed.swift en TODOS los commits como está ahora (sin datos personales)
git show caudal:native/Caudal/Model/Seed.swift > /tmp/Seed-limpio.swift
git filter-repo --force --blob-callback '
import re
if b"Miamor" in blob.data or b"a_revolut\", name: \"Revolut\"" in blob.data:
    blob.data = open("/tmp/Seed-limpio.swift","rb").read()
'

# 5) comprobar que ya no aparece
git log --all -S "Miamor" --oneline        # no debe salir nada

# 6) subir el historial nuevo (sobrescribe GitHub)
git push --force --mirror origin
```

**Después:**
- En GitHub, **Settings → General → Danger Zone**, deja el repositorio en **privado**. Ahora mismo GitHub lo sigue marcando como público.
- Los commits antiguos pueden seguir viéndose un tiempo por su identificador. Si quieres borrarlos ya, pide a GitHub Support que purgue la caché («remove cached views»).
- En el servidor, borra las copias de trabajo y vuelve a clonar: `/home/david/caudal` y `/home/david/juegos-gambas` comparten este repositorio.
