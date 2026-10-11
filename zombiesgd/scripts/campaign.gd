class_name Campaign
extends RefCounted
## Modo historia: «Operación Gamba Roja».
## El brote empezó en la conservera Gamba Roja: su último cargamento de gambas contaminadas acabó en la cárcel
## de Punta Roja y en el pueblo de al lado. El Comando y Control (la capitana Ríos, por radio) intentan contenerlo.
##
## Cada misión es una lista de pasos. Tipos de paso:
##   collect: coger objetos brillantes (pos: [[x, z], ...]); give = arma que te dan al cogerlos
##   door:    ir a una puerta de pago y abrirla gratis (door = índice en la ficha del mapa)
##   goto:    llegar a un punto (pos [x, z], r)
##   survive: aguantar unos segundos
##   defend:  quedarse dentro de una zona (pos, r) hasta llenar la barra; brute = sale un Bruto al 60 %
##   power:   encender la corriente con la palanca del mapa
##   destroy: reventar depósitos (pos: [[x, z], ...], hp = vida de cada uno) a tiros o con explosiones
##   plant:   colocar cargas (pos: [[x, z], ...]); quedarse junto a cada una `time` segundos; estallan a los `fuse` s
##   boss:    un jefe (Bruto enorme) con barra de vida; hp = veces la vida de la ronda, name = su nombre
## Cada paso puede llevar radio: [[quién, texto], ...] que suena al empezarlo, y calm: true (menos zombis).

const MISSIONS := [
	{ "id": "m1", "name": "Motín en Punta Roja", "map": "prison", "round": 3, "cap": 10, "rate": 2.2, "points": 1500, "weapon": "m1911",
	  "par_time": 840,
	  "desc": "Se ha perdido el contacto con la penitenciaría de Punta Roja. Entra en el bloque de celdas, recupera la radio del alcaide y pide extracción.",
	  "intro": [["CONTROL", "Comando, aquí Control. Hace seis horas que no sabemos nada de la penitenciaría de Punta Roja."],
				["CONTROL", "El último camión de la conservera Gamba Roja descargó aquí ayer. Y después… nada. Ten cuidado ahí dentro."],
				["COMANDO", "Recibido. Entrando por el patio."]],
	  "steps": [
		{ "type": "collect", "text": "Coge el fusil del puesto de guardia", "pos": [[20.0, -1.0]], "give": "m16", "label": "M16", "calm": true,
		  "radio": [["COMANDO", "Con una pistola no voy a ningún lado. El puesto de guardia tiene que tener armas."]] },
		{ "type": "door", "text": "Abre la verja del pasillo oeste", "door": 0,
		  "radio": [["CONTROL", "El despacho del alcaide está al fondo del pasillo oeste. Busca su radio."]] },
		{ "type": "collect", "text": "Encuentra las piezas de la radio del alcaide", "pos": [[4.0, -14.0], [10.0, -22.0], [5.0, -30.0]], "label": "pieza de la radio",
		  "radio": [["COMANDO", "La radio está hecha pedazos. Alguien la reventó a propósito…"], ["CONTROL", "Recoge las piezas. Sin esa radio no te podemos sacar."]] },
		{ "type": "door", "text": "Sal al patio norte", "door": 3,
		  "radio": [["CONTROL", "Falta el módulo de cifrado. El alcaide lo guardaba en el bloque de celdas."]] },
		{ "type": "door", "text": "Entra en el bloque de celdas", "door": 9,
		  "radio": [["COMANDO", "La puerta principal del bloque. Está todo a oscuras ahí dentro…"]] },
		{ "type": "door", "text": "Abre la galería de celdas", "door": 10, "calm": true,
		  "radio": [["CONTROL", "Los registros dicen que el alcaide hacía la ronda por la pasarela de arriba."]] },
		{ "type": "collect", "text": "Busca el módulo de cifrado en la pasarela de arriba", "pos": [[32.4, -41.8, 4.45]], "label": "módulo de cifrado",
		  "radio": [["COMANDO", "Escaleras al fondo. Subo."]] },
		{ "type": "survive", "text": "¡Las celdas se abren! Aguanta", "time": 40.0,
		  "radio": [["COMANDO", "¡Se han abierto todas las celdas a la vez!"], ["CONTROL", "Alguien sigue dentro del sistema. ¡Aguanta, Comando!"]] },
		{ "type": "door", "text": "Ve al patio trasero por el pasillo oeste", "door": 5,
		  "radio": [["CONTROL", "Tienes el módulo. Ahora la radio necesita corriente: el generador está en el patio trasero."]] },
		{ "type": "power", "text": "Enciende el generador",
		  "radio": [["COMANDO", "Aquí está la palanca. Vamos a hacer ruido…"]] },
		{ "type": "defend", "text": "Defiende la radio mientras pide ayuda", "pos": [30.0, -49.0], "r": 7.0, "time": 75.0, "brute": true,
		  "radio": [["COMANDO", "Control, ¿me recibís? Radio montada."], ["CONTROL", "Te oímos alto y claro. Mantén la señal 75 segundos para fijar tu posición."], ["COMANDO", "Ya vienen. Muchos."]] },
		{ "type": "goto", "text": "Corre al helipuerto", "pos": [39.5, -47.0], "r": 3.0, "calm": true,
		  "radio": [["CONTROL", "¡Posición fijada! El helicóptero aterriza junto a la vieja máquina del patio. ¡Corre!"]] },
	  ],
	  "outro": [["CONTROL", "Te tenemos. Buen trabajo, Comando."], ["CONTROL", "Mala noticia: el camión de Gamba Roja también paró en el pueblo de al lado. Siguiente parada: el Pueblo."]] },
	{ "id": "m2", "name": "Pueblo en llamas", "map": "pueblo", "round": 6, "cap": 12, "rate": 1.8, "points": 2500, "weapon": "m16",
	  "par_time": 720,
	  "desc": "El helicóptero cae en el cruce del Pueblo. Consigue combustible y aguanta hasta que llegue la extracción.",
	  "intro": [["PILOTO", "¡Nos han dado! ¡Agarraos!"], ["CONTROL", "Comando, ¿sigues vivo? El helicóptero ha caído en el cruce del Pueblo."],
				["COMANDO", "Vivo. Y rodeado. El pueblo entero está en llamas."]],
	  "steps": [
		{ "type": "survive", "text": "Aguanta en el cruce", "time": 45.0,
		  "radio": [["CONTROL", "Aguanta en el cruce mientras buscamos otro transporte."]] },
		{ "type": "door", "text": "Despeja la barricada de la calle Este", "door": 3,
		  "radio": [["CONTROL", "El helicóptero de rescate necesita combustible para volver. La gasolinera está en la calle Este."]] },
		{ "type": "collect", "text": "Busca bidones de gasolina", "pos": [[30.0, 20.0], [50.0, 10.0], [44.0, 31.0]], "label": "bidón",
		  "radio": [["COMANDO", "Estoy en la gasolinera. Busco bidones."]] },
		{ "type": "door", "text": "Abre la calle Sur", "door": 6,
		  "radio": [["CONTROL", "Tenemos un claro para aterrizar al final de la calle Sur. Ve hacia allí."]] },
		{ "type": "defend", "text": "Defiende la zona de aterrizaje", "pos": [0.0, 33.0], "r": 7.0, "time": 90.0, "brute": true,
		  "radio": [["CONTROL", "Helicóptero en camino. Noventa segundos."], ["COMANDO", "Noventa segundos aquí son una eternidad…"]] },
		{ "type": "goto", "text": "¡Sube al helicóptero!", "pos": [0.0, 37.5], "r": 3.0, "calm": true,
		  "radio": [["PILOTO", "¡Toma de tierra! ¡Sube, sube, sube!"]] },
	  ],
	  "outro": [["CONTROL", "Estás fuera. Hemos analizado una gamba de la conservera: no es un virus normal."],
				["CONTROL", "Todo apunta a la fábrica de Gamba Roja. Descansa, Comando. Mañana vamos a por ellos."]] },
	{ "id": "m3", "name": "La Conservera", "map": "conservera", "round": 9, "cap": 14, "rate": 1.6, "points": 3000, "weapon": "m16",
	  "par_time": 900,
	  "desc": "Entra de noche en la fábrica de Gamba Roja, descubre qué cultivaban en su laboratorio y vuélalo todo.",
	  "intro": [["CONTROL", "Comando, estás en el muelle de la conservera Gamba Roja. Aquí empezó todo."],
				["CONTROL", "Necesitamos pruebas de lo que hacían dentro. Y después, que no quede nada en pie."],
				["COMANDO", "Huele a pescado podrido… y a algo peor."]],
	  "steps": [
		{ "type": "door", "text": "Abre la verja del patio de carga", "door": 0, "calm": true,
		  "radio": [["CONTROL", "La entrada de la nave da al patio de carga. Abre la verja del muelle."]] },
		{ "type": "collect", "text": "Busca la tarjeta del encargado", "pos": [[-13.0, -6.0]], "label": "tarjeta del encargado",
		  "radio": [["COMANDO", "El portón de la nave tiene un lector de tarjetas."], ["CONTROL", "El encargado usaba la carretilla del patio. Mira por allí."]] },
		{ "type": "door", "text": "Abre el portón de la nave de procesado", "door": 2,
		  "radio": [["COMANDO", "Tengo la tarjeta. Entro en la nave."]] },
		{ "type": "collect", "text": "Recoge muestras de las líneas de procesado", "pos": [[-17.0, 14.0], [0.5, -12.5], [5.5, 8.0]], "label": "muestra",
		  "radio": [["CONTROL", "Coge muestras de las líneas de procesado. Queremos saber qué metían en las latas."]] },
		{ "type": "power", "text": "Enciende el cuadro eléctrico de la nave",
		  "radio": [["COMANDO", "Hay una puerta blindada al fondo. Sin corriente no se abre."], ["CONTROL", "El cuadro eléctrico está en la pared este de la nave."]] },
		{ "type": "door", "text": "Entra en el laboratorio", "door": 3,
		  "radio": [["COMANDO", "La puerta del fondo se ha desbloqueado. Esto no es una fábrica de latas…"]] },
		{ "type": "destroy", "text": "Destruye los tanques de cultivo", "pos": [[-3.0, -20.0], [9.0, -20.0], [-3.0, -29.5], [9.0, -29.5]], "hp": 1200.0,
		  "radio": [["COMANDO", "Control… hay gambas gigantes flotando en tanques. Están vivas."], ["CONTROL", "Es la fuente del brote. ¡Destruye esos tanques!"]] },
		{ "type": "boss", "text": "Acaba con la Gamba Madre", "name": "La Gamba Madre", "pos": [0.0, -2.0], "hp": 0.5, "scale": 1.4, "ammo": true,
		  "radio": [["CONTROL", "¡Algo enorme acaba de romper el suelo de la nave!"], ["COMANDO", "Es la madre de todas. Vamos allá."]] },
		{ "type": "plant", "text": "Coloca cargas en las líneas de procesado", "pos": [[-3.0, -8.4], [3.5, -1.3], [-9.6, 11.0]], "time": 3.0, "fuse": 25.0,
		  "radio": [["CONTROL", "Bien hecho. Ahora coloca las cargas: que no quede ni una lata."]],
		  "radio_done": [["COMANDO", "Cargas puestas. Veinticinco segundos."], ["PILOTO", "¡Os espero en el muelle con el pesquero en marcha!"]] },
		{ "type": "goto", "text": "¡Corre al pesquero!", "pos": [-14.0, 29.6], "r": 3.0,
		  "radio": [["CONTROL", "¡Sal de ahí, Comando! ¡Al muelle!"]] },
	  ],
	  "outro": [["CONTROL", "Confirmado: la conservera ha volado por los aires. Buen trabajo, Comando."],
				["CONTROL", "Pero los informes del laboratorio mencionan otras plantas de Gamba Roja. Esto no ha terminado."]] },
]

static func get_mission(id: String) -> Dictionary:
	for m in MISSIONS:
		if m.id == id: return m
	return {}

static func index_of(id: String) -> int:
	for i in MISSIONS.size():
		if MISSIONS[i].id == id: return i
	return -1
