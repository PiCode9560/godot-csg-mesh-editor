@tool
extends EditorPlugin

#const META_EDITING := &"CSGMeshInstance_editing"
const META_EDIT_TREE := &"MeshInstanceCSGEditorTree"

const CSG_ROOT_NAME := "MeshInstanceCSGEditor"

var SceneTreeEditor_tree: Tree
var SceneTreeEditor: Control

var enable_editing_button: Button
var enable_editing_menu_button: MenuButton
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
	enable_editing_button.icon = EditorInterface.get_editor_theme().get_icon("CSGBox3D", "EditorIcons")
	enable_editing_button.flat = true
	enable_editing_button.pressed.connect(_on_enable_editing_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, enable_editing_button)

	enable_editing_menu_button = MenuButton.new()
	enable_editing_menu_button.text = "Apply CSG changes to ..."
	enable_editing_menu_button.icon = EditorInterface.get_editor_theme().get_icon("CSGBox3D", "EditorIcons")
	enable_editing_menu_button.flat = true

	var popup := enable_editing_menu_button.get_popup()
	popup.add_item("...to current mesh")
	popup.add_item("...to new mesh")
	popup.id_pressed.connect(_on_popup_id_pressed)

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, enable_editing_menu_button)

	_get_scene_tree()

func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_selection_changed)

	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, enable_editing_button)
	enable_editing_button.queue_free()

	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, enable_editing_menu_button)
	enable_editing_menu_button.queue_free()


func _on_editor_selection_selection_changed() -> void:
	selected_mesh_instances = EditorInterface.get_selection().get_selected_nodes().filter(func(node:Node): return node.get_class() == "MeshInstance3D")
	if selected_mesh_instances.is_empty():
		enable_editing_button.visible = false
		enable_editing_menu_button.visible = false
		return


	editing = _is_mesh_instance_editing(selected_mesh_instances[0])

	_update_buttons()

func _on_enable_editing_button_pressed() -> void:
	editing = not editing

	var current_selected_mesh_instance_list := selected_mesh_instances.duplicate()
	for mesh_instance in selected_mesh_instances:
		_update_mesh_instance_editing(mesh_instance)


	if editing:
		enable_editing_button.text = "Apply CSG changes"
	else:
		enable_editing_button.text = "Edit mesh as CSG"

	for selected_mesh_inst:Node in current_selected_mesh_instance_list:
		EditorInterface.get_selection().add_node.call_deferred(selected_mesh_inst)


func _is_mesh_instance_editing(mesh_instance: MeshInstance3D) -> bool:
	return mesh_instance.has_node(CSG_ROOT_NAME)


func _update_mesh_instance_editing(mesh_instance: MeshInstance3D) -> void:
	if editing:
		if not _is_mesh_instance_editing(mesh_instance):
			var csg_combiner:MeshInstanceCSGEditor
			if not mesh_instance.has_meta(META_EDIT_TREE):
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
				var edit_tree = mesh_instance.get_meta(META_EDIT_TREE)
				csg_combiner = _add_node_from_data_tree(edit_tree, mesh_instance)
				csg_combiner.name = CSG_ROOT_NAME

			csg_combiner.mesh_resource_path = mesh_instance.mesh.resource_path

		mesh_instance.mesh = null
		if not mesh_instance.child_exiting_tree.is_connected(_on_mesh_instance_child_exiting_tree):
			mesh_instance.child_exiting_tree.connect(_on_mesh_instance_child_exiting_tree.bind(mesh_instance))

	else:
		_update_mesh_instance_disabled_editing(mesh_instance)

	#update_mesh_instance_scene_tree_item.call_deferred(mesh_instance)

func _update_mesh_instance_disabled_editing(mesh_instance:MeshInstance3D, new_mesh := true) -> void:
	if not editing:
		if mesh_instance.has_node(CSG_ROOT_NAME):
			if _is_mesh_instance_editing(mesh_instance):
				_apply_csg_child_to_mesh_instance(mesh_instance, true, new_mesh)

func _apply_csg_child_to_mesh_instance(mesh_instance: MeshInstance3D, remove_csg := true, new_mesh := true) -> void:
	if mesh_instance.child_exiting_tree.is_connected(_on_mesh_instance_child_exiting_tree):
		mesh_instance.child_exiting_tree.disconnect(_on_mesh_instance_child_exiting_tree)

	var csg_combiner:MeshInstanceCSGEditor = mesh_instance.get_node(CSG_ROOT_NAME)
	mesh_instance.mesh = csg_combiner.get_meshes()[1]
	if not new_mesh:
		mesh_instance.mesh.resource_path = csg_combiner.mesh_resource_path

	csg_combiner.mesh_resource_path = ""

	mesh_instance.set_meta(META_EDIT_TREE, _get_node_data_tree(csg_combiner))

	if remove_csg:
		csg_combiner.queue_free()
	#mesh_instance.set_meta(META_EDITING, editing)

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
		_apply_csg_child_to_mesh_instance(mesh_instance, false)
		mesh_instance.child_exiting_tree.disconnect(_on_mesh_instance_child_exiting_tree)

func _on_popup_id_pressed(id: int) -> void:
	print("PRESSED: ",id)
	editing = false
	match id:
		0:
			for mesh_instance in selected_mesh_instances:
				_update_mesh_instance_disabled_editing(mesh_instance, false)
		1:
			for mesh_instance in selected_mesh_instances:
				_update_mesh_instance_disabled_editing(mesh_instance, true)

	_update_buttons()

func _update_buttons() -> void:
	if editing:
		enable_editing_button.text = "Apply CSG changes"
		var csg_combiner:MeshInstanceCSGEditor = selected_mesh_instances[0].get_node(CSG_ROOT_NAME)
		if csg_combiner.mesh_resource_path == "":
			enable_editing_button.visible = true
			enable_editing_menu_button.visible = false
		else:
			enable_editing_button.visible = false
			enable_editing_menu_button.visible = true
			enable_editing_menu_button.get_popup().set_item_text(0,"...to current mesh ({path})".format({"path" : csg_combiner.mesh_resource_path}))
	else:
		enable_editing_button.text = "Edit mesh as CSG"
		enable_editing_button.visible = true
		enable_editing_menu_button.visible = false

#region Scene tree icon display.

func _update_scene_tree_editor() -> void:
	print("NODE CHANGED")
	await get_tree().process_frame
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root:
		for mesh_instance in scene_root.find_children("", "MeshInstance3D", true, false):
			update_mesh_instance_scene_tree_item.call_deferred(mesh_instance)

func update_mesh_instance_scene_tree_item(mesh_instance: MeshInstance3D) -> void:
	var path := EditorInterface.get_edited_scene_root().get_path_to(mesh_instance)
	var tree_item := SceneTreeEditor_tree.get_root()

	#print("PATH: ", path)
	for i in range(0, path.get_name_count()):
		#print("------------")
		if not tree_item:
			return
		#for c:TreeItem in tree_item.get_children():
			#print(c.get_text(0))
		var find_item := tree_item.get_children().find_custom(func(c:TreeItem): return c.get_text(0) == path.get_name(i))
		if find_item == -1:
			return

		tree_item = tree_item.get_child(find_item)

	if not tree_item:
		return

	var texture := EditorInterface.get_editor_theme().get_icon("CSGCombiner3D", "EditorIcons")
	var size := tree_item.get_button(0, 0).get_size()
	var image := texture.get_image()
	image.resize(size.x ,size.y)
	texture = ImageTexture.create_from_image(image)

	if mesh_instance.has_meta(META_EDIT_TREE):
		if tree_item.get_button_by_id(0, 389419) == -1:
			var buttons := []
			for i in tree_item.get_button_count(0):
				var t := tree_item.get_button(0, 0)
				var idx := tree_item.get_button_id(0, 0)
				var disable := tree_item.is_button_disabled(0, 0)
				var tooltip := tree_item.get_button_tooltip_text(0, 0)

				tree_item.erase_button(0, 0)
				buttons.append([t, idx, disable, tooltip])

			tree_item.add_button(0, texture, 389419, false, "This node contains MeshInstanceCSGEditor metadata")

			for button:Array in buttons:
				tree_item.add_button(0, button[0], button[1], button[2], button[3])

	else:
		if tree_item.get_button_by_id(0, 389419) != -1:
			tree_item.erase_button(0, tree_item.get_button_by_id(0, 389419))

func _on_scene_tree_node_added(node: Node) -> void:
	if node.get_class() == "SceneTreeEditor":
		_get_scene_tree()

func _get_scene_tree() -> void:
	SceneTreeEditor = EditorInterface.get_base_control().find_child("*SceneTreeEditor*", true, false)
	if SceneTreeEditor:
		#SceneTreeEditor.node_changed.connect(_update_scene_tree_editor)
		#SceneTreeEditor.node_renamed.connect(_update_scene_tree_editor)
		#SceneTreeEditor.node_selected.connect(_update_scene_tree_editor)
		#SceneTreeEditor.nodes_rearranged.connect(func(p, tp, t): _update_scene_tree_editor)
		SceneTreeEditor_tree = SceneTreeEditor.get_child(0)
		SceneTreeEditor_tree.draw.connect(_update_scene_tree_editor)

#endregion
