extends SceneTree
func _initialize():
	var a = OS.get_cmdline_user_args(); var nm: NavigationMesh = load("res://assets/maps/%s/nav/%s.res" % [a[0], a[1]])
	var v = nm.get_vertices(); var h = {}
	for p in v: var k = snapped(p.y, 0.25); h[k] = h.get(k, 0) + 1
	var ks = h.keys(); ks.sort()
	for k in ks: if h[k] > 8: print("y=", k, " n=", h[k])
	# polígonos por altura con su caja
	var groups = {}
	for i in nm.get_polygon_count():
		var poly = nm.get_polygon(i); var c = Vector3()
		for q in poly: c += v[q]
		c /= poly.size(); var k = snapped(c.y, 1.0)
		if not groups.has(k): groups[k] = AABB(c, Vector3.ZERO)
		groups[k] = groups[k].expand(c)
	for k in groups: print("planta y~", k, " ", groups[k])
	quit()
