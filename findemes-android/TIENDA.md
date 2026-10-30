# Fin de Mes: anuncios y compras

## Qué hay en el juego

**Anuncios con premio.** Solo salen si el jugador pulsa el botón; nunca hay anuncios obligatorios.

| Premio | Dónde | Veces al día |
|---|---|---|
| Cobrar el doble de lo ganado mientras no jugabas | Aviso «Mientras no estabas» | 3 |
| Tirada extra en la tragaperras (cuando se acaban las gratis) | La feria | 3 |
| Sobre de regalo | Álbum › Monedas | 2 |
| Un día más para pagar la factura (en vez del cobrador) | Aviso «¡Llama el cobrador!» | 1 |

**Compras.** Ninguna hace ir más rápido.

| Producto (id en Play Console) | Precio | Qué da |
|---|---|---|
| `sin_anuncios` | 3,99 € | Los premios de arriba sin ver el vídeo |
| `paquete_inicio` | 1,99 € | La oveja y 3 sobres épicos (una vez) |
| `animal_perro`, `animal_gato`, `animal_zorro`, `animal_pollito` | 0,99 € cada uno | El animal |

Todos son productos **de compra única** (no consumibles). Los animales nuevos son modelos de Quaternius (CC0).

## Qué falta por tu parte (cuando subas el juego a Play)

1. **Play Console** → Monetizar → Productos → Productos integrados en la aplicación: crea los 6 productos con esos id y precios. Para eso hace falta un perfil de pagos.
2. **AdMob** (admob.google.com):
   - da de alta la app;
   - crea un bloque de anuncios **Bonificado**;
   - en Privacidad y mensajes, crea el mensaje del RGPD (Unión Europea).
3. **Secretos de GitHub** (repositorio → Settings → Secrets):
   - `FDM_ADMOB_APP_ID`: el id de la app (`ca-app-pub-…~…`);
   - `FDM_ADMOB_REWARDED`: el id del bloque (`ca-app-pub-…/…`).
   Mientras no estén, el juego usa los anuncios de prueba de Google.
4. **Política de privacidad:** `PRIVACIDAD.md` es un borrador. Hay que ponerle un correo de contacto y publicarla en una web (por ejemplo, tu página de GitHub). Play pide el enlace en la ficha.

Las compras solo funcionan cuando el juego se instala desde Google Play (aunque sea en la prueba cerrada). Con el APK instalado a mano, la tienda dice «La tienda abrirá cuando el juego esté en Google Play».
