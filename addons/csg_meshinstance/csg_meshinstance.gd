@tool
extends EditorPlugin

#const META_EDITING := &"CSGMeshInstance_editing"
const META_EDIT_TREE := &"MeshInstanceCSGEditorTree"

const CSG_ROOT_NAME := "MeshInstanceCSGEditor"

var enable_editing_button: Button
var disable_editing_menu_button: MenuButton
var disable_editing_menu_button_popup: PopupMenu
var editing := false



var selected_mesh_instances: Array[Node]

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_selection_changed)

	enable_editing_button = Button.new()
	enable_editing_button.text = "Edit mesh as CSG"
	enable_editing_button.icon = EditorInterface.get_editor_theme().get_icon("CSGBox3D", "EditorIcons")
	enable_editing_button.flat = true
	enable_editing_button.pressed.connect(_on_enable_editing_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, enable_editing_button)

	disable_editing_menu_button = MenuButton.new()
	disable_editing_menu_button.text = "CSG changes"
	disable_editing_menu_button.icon = EditorInterface.get_editor_theme().get_icon("CSGBox3D", "EditorIcons")
	disable_editing_menu_button.flat = true

	disable_editing_menu_button_popup = disable_editing_menu_button.get_popup()
	disable_editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("MeshInstance3D", "EditorIcons"), "Apply to current mesh")
	disable_editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("MultiMeshInstance3D", "EditorIcons"), "Apply to new mesh")
	disable_editing_menu_button_popup.add_separator()
	disable_editing_menu_button_popup.add_icon_item(EditorInterface.get_editor_theme().get_icon("GuiClose", "EditorIcons"), "Discard changes")
	disable_editing_menu_button_popup.id_pressed.connect(_on_popup_id_pressed)

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, disable_editing_menu_button)



func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_selection_changed)

	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, enable_editing_button)
	enable_editing_button.queue_free()

	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, disable_editing_menu_button)
	disable_editing_menu_button.queue_free()


func _on_editor_selection_selection_changed() -> void:
	selected_mesh_instances = EditorInterface.get_selection().get_selected_nodes().filter(func(node:Node): return node.get_class() == "MeshInstance3D")
	if selected_mesh_instances.is_empty():
		enable_editing_button.visible = false
		disable_editing_menu_button.visible = false
		return


	editing = _is_mesh_instance_editing(selected_mesh_instances[0])

	_update_buttons()

func _on_enable_editing_button_pressed() -> void:
	if not editing:
		for mesh_instance in selected_mesh_instances:
			if mesh_instance.mesh != null:
				editing = true
				break
		if not editing:
			printerr("MeshInstance mesh is null.")
			return
	else:
		editing = false

	var current_selected_mesh_instance_list := selected_mesh_instances.duplicate()
	for mesh_instance in selected_mesh_instances:
		_update_mesh_instance_editing(mesh_instance)


	_update_buttons()

	for selected_mesh_inst:Node in current_selected_mesh_instance_list:
		EditorInterface.get_selection().add_node.call_deferred(selected_mesh_inst)


func _is_mesh_instance_editing(mesh_instance: MeshInstance3D) -> bool:
	return mesh_instance.has_node(CSG_ROOT_NAME)


func _update_mesh_instance_editing(mesh_instance: MeshInstance3D) -> void:
	if editing:
		if not _is_mesh_instance_editing(mesh_instance) and mesh_instance.mesh != null:
			var csg_combiner:MeshInstanceCSGEditor
			if not mesh_instance.mesh.has_meta(META_EDIT_TREE):
				csg_combiner = MeshInstanceCSGEditor.new()
				mesh_instance.add_child(csg_combiner)
				csg_combiner.name = CSG_ROOT_NAME
				csg_combiner.editor_description = "MeshInstanceCSGEditor: edit the csg then apply it from to the MeshInstance from it."
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

			#csg_combiner.mesh_resource_path = mesh_instance.mesh.resource_path
			#mesh_instance.mesh = mesh_instance.mesh


		# Make meshinstance invisible when editing.
		RenderingServer.instance_geometry_set_visibility_range(mesh_instance.get_instance(), 99999, 0, 0, 0, RenderingServer.VisibilityRangeFadeMode.VISIBILITY_RANGE_FADE_DISABLED)

		if not mesh_instance.child_exiting_tree.is_connected(_on_mesh_instance_child_exiting_tree):
			mesh_instance.child_exiting_tree.connect(_on_mesh_instance_child_exiting_tree.bind(mesh_instance))

	else:
		_update_mesh_instance_disabled_editing(mesh_instance)

	#update_mesh_instance_scene_tree_item.call_deferred(mesh_instance)

func _update_mesh_instance_disabled_editing(mesh_instance:MeshInstance3D, apply_mesh := true,  is_new_mesh := true) -> void:
	if not editing:
		if _is_mesh_instance_editing(mesh_instance):
			if apply_mesh:
				if not is_new_mesh:
					if mesh_instance.mesh == null:
						printerr("Current mesh is null.")
						return
					elif not _can_modify_mesh(mesh_instance.mesh):
						printerr("Current mesh is not ArrayMesh.")
						return
					#elif

				_apply_csg_child_to_mesh_instance(mesh_instance, is_new_mesh)

			var csg_combiner:MeshInstanceCSGEditor = mesh_instance.get_node(CSG_ROOT_NAME)
			csg_combiner.queue_free()

func _apply_csg_child_to_mesh_instance(mesh_instance: MeshInstance3D, is_new_mesh := true) -> void:
	var csg_combiner:MeshInstanceCSGEditor = mesh_instance.get_node(CSG_ROOT_NAME)
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
	#csg_combiner.mesh_resource_path = ""
	#mesh_instance.mesh = null

	mesh_instance.mesh.set_meta(META_EDIT_TREE, _get_node_data_tree(csg_combiner))


	#mesh_instance.set_meta(META_EDITING, editing)

func _can_modify_mesh(mesh:Mesh) -> bool:
	return mesh is ArrayMesh

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

func _on_mesh_instance_child_exiting_tree(child: Node, mesh_instance:MeshInstance3D) -> void:
	if child is MeshInstanceCSGEditor:
		_update_buttons()

		# Reset meshinstance visibility.
		RenderingServer.instance_geometry_set_visibility_range(mesh_instance.get_instance(),
															   mesh_instance.visibility_range_begin,
															   mesh_instance.visibility_range_end,
															   mesh_instance.visibility_range_begin_margin,
															   mesh_instance.visibility_range_end_margin,
															   int(mesh_instance.visibility_range_fade_mode))
		print("VISIBLE")
		mesh_instance.child_exiting_tree.disconnect(_on_mesh_instance_child_exiting_tree)

func _on_popup_id_pressed(id: int) -> void:
	print("PRESSED: ",id)
	editing = false
	match id:
		0:
			for mesh_instance in selected_mesh_instances:
				_update_mesh_instance_disabled_editing(mesh_instance, true, false)
		1:
			for mesh_instance in selected_mesh_instances:
				_update_mesh_instance_disabled_editing(mesh_instance, true, true)
		3:
			for mesh_instance in selected_mesh_instances:
				_update_mesh_instance_disabled_editing(mesh_instance, false)

	_update_buttons()

func _update_buttons() -> void:
	if editing:
		var csg_combiner:MeshInstanceCSGEditor = selected_mesh_instances[0].get_node(CSG_ROOT_NAME)
		enable_editing_button.visible = false
		disable_editing_menu_button.visible = true
		if selected_mesh_instances.size() > 1:
			disable_editing_menu_button.text = "CSG changes ({mesh_count} selected)".format({"mesh_count":selected_mesh_instances.size()})
		else:
			disable_editing_menu_button.text = "CSG changes"


		if selected_mesh_instances[0].mesh == null:
			disable_editing_menu_button_popup.set_item_disabled(0, true)
			disable_editing_menu_button_popup.set_item_text(0,"Apply to current mesh (Current mesh is null)")
		elif selected_mesh_instances[0].mesh is not ArrayMesh:
			disable_editing_menu_button_popup.set_item_disabled(0, true)
			disable_editing_menu_button_popup.set_item_text(0,"Apply to current mesh (Current mesh is not ArrayMesh)")
		elif selected_mesh_instances[0].mesh.resource_path == "":
			disable_editing_menu_button_popup.set_item_disabled(0, false)
			disable_editing_menu_button_popup.set_item_text(0,"Apply to current mesh")
		else:
			disable_editing_menu_button_popup.set_item_disabled(0, false)
			if selected_mesh_instances.size() > 1:
				disable_editing_menu_button_popup.set_item_text(0,"Apply to current meshes")
				disable_editing_menu_button_popup.set_item_text(1,"Apply to new meshes")
			else:
				disable_editing_menu_button_popup.set_item_text(0,"Apply to current mesh ({path})".format({"path" : selected_mesh_instances[0].mesh.resource_path}))
				disable_editing_menu_button_popup.set_item_text(1,"Apply to new mesh")
	else:
		enable_editing_button.visible = true
		disable_editing_menu_button.visible = false
		if selected_mesh_instances.size() > 1:
			enable_editing_button.text = "Edit mesh as CSG ({mesh_count} selected)".format({"mesh_count":selected_mesh_instances.size()})
		else:
			enable_editing_button.text = "Edit mesh as CSG"
