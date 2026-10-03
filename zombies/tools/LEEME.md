# Herramientas de assets de Shrimp Zombies

Todo se ejecuta en Chromium sin pantalla (Playwright, `pip install playwright && playwright install chromium`) y un servidor
estático. Las páginas importan three r170 y sus `examples/jsm` (descárgalos de jsdelivr a una carpeta `m/`, con `three.js` = `www/lib/three.module.min.js`)
y el simplificador `meshoptimizer@0.22.0/meshopt_simplifier.module.js` como `m/simplifier.js`.

- `fbx-a-glb.*`: convierte el zombi de ciudad (OpenGameArt, CC0) de FBX a GLB: reasigna los huesos `mixamorig*`→`CityDeadOutfit*`,
  deja las animaciones en el sitio, reduce texturas y simplifica la malla de 72k a ~10k triángulos.
- `props.*`: convierte objetos de Poly Haven (gltf con texturas) a GLB ligeros (texturas 512 px y tope de triángulos).
  Uso: `python props.py id1,id2 destino 512 2500`.
- `imp.*`: convierte un árbol pesado en dos imágenes con transparencia (planos cruzados). Salida en `www/models/i/`.
- `captura.py`: captura de pantalla con `?shot&play&map=...&t=...&look=x,y,z,tx,ty,tz`.

Medidas que usa el juego (ver `zombis.js`): velocidad real de cada animación de andar/correr (recorrido del pie respecto a la cadera por ciclo)
y el instante del golpe de cada animación de ataque. Si cambias de modelo hay que volver a medirlas.

Créditos: Poly Haven (CC0), Rikindle3D «Male City Zombie» (CC0), Kenney (CC0), Quaternius (CC0/CC-BY), poly.pizza.
