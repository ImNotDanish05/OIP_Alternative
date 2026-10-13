@tool
class_name OIPCommsPlugin
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/oip_comms/controls/dock.tscn")
const DRIVER_IO_SCRIPT: GDScript = preload("res://addons/oip_comms/controls/driver_io_dock.gd")
const DOCK_NAME: String = "Comms"
const DRIVER_DOCK_NAME: String = "Driver I/O"

var _comms_dock: _OIPCommsDock
var _editor_dock: EditorDock
var _driver_io_dock: DriverIODock
var _driver_editor_dock: EditorDock
var _spatial_driver_btn: Button


func _enter_tree() -> void:
	# 1. Comms Dock (Tag Groups & Protocol Connections)
	_comms_dock = DOCK_SCENE.instantiate()
	_editor_dock = EditorDock.new()
	_editor_dock.name = DOCK_NAME
	_editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_editor_dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL | EditorDock.DOCK_LAYOUT_FLOATING
	_editor_dock.add_child(_comms_dock)
	add_dock(_editor_dock)
	
	_comms_dock.save_changes.connect(save_changes)
	scene_saved.connect(_scene_saved)

	# 2. Driver I/O Dock (Input & Output Variable Mapping per Open Scene)
	_driver_io_dock = DRIVER_IO_SCRIPT.new()
	_driver_editor_dock = EditorDock.new()
	_driver_editor_dock.name = DRIVER_DOCK_NAME
	_driver_editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_driver_editor_dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL | EditorDock.DOCK_LAYOUT_FLOATING
	_driver_editor_dock.add_child(_driver_io_dock)
	add_dock(_driver_editor_dock)

	# 3. 3D Spatial Editor Toolbar Button (Quick-access to Driver I/O)
	_spatial_driver_btn = Button.new()
	_spatial_driver_btn.text = "Driver I/O"
	_spatial_driver_btn.tooltip_text = "Configure Driver Input & Output Variables for Active Scene"
	_spatial_driver_btn.flat = true
	_spatial_driver_btn.pressed.connect(_on_spatial_driver_btn_pressed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _spatial_driver_btn)

	# Connect Comms button to Driver I/O if available
	if _comms_dock.has_signal("open_driver_io"):
		_comms_dock.connect("open_driver_io", _on_spatial_driver_btn_pressed)

	# 4. Scene tracking
	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(_on_scene_closed)
	main_screen_changed.connect(_on_main_screen_changed)
	call_deferred("_sync_active_scene")


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if scene_closed.is_connected(_on_scene_closed):
		scene_closed.disconnect(_on_scene_closed)
	if main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.disconnect(_on_main_screen_changed)

	if _spatial_driver_btn != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _spatial_driver_btn)
		_spatial_driver_btn.queue_free()
		_spatial_driver_btn = null

	if _driver_editor_dock != null:
		remove_dock(_driver_editor_dock)
		_driver_editor_dock.queue_free()
		_driver_editor_dock = null
		_driver_io_dock = null

	if _editor_dock != null:
		remove_dock(_editor_dock)
		_editor_dock.queue_free()
		_editor_dock = null
		_comms_dock = null


func save_changes(value: bool) -> void:
	if value:
		_editor_dock.name = DOCK_NAME + "(*)"
	else:
		_editor_dock.name = DOCK_NAME


func _scene_saved(_filepath: String) -> void:
	if _comms_dock != null:
		_comms_dock.save_all()


func _on_scene_changed(scene_root: Node) -> void:
	if _driver_io_dock != null:
		var root: Node = scene_root
		if root == null and Engine.is_editor_hint():
			root = EditorInterface.get_edited_scene_root()
		_driver_io_dock.set_scene_root(root)


func _on_scene_closed(_filepath: String) -> void:
	call_deferred("_sync_active_scene")


func _on_main_screen_changed(_screen_name: String) -> void:
	call_deferred("_sync_active_scene")


func _sync_active_scene() -> void:
	if _driver_io_dock != null and Engine.is_editor_hint():
		_driver_io_dock.set_scene_root(EditorInterface.get_edited_scene_root())


func _on_spatial_driver_btn_pressed() -> void:
	if _driver_editor_dock != null:
		if _driver_editor_dock.has_method("make_visible"):
			_driver_editor_dock.make_visible()
		else:
			_driver_editor_dock.show()
	if _driver_io_dock != null:
		if Engine.is_editor_hint():
			_driver_io_dock.set_scene_root(EditorInterface.get_edited_scene_root())
		_driver_io_dock.grab_focus()
