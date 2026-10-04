extends Node3D
func _ready():
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.5, 4); add_child(cam)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); add_child(l)
	var m := MeshInstance3D.new(); m.mesh = BoxMesh.new(); add_child(m)
