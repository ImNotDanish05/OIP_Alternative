@tool
class_name OIPUIPlugin
extends EditorPlugin

const ICON: Texture2D = preload("res://assets/png/OIP-LOGO-RGB_ICON.svg")

const LIVE_SNAP_SHORTCUT_PATH := "Open Industry Project/Toggle Live Snap"
const SETTING_LIVE_SNAP := "open_industry_project/live_snap_enabled"

var _editor_node: Node
var _create_root_vbox: VBoxContainer
var _selected_nodes: Array[Node]
var _live_snap_button: Button
var _live_snap_shortcut: Shortcut
var _cam_track_timer: float = 0.0
var _last_saved_cam_transform: Transform3D = Transform3D()
var _last_forwarded_camera: Camera3D = null


func _enter_tree() -> void:
	set_input_event_forwarding_always_enabled()
	_editor_node = get_tree().root.get_child(0)
	if _editor_node and _editor_node.has_signal("editor_layout_loaded"):
		_editor_node.connect("editor_layout_loaded", _editor_layout_loaded)
	else:
		_editor_layout_loaded.call_deferred()

	var editor_settings := EditorInterface.get_editor_settings()
	var use_shortcut := Shortcut.new()
	var key_stroke := InputEventKey.new()
	key_stroke.keycode = KEY_C
	use_shortcut.events.append(key_stroke)
	editor_settings.add_shortcut("Open Industry Project/Use", use_shortcut)

	_live_snap_button = Button.new()
	_live_snap_button.flat = true
	_live_snap_button.toggle_mode = true
	_live_snap_button.icon = EditorInterface.get_editor_theme().get_icon("SnapGrid", "EditorIcons")
	_live_snap_button.toggled.connect(_on_live_snap_toggle)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _live_snap_button)

	if not editor_settings.has_setting(SETTING_LIVE_SNAP):
		editor_settings.set_setting(SETTING_LIVE_SNAP, true)
	editor_settings.set_initial_value(SETTING_LIVE_SNAP, true, false)
	_live_snap_button.button_pressed = editor_settings.get_setting(SETTING_LIVE_SNAP)
	ConveyorSnapping.live_snap_enabled = _live_snap_button.button_pressed

	_live_snap_shortcut = Shortcut.new()
	var live_snap_key := InputEventKey.new()
	live_snap_key.keycode = KEY_N
	_live_snap_shortcut.events.append(live_snap_key)
	editor_settings.add_shortcut(LIVE_SNAP_SHORTCUT_PATH, _live_snap_shortcut)
	_live_snap_shortcut = editor_settings.get_shortcut(LIVE_SNAP_SHORTCUT_PATH)
	_live_snap_shortcut.changed.connect(_update_live_snap_tooltip)
	_update_live_snap_tooltip()

	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)


func _editor_layout_loaded() -> void:
	_create_root_vbox = _editor_node.find_child("BeginnerNodeShortcuts", true, false)

	if _create_root_vbox:
		var button := Button.new()
		button.text = "New Simulation"
		button.icon = ICON
		button.pressed.connect(self._new_simulation_btn_pressed)
		_create_root_vbox.add_child(button)
		_create_root_vbox.move_child(button, 0)
		_create_root_vbox.move_child(_create_root_vbox.get_child(1), 2)

	if get_tree().edited_scene_root == null:
		_create_new_simulation()
		if (EditorInterface as Object).has_method("mark_scene_as_saved"):
			(EditorInterface as Object).call("mark_scene_as_saved")


func _process(delta: float) -> void:
	_track_editor_camera(delta)
	for node: Node in _selected_nodes:
		if not node:
			return
		if node.has_method("selected"):
			node.call("selected")


func _forward_3d_gui_input(viewport_camera: Camera3D, _event: InputEvent) -> int:
	if viewport_camera:
		_last_forwarded_camera = viewport_camera
		_check_and_save_camera(viewport_camera)
	return AfterGUIInput.AFTER_GUI_INPUT_PASS


func _track_editor_camera(delta: float) -> void:
	_cam_track_timer += delta
	if _cam_track_timer < 0.1:
		return
	_cam_track_timer = 0.0

	var cam: Camera3D = _get_editor_camera()
	if cam:
		_check_and_save_camera(cam)


func _check_and_save_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	if cam.global_transform != _last_saved_cam_transform:
		_last_saved_cam_transform = cam.global_transform
		_save_editor_camera(cam)


func _get_editor_camera() -> Camera3D:
	if _last_forwarded_camera != null and is_instance_valid(_last_forwarded_camera):
		return _last_forwarded_camera

	var vp: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	if vp:
		var c: Camera3D = vp.get_camera_3d()
		if c:
			return c
		var cameras: Array[Node] = vp.find_children("*", "Camera3D", true, false)
		if not cameras.is_empty():
			return cameras[0] as Camera3D
	return null


func _save_editor_camera(cam: Camera3D) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "transform", cam.global_transform)
	cfg.set_value("camera", "fov", cam.fov)
	cfg.save("res://oip_data/editor_camera.cfg")


func _build() -> bool:
	var cam: Camera3D = _get_editor_camera()
	if cam:
		_save_editor_camera(cam)
	return true


func _shortcut_input(event: InputEvent) -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.is_shortcut("Open Industry Project/Use", event) and event.is_pressed() and not event.is_echo():
		for node: Node in EditorInterface.get_selection().get_selected_nodes():
			if node.has_method("use"):
				node.call("use")
	if editor_settings.is_shortcut(LIVE_SNAP_SHORTCUT_PATH, event) and event.is_pressed() and not event.is_echo():
		_live_snap_button.button_pressed = not _live_snap_button.button_pressed


func _exit_tree() -> void:
	var cam: Camera3D = _get_editor_camera()
	if cam:
		_save_editor_camera(cam)
	if _live_snap_shortcut and _live_snap_shortcut.changed.is_connected(_update_live_snap_tooltip):
		_live_snap_shortcut.changed.disconnect(_update_live_snap_tooltip)
	if _live_snap_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _live_snap_button)
		_live_snap_button.queue_free()


func _on_live_snap_toggle(pressed: bool) -> void:
	EditorInterface.get_editor_settings().set_setting(SETTING_LIVE_SNAP, pressed)
	ConveyorSnapping.live_snap_enabled = pressed


func _update_live_snap_tooltip() -> void:
	if not _live_snap_button:
		return
	var shortcut_text := _live_snap_shortcut.get_as_text() if _live_snap_shortcut else ""
	var title := "Toggle Live Snap"
	if not shortcut_text.is_empty() and shortcut_text != "None":
		title += " (" + shortcut_text + ")"
	_live_snap_button.tooltip_text = title + "\nWhen on, parts snap to neighbours during gizmo drags and drop hover.\nHold Alt to escape snap for a single drag."


func _on_selection_changed() -> void:
	_selected_nodes = EditorInterface.get_selection().get_selected_nodes()


func _new_simulation_btn_pressed() -> void:
	get_undo_redo().create_action("Create New Simulation")
	get_undo_redo().add_do_method(self, "_create_new_simulation")
	get_undo_redo().add_undo_method(self, "_remove_new_simulation")
	get_undo_redo().commit_action()


func _create_new_simulation() -> void:
	var scene := Node3D.new()
	scene.name = "Simulation"
	var building: Node3D = load("res://parts/Building.tscn").instantiate()
	if (EditorInterface as Object).has_method("add_root_node"):
		(EditorInterface as Object).call("add_root_node", scene)
	elif get_tree().edited_scene_root:
		get_tree().edited_scene_root.add_child(scene)
	if get_tree().edited_scene_root:
		get_tree().edited_scene_root.add_child(building)
		building.owner = scene
		# Also add a runtime Player (capsule) so pressing Play immediately gives a controllable character.
		if ResourceLoader.exists("res://parts/Player.tscn"):
			var player: Node3D = load("res://parts/Player.tscn").instantiate()
			player.position = Vector3(0.0, 2.0, 8.0)
			get_tree().edited_scene_root.add_child(player)
			player.owner = scene


func _remove_new_simulation() -> void:
	if (EditorInterface as Object).has_method("remove_root_node"):
		(EditorInterface as Object).call("remove_root_node")
