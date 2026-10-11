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
## Cada paso puede llevar radio: [[quién, texto], ...] que suena al empezarlo, y calm: true (menos zombis).

const MISSIONS := [
	{ "id": "m1", "name": "Motín en Punta Roja", "map": "prison", "round": 3, "cap": 9, "rate": 2.4, "points": 1500, "weapon": "m1911",
	  "par_time": 600,
	  "desc": "Se ha perdido el contacto con la penitenciaría de Punta Roja. Entra, encuentra la radio del alcaide y pide extracción.",
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
		{ "type": "door", "text": "Abre la puerta del patio trasero", "door": 5,
		  "radio": [["CONTROL", "La radio necesita corriente. El generador está en el patio trasero."]] },
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
]

static func get_mission(id: String) -> Dictionary:
	for m in MISSIONS:
		if m.id == id: return m
	return {}

static func index_of(id: String) -> int:
	for i in MISSIONS.size():
		if MISSIONS[i].id == id: return i
	return -1
