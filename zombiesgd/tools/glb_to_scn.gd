extends SceneTree
## Convierte modelos .glb sin texturas (colores lisos, como los de Quaternius de Poly Pizza) en escenas .scn
## comprimidas: ocupan mucho menos que los .glb importados.
## godot --headless --path zombiesgd -s tools/glb_to_scn.gd -- <carpeta con .glb> <carpeta res:// de destino>
func _initialize() -> void:
	var a = OS.get_cmdline_user_args(); var src: String = a[0]; var dst: String = a[1]
	for f in DirAccess.get_files_at(src):
		if not f.ends_with(".glb"): continue
		var doc = GLTFDocument.new(); var st = GLTFState.new()
		if doc.append_from_file(src + "/" + f, st) != OK: print("FALLA ", f); continue
		var n: Node = doc.generate_scene(st)
		for c in n.find_children("*", "", true, false): c.owner = n
		var ps = PackedScene.new(); ps.pack(n)
		var out = dst + "/" + f.get_basename() + ".scn"
		print("SCN ", out, " ", ResourceSaver.save(ps, out, ResourceSaver.FLAG_COMPRESS))
		n.free()
	quit()
