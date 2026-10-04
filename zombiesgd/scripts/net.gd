extends Node
## Cooperativo por wifi (2 a 4 jugadores, iPhone y Android mezclados): el que crea la partida hace de servidor.
## El servidor manda en el mundo (zombis, rondas, puertas, caja, potenciadores, easter egg); cada móvil manda en su
## propio jugador (movimiento, armas, puntos). Las partidas de la red se encuentran solas (aviso por difusión UDP)
## y, por si la wifi lo bloquea, también se puede entrar escribiendo la IP que enseña el anfitrión.

signal lobby_changed
signal hosts_changed
signal join_failed(msg: String)
signal left

const PORT := 24680
const DISCOVERY_PORT := 24681
const MAX_PLAYERS := 4
var active = false            # hay una sesión de red (en solitario es false)
var players = {}              # peer -> { name, character, ready }
var hosts = {}                # ip -> { name, map, n, t }
var lobby = { "map": "prison", "start_round": 1 }
var game: Node = null
var udp_send: PacketPeerUDP
var udp_listen: PacketPeerUDP
var bcast_t = 0.0
var snap_t = 0.0
var my_name = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _close(); join_failed.emit("No se pudo conectar"))
	multiplayer.server_disconnected.connect(func(): _close(); left.emit())
	my_name = str(GS.settings.get("name", ""))
	if my_name == "": my_name = OS.get_model_name() if OS.get_model_name() != "GenericDevice" else "Jugador"

func is_host() -> bool: return not active or multiplayer.is_server()
func my_id() -> int: return multiplayer.get_unique_id() if active else 1
func is_coop() -> bool: return active and players.size() > 1

## IP de este móvil en la wifi (para que los demás la escriban si no aparece la partida sola)
func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31): return a
	return "?"

# ------------------------------------------------------------------ sala
func host() -> bool:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_PLAYERS) != OK: return false
	multiplayer.multiplayer_peer = peer
	active = true
	players = { 1: { "name": my_name, "character": GS.character, "ready": true, "level": GS.level } }
	lobby = { "map": GS.sel_map, "start_round": GS.start_round }
	udp_send = PacketPeerUDP.new(); udp_send.set_broadcast_enabled(true)
	lobby_changed.emit()
	return true

func join(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK: join_failed.emit("Dirección no válida"); return
	multiplayer.multiplayer_peer = peer
	active = true

func leave() -> void:
	_close(); left.emit()

func _close() -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false; players.clear(); game = null
	if udp_send: udp_send.close(); udp_send = null

## buscar partidas en la wifi
func start_discovery() -> void:
	stop_discovery()
	udp_listen = PacketPeerUDP.new()
	if udp_listen.bind(DISCOVERY_PORT) != OK: udp_listen = null
	hosts.clear()

func stop_discovery() -> void:
	if udp_listen: udp_listen.close(); udp_listen = null

func _process(d: float) -> void:
	if udp_listen:
		while udp_listen.get_available_packet_count() > 0:
			var pkt = udp_listen.get_packet().get_string_from_utf8(); var ip = udp_listen.get_packet_ip()
			var info = JSON.parse_string(pkt)
			if typeof(info) == TYPE_DICTIONARY and info.get("game", "") == "shrimpzombies":
				var isnew = not hosts.has(ip)
				hosts[ip] = info; hosts[ip]["t"] = Time.get_ticks_msec()
				if isnew: hosts_changed.emit()
		for ip in hosts.keys():
			if Time.get_ticks_msec() - int(hosts[ip].t) > 4000: hosts.erase(ip); hosts_changed.emit()
	if active and multiplayer.is_server() and udp_send and game == null:
		bcast_t -= d
		if bcast_t <= 0.0:
			bcast_t = 1.0
			var msg = JSON.stringify({ "game": "shrimpzombies", "name": my_name, "map": lobby.map, "n": players.size() }).to_utf8_buffer()
			udp_send.set_dest_address("255.255.255.255", DISCOVERY_PORT); udp_send.put_packet(msg)
	if active and game and is_instance_valid(game) and game.player:
		snap_t -= d
		if snap_t <= 0.0:
			snap_t = 0.05
			var p: Player = game.player
			p_state.rpc(p.global_position, p.yaw, p.pitch, p.state_flags(), p.cur_w().id if p.weapons.size() > 0 else "", p.hp / p.max_hp)
			if multiplayer.is_server(): game.send_zombie_snapshot()

func _on_peer_connected(_id: int) -> void: pass

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		if multiplayer.is_server(): lobby_sync.rpc(players, lobby)
		lobby_changed.emit()
		if game and is_instance_valid(game): game.remove_remote(id)

func _on_connected() -> void:
	hello.rpc_id(1, my_name, GS.character, GS.level)

@rpc("any_peer", "reliable")
func hello(name: String, character: String, level: int) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if game != null or players.size() >= MAX_PLAYERS:
		kicked.rpc_id(id, "La partida ya ha empezado o está llena"); return
	players[id] = { "name": name, "character": character, "ready": false, "level": level }
	lobby_sync.rpc(players, lobby); lobby_changed.emit()

@rpc("authority", "reliable")
func kicked(msg: String) -> void:
	_close(); join_failed.emit(msg)

@rpc("authority", "reliable")
func lobby_sync(p: Dictionary, l: Dictionary) -> void:
	players = p; lobby = l; lobby_changed.emit()

## un jugador cambia su personaje en la sala
@rpc("any_peer", "reliable", "call_local")
func set_character(c: String) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	if players.has(id): players[id].character = c; lobby_sync.rpc(players, lobby); lobby_changed.emit()

func set_lobby(map: String, start_round: int) -> void:
	lobby = { "map": map, "start_round": start_round }
	if multiplayer.is_server(): lobby_sync.rpc(players, lobby); lobby_changed.emit()

## el anfitrión empieza: todos cargan el mapa con la misma semilla
func start_match() -> void:
	if not multiplayer.is_server(): return
	begin.rpc(lobby.map, int(lobby.start_round), randi(), players)

@rpc("authority", "reliable", "call_local")
func begin(map: String, start_round: int, seed_: int, p: Dictionary) -> void:
	if OS.get_cmdline_user_args().has("verbose"): print("BEGIN ", map, " ", p.keys())
	players = p
	GS.sel_map = map; GS.start_round = start_round
	seed(seed_)
	get_tree().root.get_node("Main").start_game()

## cada móvil avisa cuando ha cargado el mapa; el servidor arranca las rondas cuando están todos
@rpc("any_peer", "reliable", "call_local")
func loaded() -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	if players.has(id): players[id].ready = true
	for k in players:
		if not players[k].get("ready", false): return
	if game: game.all_loaded()

# ------------------------------------------------------------------ partida: jugadores
@rpc("any_peer", "unreliable_ordered")
func p_state(pos: Vector3, yaw: float, pitch: float, flags: int, wid: String, hp: float) -> void:
	if game and is_instance_valid(game): game.on_remote_state(multiplayer.get_remote_sender_id(), pos, yaw, pitch, flags, wid, hp)

@rpc("any_peer", "unreliable")
func p_shot(sound: String, pitch_: float) -> void:
	if game and is_instance_valid(game): game.on_remote_shot(multiplayer.get_remote_sender_id(), sound, pitch_)

## daño a un zombi hecho por un cliente: lo aplica el servidor
@rpc("any_peer", "reliable")
func hit(zid: int, dmg: float, head: bool, kind: String, wid: String) -> void:
	if game and is_instance_valid(game) and multiplayer.is_server(): game.on_net_hit(multiplayer.get_remote_sender_id(), zid, dmg, head, kind, wid)

## el servidor le da a cada jugador los puntos de sus disparos y bajas
@rpc("authority", "reliable")
func award(pts: int, kill: bool, head: bool, kind: String, wid: String) -> void:
	if game and is_instance_valid(game): game.on_award(pts, kill, head, kind, wid)

@rpc("authority", "reliable")
func hurt(dmg: float) -> void:
	if game and is_instance_valid(game) and game.player: game.player.take_damage(dmg)

## caído, levantado o muerto (lo manda cada jugador sobre sí mismo)
@rpc("any_peer", "reliable", "call_local")
func life(state: String) -> void:
	var id = multiplayer.get_remote_sender_id()
	if id == 0: id = my_id()
	if game and is_instance_valid(game): game.on_life(id, state)

## reanimar a un compañero
@rpc("any_peer", "reliable")
func revive_peer() -> void:
	if game and is_instance_valid(game) and game.player: game.player.revived_by_friend()

# ------------------------------------------------------------------ partida: zombis
@rpc("authority", "reliable")
func z_spawn(zid: int, kind: String, type: String, pos: Vector3, speed: float) -> void:
	if game and is_instance_valid(game): game.on_z_spawn(zid, kind, type, pos, speed)

@rpc("authority", "unreliable_ordered")
func z_snap(data: PackedFloat32Array) -> void:
	if game and is_instance_valid(game): game.on_z_snap(data)

@rpc("authority", "reliable")
func z_dead(zid: int, head: bool) -> void:
	if game and is_instance_valid(game): game.on_z_dead(zid, head)

# ------------------------------------------------------------------ partida: mundo (puertas, caja, rondas...)
## un cliente pide usar algo del mundo; el servidor contesta si se puede
@rpc("any_peer", "reliable")
func world_req(idx: int, action: String, arg: Variant) -> void:
	if game and is_instance_valid(game) and multiplayer.is_server(): game.on_world_req(multiplayer.get_remote_sender_id(), idx, action, arg)

@rpc("authority", "reliable")
func world_res(idx: int, action: String, ok: bool, result: Variant) -> void:
	if game and is_instance_valid(game): game.on_world_res(idx, action, ok, result)

## algo cambia en el mundo y lo ven todos
@rpc("authority", "reliable", "call_local")
func world_evt(name: String, data: Variant) -> void:
	if game and is_instance_valid(game): game.on_world_evt(name, data)

@rpc("authority", "reliable", "call_local")
func game_over() -> void:
	if game and is_instance_valid(game): game.on_game_over()
