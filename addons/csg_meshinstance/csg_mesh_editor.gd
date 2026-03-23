@tool
extends EditorPlugin

const META_EDIT_TREE := &"CSGMeshEditorTree"
const CSG_ROOT_NAME := "CSGMeshEditor"

var editing_menu_button: MenuButton
var editing_menu_button_popup: PopupMenu

var selected_mesh_instances: Array[Node]


## On plugin entered tree.
func _enter_tree() -> void:
	EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_selection_changed)

	editing_menu_button = MenuButton.new()
	editing_menu_button.text = "CSGMeshEditor"
	editing_menu_button.icon = EditorInterface.get_editor_theme().get_icon("CSGBox3D", "EditorIcons")
	editing_menu_button.flat = true

	editing_menu_button_popup = editing_menu_button.get_popup()
	editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("CSGCombiner3D", "EditorIcons"), "Edit mesh as CSG")
	editing_menu_button_popup.add_separator()
	editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("MeshInstance3D", "EditorIcons"), "Apply CSG to current mesh")
	editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("MultiMeshInstance3D", "EditorIcons"), "Apply CSG to new mesh")
	editing_menu_button_popup.add_separator()
	editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("GuiClose", "EditorIcons"), "Discard changes")
	editing_menu_button_popup.id_pressed.connect(on_editing_menu_button_popup_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, editing_menu_button)

	resource_saved.connect(_on_resource_saved)
	scene_saved.connect(_on_scene_saved)


## On plugin exited tree.
func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_selection_changed)


	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, editing_menu_button)
	editing_menu_button.queue_free()


## On EditorSelection selection changed.
func _on_editor_selection_selection_changed() -> void:
	selected_mesh_instances = EditorInterface.get_selection().get_selected_nodes().filter(func(node:Node): return node.get_class() == "MeshInstance3D")

	_update_buttons()


## On resource saved.
func _on_resource_saved(resource: Resource) -> void:
	_update_buttons()

## On scene saved.
func _on_scene_saved(filepath: String) -> void:
	_update_buttons()


## On editing menu options selected.
func on_editing_menu_button_popup_pressed(id: int) -> void:
	print("PRESSED: ",id)
	match id:
		0: # enable editing.
			var is_mesh_null := true
			for mesh_instance in selected_mesh_instances:
				if mesh_instance.mesh != null:
					is_mesh_null = false
					break
			if is_mesh_null:
				printerr("MeshInstance mesh is null.")
				return

			var current_selected_mesh_instance_list := selected_mesh_instances.duplicate()

			for mesh_instance in selected_mesh_instances:
				_enable_mesh_instance_editing(mesh_instance)

			# Selection messed up. Need to be reselected.
			for selected_mesh_inst:Node in current_selected_mesh_instance_list:
				EditorInterface.get_selection().add_node.call_deferred(selected_mesh_inst)

		2: # Apply CSG as current mesh.
			for mesh_instance in selected_mesh_instances:
				_disable_mesh_instance_editing(mesh_instance, true, false)
		3: # Apply CSG as new mesh.
			for mesh_instance in selected_mesh_instances:
				_disable_mesh_instance_editing(mesh_instance, true, true)
		5: # Discard CSG changes.
			for mesh_instance in selected_mesh_instances:
				_disable_mesh_instance_editing(mesh_instance, false)

	await get_tree().process_frame
	_update_buttons()


## On editing mesh instance child exiting tree.
func _on_mesh_instance_child_exiting_tree(child: Node, mesh_instance:MeshInstance3D) -> void:
	if child is CSGMeshEditor:

		# Reset meshinstance visibility.
		RenderingServer.instance_geometry_set_visibility_range(mesh_instance.get_instance(),
															   mesh_instance.visibility_range_begin,
															   mesh_instance.visibility_range_end,
															   mesh_instance.visibility_range_begin_margin,
															   mesh_instance.visibility_range_end_margin,
															   int(mesh_instance.visibility_range_fade_mode))

		mesh_instance.child_exiting_tree.disconnect(_on_mesh_instance_child_exiting_tree)

		await child.tree_exited
		_update_buttons()

		print("CSGMeshEditor exited")


## enable mesh instance editing.
func _enable_mesh_instance_editing(mesh_instance: MeshInstance3D) -> void:
	if not _is_mesh_instance_editing(mesh_instance) and mesh_instance.mesh != null:
		var csg_combiner:CSGMeshEditor
		if not mesh_instance.mesh.has_meta(META_EDIT_TREE):
			csg_combiner = CSGMeshEditor.new()
			mesh_instance.add_child(csg_combiner)
			csg_combiner.name = CSG_ROOT_NAME
			csg_combiner.editor_description = "CSGMeshEditor: edit the csg then apply it from to the MeshInstance from it."
			csg_combiner.owner = mesh_instance.owner
			#csg_combiner.set_script(MeshInstanceCSGEditing)

			if mesh_instance.mesh != null:
				var csg_mesh := CSGMesh3D.new()
				csg_combiner.add_child(csg_mesh, true)
				csg_mesh.mesh = mesh_instance.mesh
				csg_mesh.owner = mesh_instance.owner
		else:
			var edit_tree = mesh_instance.mesh.get_meta(META_EDIT_TREE)
			csg_combiner = _add_node_from_data_tree(edit_tree, mesh_instance)
			csg_combiner.name = CSG_ROOT_NAME


	# Make meshinstance invisible when editing.
	RenderingServer.instance_geometry_set_visibility_range(mesh_instance.get_instance(), 99999, 0, 0, 0, RenderingServer.VisibilityRangeFadeMode.VISIBILITY_RANGE_FADE_DISABLED)

	if not mesh_instance.child_exiting_tree.is_connected(_on_mesh_instance_child_exiting_tree):
		mesh_instance.child_exiting_tree.connect(_on_mesh_instance_child_exiting_tree.bind(mesh_instance))


## Disable mesh instance editing.
func _disable_mesh_instance_editing(mesh_instance:MeshInstance3D, apply_mesh := true,  is_new_mesh := true) -> void:
	if _is_mesh_instance_editing(mesh_instance):
		if apply_mesh:
			if not is_new_mesh:
				if mesh_instance.mesh == null:
					printerr("Current mesh is null.")
					return
				elif not _can_modify_mesh(mesh_instance.mesh):
					printerr(_get_modify_mesh_failed_msg(mesh_instance.mesh))
					return

			_apply_csg_child_to_mesh_instance(mesh_instance, is_new_mesh)

		var csg_combiner:CSGMeshEditor = mesh_instance.get_node(CSG_ROOT_NAME)
		csg_combiner.queue_free()


## Apply the child CSG mesh into the mesh instance mesh.
## [code] is_new_mesh [/code] determine to create a new mesh or just use the current meshinstance mesh.
func _apply_csg_child_to_mesh_instance(mesh_instance: MeshInstance3D, is_new_mesh := true) -> void:
	if not _is_mesh_instance_editing(mesh_instance):
		print_debug("Error: Mesh instance is not in editing mode.")
		return

	var csg_combiner:CSGMeshEditor = mesh_instance.get_node(CSG_ROOT_NAME)
	var new_mesh:ArrayMesh = csg_combiner.get_meshes()[1]
	var current_mesh := mesh_instance.mesh

	if not is_new_mesh:
		if _can_modify_mesh(current_mesh):
			var array_mesh := current_mesh as ArrayMesh
			array_mesh.clear_surfaces()
			for i in new_mesh.get_surface_count():
				array_mesh.add_surface_from_arrays(new_mesh.surface_get_primitive_type(i), new_mesh.surface_get_arrays(i))
			mesh_instance.mesh = array_mesh

	else: # new mesh
		mesh_instance.mesh = new_mesh

	mesh_instance.mesh.set_meta(META_EDIT_TREE, _get_node_data_tree(csg_combiner))


## create load the CSG nodes into the scene from stored data.
func _add_node_from_data_tree(edit_tree:Array, parent:Node) -> Node:
	var node_class:String = edit_tree[0]
	var node := ClassDB.instantiate(node_class)
	parent.add_child(node)
	node.owner = parent.owner

	var node_properties:Dictionary = edit_tree[1]
	for key:String in node_properties.keys():
		node.set(key, node_properties[key])

	var children_data:Array = edit_tree[2]
	for child_data in children_data:
		_add_node_from_data_tree(child_data, node)

	return node


## get a node's children tree as a nested arrays, including their properties.
func _get_node_data_tree(node:Node) -> Array:
	var node_data := []

	node_data.append(node.get_class())

	var properties:Dictionary
	for property in node.get_property_list():
		var property_name:String = property["name"]

		match property_name:
			"global_position", "global_rotation", "global_rotation_degrees", "global_transform", "global_basis", "owner":
				continue

		var property_data := node.get(property_name)
		if property_data is NodePath:
			property_data = String(property_data)

		properties[property_name] = property_data
	node_data.append(properties)

	var children_data := []
	for child in node.get_children():
		var child_data := _get_node_data_tree(child)
		children_data.append(child_data)

	node_data.append(children_data)

	return node_data


## Update the tool buttons.
func _update_buttons() -> void:
	if selected_mesh_instances.is_empty():
		editing_menu_button.visible = false
		return

	var editing_mesh_instances := selected_mesh_instances.filter(func(mesh_int:MeshInstance3D): return _is_mesh_instance_editing(mesh_int))
	var non_editing_mesh_instances := selected_mesh_instances.filter(func(mesh_int:MeshInstance3D): return not _is_mesh_instance_editing(mesh_int))

	editing_menu_button.visible = true

	if selected_mesh_instances.size() > 1:
		editing_menu_button.text = "CSGMeshEditor ({mesh_count} selected)".format({"mesh_count":selected_mesh_instances.size()})
	else:
		editing_menu_button.text = "CSGMeshEditor"


	if not editing_mesh_instances.is_empty():
		var not_null_mesh_mesh_instances := editing_mesh_instances.filter(func(mesh_int:MeshInstance3D): return mesh_int.mesh != null)
		var all_mesh_cannot_modify := not_null_mesh_mesh_instances.all(func(mesh_int:MeshInstance3D): return not _can_modify_mesh(mesh_int.mesh))

		var plural_mesh := "mesh" if editing_mesh_instances.size() == 1 else "meshes"

		if not_null_mesh_mesh_instances.is_empty():
			editing_menu_button_popup.set_item_disabled(2, true)
			editing_menu_button_popup.set_item_text(2,"Apply CSG to current {mesh} (Current {mesh} is null)".format({"mesh": plural_mesh}))
		elif all_mesh_cannot_modify:
			editing_menu_button_popup.set_item_disabled(2, true)

			var all_same_failed_msg := true
			var compare_msg := _get_modify_mesh_failed_msg(editing_mesh_instances[0].mesh)
			for mesh_inst in editing_mesh_instances:
				if _get_modify_mesh_failed_msg(mesh_inst.mesh) != compare_msg:
					all_same_failed_msg = false
					break

			if not all_same_failed_msg:
				editing_menu_button_popup.set_item_text(2,"Apply CSG to current {mesh} (mesh cannot be modified)".format({"mesh": plural_mesh}))
			else:
				var failed_msg := _get_uncapitalized_string(_get_modify_mesh_failed_msg(editing_mesh_instances[0].mesh))
				editing_menu_button_popup.set_item_text(2,"Apply CSG to current {mesh} ({failed_msg})".format({"mesh": plural_mesh, "failed_msg": failed_msg}))
		else:
			editing_menu_button_popup.set_item_disabled(2, false)
			if editing_mesh_instances.size() > 1:
				var can_apply_to_current_mesh_mesh_instances := editing_mesh_instances.filter(func(mesh_inst: MeshInstance3D): return _can_modify_mesh(mesh_inst.mesh))
				editing_menu_button_popup.set_item_text(2,"Apply CSG to current meshes ({mesh_count})".format({"mesh_count": can_apply_to_current_mesh_mesh_instances.size()}))
			else:
				if editing_mesh_instances[0].mesh.resource_path == "":
					editing_menu_button_popup.set_item_text(2,"Apply CSG to current mesh")
				else:
					editing_menu_button_popup.set_item_text(2,"Apply CSG to current mesh ({path})".format({"path" : editing_mesh_instances[0].mesh.resource_path}))

		editing_menu_button_popup.set_item_disabled(3, false)
		editing_menu_button_popup.set_item_disabled(5, false)

		if selected_mesh_instances.size() > 1:
			editing_menu_button_popup.set_item_text(3,"Apply CSG to new {mesh} ({mesh_count})".format({"mesh": plural_mesh, "mesh_count": editing_mesh_instances.size()}))
			editing_menu_button_popup.set_item_text(5,"Discard CSG changes ({mesh_count})".format({"mesh_count": editing_mesh_instances.size()}))
		else:
			editing_menu_button_popup.set_item_text(3,"Apply CSG to new mesh")
			editing_menu_button_popup.set_item_text(5,"Discard CSG changes")

	else:
		editing_menu_button_popup.set_item_text(2,"Apply CSG to current mesh")
		editing_menu_button_popup.set_item_disabled(2, true)
		editing_menu_button_popup.set_item_text(3,"Apply CSG to new mesh")
		editing_menu_button_popup.set_item_disabled(3, true)
		editing_menu_button_popup.set_item_text(5,"Discard CSG changes")
		editing_menu_button_popup.set_item_disabled(5, true)


	if not non_editing_mesh_instances.is_empty():
		var plural_mesh := "mesh" if non_editing_mesh_instances.size() == 1 else "meshes"
		editing_menu_button_popup.set_item_disabled(0, false)
		if selected_mesh_instances.size() > 1:
			editing_menu_button_popup.set_item_text(0,"Edit {mesh} as CSG ({mesh_count})".format({"mesh": plural_mesh, "mesh_count": non_editing_mesh_instances.size()}))
		else:
			editing_menu_button_popup.set_item_text(0,"Edit mesh as CSG")
	else:
		editing_menu_button_popup.set_item_text(0,"Edit mesh as CSG")
		editing_menu_button_popup.set_item_disabled(0, true)


## Whether a mesh instance is in editing mode.
func _is_mesh_instance_editing(mesh_instance: MeshInstance3D) -> bool:
	return mesh_instance.has_node(CSG_ROOT_NAME)


## Whether a mesh geometries can be modified.
func _can_modify_mesh(mesh:Mesh) -> bool:
	return mesh is ArrayMesh and not mesh.resource_path.ends_with(".obj")


## Get modify mesh failed message.
func _get_modify_mesh_failed_msg(mesh:Mesh) -> String:
	if not mesh is ArrayMesh:
		return "Mesh is not ArrayMesh."
	elif mesh.resource_path.ends_with(".obj"):
		return ".obj file cannot be modified."
	return "Mesh cannot be modified."


## Uncapitalized first letter of a string.
func _get_uncapitalized_string(string:String) -> String:
	return string[0].to_lower() + string.substr(1,-1)
