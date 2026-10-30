# Vitalidad: cómo instalarla

## 1. Descargar el .ipa
1. En el iPhone, abre en Safari: https://github.com/queren05/mision-finanzas/releases/tag/vitalidad-latest
2. Toca **Vitalidad.ipa** (sin firmar).
   - Si ya configuraste la firma automática (apartado 4), toca **Vitalidad-firmada.ipa**.
3. Cuando acabe la descarga, toca el archivo y luego Compartir → **KSign**.

## 2. Instalar con KSign
1. En KSign, abre la pestaña de apps y toca **Vitalidad**.
2. Toca **Firmar**.
3. Como certificado, elige **el tuyo**: el de tu cuenta de desarrollador, con el perfil de Vitalidad (apartado 3).
4. Toca **Instalar**.

> **Importante:** Salud solo deja leer datos a apps firmadas con un perfil que incluya **HealthKit**. Con un certificado de terceros o de empresa, la app se instala pero no puede leer nada. Al tocar «Conectar con Salud» saldrá el aviso «No se pudo conectar con Salud».

## 3. Crear tu certificado y tu perfil con HealthKit (una sola vez, sin Mac)
Todo se hace en https://developer.apple.com/account, en el apartado **Certificates, Identifiers & Profiles**.

### a) El certificado
Apple pide un archivo de solicitud (CSR). Sin Mac se hace con OpenSSL; Claude puede generártelo en el servidor.
```sh
openssl genrsa -out vitalidad.key 2048
openssl req -new -key vitalidad.key -out vitalidad.csr -subj "/CN=David/C=ES"
```
1. En **Certificates**, toca **+**, elige **Apple Development** y sube `vitalidad.csr`.
2. Descarga el archivo `.cer` que te da Apple.
3. Conviértelo en `.p12`, que es lo que entienden KSign y GitHub. Al crearlo te pedirá una contraseña: apúntala.
   ```sh
   openssl x509 -inform DER -in development.cer -out cert.pem
   openssl pkcs12 -export -legacy -inkey vitalidad.key -in cert.pem -out vitalidad.p12
   ```

### b) El identificador de la app (App ID) con HealthKit
1. En **Identifiers**, toca **+**, elige **App IDs** y luego **App**.
2. En **Bundle ID**, marca **Explicit** y escribe `com.david.salud`.
   - Si Apple dice que ya está cogido, usa otro, por ejemplo `com.tunombre.vitalidad`.
   - La firma automática cambia el identificador de la app sola. En KSign, cámbialo a mano antes de firmar.
3. En **Capabilities**, marca **HealthKit**. Si te deja configurarlo, activa también **Background Delivery**, para que se actualice con la app cerrada.
4. Guarda.

### c) Tu iPhone
1. En **Devices**, toca **+** y añade tu iPhone con su **UDID**.
2. Para ver el UDID sin Mac, abre https://udid.tech en Safari.
3. Si ya registraste el iPhone para otras apps, sáltate este paso.

### d) El perfil
1. En **Profiles**, toca **+** y elige **iOS App Development**.
2. Elige el App ID `com.david.salud`, tu certificado y tu iPhone.
3. Ponle de nombre «Vitalidad» y descarga el `.mobileprovision`.

### e) Meterlo en KSign
1. En KSign, ve a Certificados e importa `vitalidad.p12`, con su contraseña, junto con `Vitalidad.mobileprovision`.
2. Firma Vitalidad con ese certificado.

## 4. (Opcional) Que GitHub la firme sola
1. En el repositorio, ve a **Settings → Secrets and variables → Actions → New repository secret** y crea tres secretos:

   | Secreto | Contenido |
   |---|---|
   | `VITALIDAD_P12` | El `.p12` en base64: `base64 -w0 vitalidad.p12` |
   | `VITALIDAD_P12_PASSWORD` | La contraseña del `.p12` |
   | `VITALIDAD_PROFILE` | El perfil en base64: `base64 -w0 Vitalidad.mobileprovision` |

2. A partir de ahí, cada compilación publica también **Vitalidad-firmada.ipa**, ya firmada con HealthKit.
3. En el registro de GitHub Actions, el paso «Firmar» enseña los permisos del perfil y avisa si falta HealthKit.

## 5. Comprobar que funciona
1. Abre Vitalidad, toca **Conectar con Salud** y activa todos los datos.
2. Si más adelante quieres cambiar los permisos, ve a la app Salud → tu foto → Apps → Vitalidad.
