@tool
class_name MeshInstanceCSGEditor
extends CSGCombiner3D

var mesh_resource_path := ""
var current_mesh:Mesh

func _physics_process(delta: float) -> void:#(delta: float) -> void:#(_delta: float) -> void:
	transform = Transform3D.IDENTITY
