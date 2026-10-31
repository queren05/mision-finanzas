# Traducciones de Fin de Mes

Los textos se escriben en español en el código. Los otros idiomas salen de `app/src/main/assets/i18n/en.json` y `pt.json`.

Para añadir o cambiar un texto:
1. `python3 extract.py ../app/src/main/java/es/david/findemes keys.json` saca todos los textos del código.
2. Añade la línea `("español", "English", "português")` en `tr1.py`, `tr2.py` o `tr3.py`.
3. `python3 build.py ../app/src/main/assets/i18n` crea los JSON y avisa de lo que falta por traducir.

Los textos con variables van con `tf("Vence en %1 días", n)`.
