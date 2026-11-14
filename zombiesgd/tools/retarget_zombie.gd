extends SceneTree
## Adapta las animaciones de un zombi (zr_C, donde se ven bien) al esqueleto de otro (zr_A), que tiene los huesos
## orientados de otra forma: copiar los giros hueso a hueso deja las piernas abiertas y los pies patinando.
## Se copia el giro de cada hueso EN EL MUNDO respecto a su pose de reposo, y la cadera se mueve en proporción a la pierna.
## xvfb-run -a godot --path zombiesgd -s tools/retarget_zombie.gd     -> assets/models/zombies/zr_A_anims.res
const SRC := "res://assets/models/zombies/zr_C.glb"
const DST := "res://assets/models/zombies/zr_A.glb"
const OUT := "res://assets/models/zombies/zr_A_anims.res"
const FPS := 30.0
var done = false

func _key(n: String) -> String:
	var i = n.rfind("_")
	return n.substr(0, i) if i > 0 and n.substr(i + 1).is_valid_int() else n

func _process(_d) -> bool:
	if done: return true
	done = true
	var s: Node3D = load(SRC).instantiate(); root.add_child(s)
	var d: Node3D = load(DST).instantiate(); root.add_child(d)
	var sap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
	var dap: AnimationPlayer = d.find_child("AnimationPlayer", true, false)
	sap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	dap.active = false
	var ss: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
	var ds: Skeleton3D = d.find_children("*", "Skeleton3D", true, false)[0]
	ss.reset_bone_poses(); ds.reset_bone_poses()
	var Ws: Transform3D = ss.global_transform; var Wt: Transform3D = ds.global_transform
	var Wtb: Basis = Wt.basis.orthonormalized()
	var smap = {}
	for i in ss.get_bone_count(): smap[_key(ss.get_bone_name(i))] = i
	# reposo de los dos (giros en el mundo)
	var n = ds.get_bone_count()
	var src_of = []; var s_rest = []; var t_rest = []
	var hips = -1; var s_lo = INF; var t_lo = INF
	for i in ss.get_bone_count(): s_lo = min(s_lo, (Ws * ss.get_bone_global_rest(i).origin).y)
	for i in n:
		var k = _key(ds.get_bone_name(i))
		var si: int = smap.get(k, -1)
		src_of.append(si)
		t_rest.append((Wt.basis * ds.get_bone_global_rest(i).basis).orthonormalized())
		s_rest.append((Ws.basis * ss.get_bone_global_rest(si).basis).orthonormalized() if si >= 0 else Basis())
		t_lo = min(t_lo, (Wt * ds.get_bone_global_rest(i).origin).y)
		if k.ends_with("Hips") and hips < 0: hips = i
	# los dos esqueletos no descansan en la misma postura: se corrige el reposo del nuestro para que cada hueso apunte
	# hacia donde apunta el del original (cadera: con su eje arriba y su eje izquierda-derecha; el resto: hacia su hijo)
	var tkey = {}
	for i in n: tkey[_key(ds.get_bone_name(i))] = i
	var sp_of = func(sk: Skeleton3D, W: Transform3D, b: int) -> Vector3: return W * sk.get_bone_global_rest(b).origin
	var corr = []; corr.resize(n)
	for i in n:
		var si: int = src_of[i]
		var par = ds.get_bone_parent(i)
		var c: Basis = corr[par] if par >= 0 else Basis()
		if si >= 0:
			if i == hips:
				var f = func(sk: Skeleton3D, W: Transform3D, m: Dictionary) -> Basis:
					var up: Vector3 = (sp_of.call(sk, W, m["mixamorigSpine"]) - sp_of.call(sk, W, m["mixamorigHips"])).normalized()
					var right: Vector3 = (sp_of.call(sk, W, m["mixamorigRightUpLeg"]) - sp_of.call(sk, W, m["mixamorigLeftUpLeg"])).normalized()
					var fw = right.cross(up).normalized(); right = up.cross(fw).normalized()
					return Basis(right, up, fw)
				c = f.call(ss, Ws, smap) * (f.call(ds, Wt, tkey) as Basis).inverse()
			else:
				# hijo principal: el que tiene pareja (en la mano, el dedo corazón)
				var child = -1
				for ch in ds.get_bone_children(i):
					var sc: int = src_of[ch]
					if sc < 0 or ss.get_bone_parent(sc) != si: continue
					var nm = ds.get_bone_name(ch)
					if child < 0 or nm.contains("Middle") or nm.contains("Neck") or (nm.contains("Spine") and not ds.get_bone_name(child).contains("Neck")): child = ch
				if child >= 0:
					var td: Vector3 = (sp_of.call(ds, Wt, child) - sp_of.call(ds, Wt, i)).normalized()
					var sd: Vector3 = (sp_of.call(ss, Ws, src_of[child]) - sp_of.call(ss, Ws, si)).normalized()
					# la dirección del nuestro tras la corrección del padre ya aplicada al hueso (se arrastra el giro del padre para repartir la torsión)
					var base: Basis = corr[par] if par >= 0 else Basis()
					var td2: Vector3 = (base * td).normalized()
					var q = Quaternion(td2, sd) if td2.dot(sd) < 0.999999 else Quaternion.IDENTITY
					c = Basis(q) * base
		corr[i] = c
		t_rest[i] = (c * t_rest[i]).orthonormalized()
	var s_hip0: Vector3 = Ws * ss.get_bone_global_rest(src_of[hips]).origin
	var t_hip0: Vector3 = Wt * ds.get_bone_global_rest(hips).origin
	# proporción de piernas (muslo + espinilla): el reposo del nuestro tiene las piernas abiertas y la altura de la cadera engaña
	var leg = func(sk: Skeleton3D, W: Transform3D, m: Dictionary) -> float:
		var a: Vector3 = sp_of.call(sk, W, m["mixamorigLeftUpLeg"]); var b: Vector3 = sp_of.call(sk, W, m["mixamorigLeftLeg"]); var c: Vector3 = sp_of.call(sk, W, m["mixamorigLeftFoot"])
		return a.distance_to(b) + b.distance_to(c)
	var ratio: float = leg.call(ds, Wt, tkey) / leg.call(ss, Ws, smap)
	print("huesos ", n, " sin pareja ", src_of.count(-1), " cadera ", ds.get_bone_name(hips), " proporción ", ratio)
	# ruta de las pistas, como las del modelo
	var prefix = ""
	var any: Animation = dap.get_animation(dap.get_animation_list()[0])
	for t in any.get_track_count():
		var p = String(any.track_get_path(t))
		if p.contains(":"): prefix = p.substr(0, p.rfind(":") + 1); break
	var lib = AnimationLibrary.new()
	for name in sap.get_animation_list():
		if name == "Orig" or name == "RESET": continue
		var src: Animation = sap.get_animation(name)
		var out = Animation.new(); out.length = src.length; out.loop_mode = src.loop_mode
		var rot = []
		for i in n:
			var t = out.add_track(Animation.TYPE_ROTATION_3D); out.track_set_path(t, NodePath(prefix + ds.get_bone_name(i))); rot.append(t)
		var pt = out.add_track(Animation.TYPE_POSITION_3D); out.track_set_path(pt, NodePath(prefix + ds.get_bone_name(hips)))
		sap.play(name)
		var frames = int(ceil(src.length * FPS))
		for f in frames + 1:
			var tm = min(src.length, f / FPS)
			sap.seek(min(tm, src.length - 0.0001), true); sap.advance(0.0)
			var world = []; world.resize(n)
			for i in n:
				var si: int = src_of[i]
				var par = ds.get_bone_parent(i)
				var pw: Basis = world[par] if par >= 0 else Wtb
				var w: Basis
				if si >= 0:
					var cur: Basis = (Ws.basis * ss.get_bone_global_pose(si).basis).orthonormalized()
					w = (cur * s_rest[si].inverse()) * t_rest[i]
				else:
					w = pw * ds.get_bone_rest(i).basis.orthonormalized()
				world[i] = w
				out.rotation_track_insert_key(rot[i], tm, (pw.inverse() * w).orthonormalized().get_rotation_quaternion())
			# cadera: lo que se mueve la del original respecto a su reposo, en proporción al largo de la pierna
			var sp: Vector3 = Ws * ss.get_bone_global_pose(src_of[hips]).origin
			var tp: Vector3 = t_hip0 + (sp - s_hip0) * ratio
			var par_h = ds.get_bone_parent(hips)
			var px: Transform3D = Wt
			if par_h >= 0: px = Wt * ds.get_bone_global_rest(par_h)
			out.position_track_insert_key(pt, tm, px.affine_inverse() * tp)
		lib.add_animation(name, out)
		print("  ", name, " ", frames, " fotogramas")
	print("guardado ", OUT, " ", ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS))
	quit()
	return true
