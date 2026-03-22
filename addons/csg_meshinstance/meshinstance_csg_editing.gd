@tool
class_name MeshInstanceCSGEditor
extends CSGCombiner3D

func _physics_process(delta: float) -> void:
	transform = Transform3D.IDENTITY
