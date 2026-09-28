@tool
class_name DriverIODock
extends VBoxContainer

const TAG_GROUPS_FILE := "res://oip_data/tag_groups.cfg"

# Currently tracked scene root
var _scene_root: Node = null
var _inputs: Array[Dictionary] = []
var _outputs: Array[Dictionary] = []
var _filter_text: String = ""

# UI References
var _scene_label: Label
var _inputs_badge: Button
var _outputs_badge: Button
var _driver_select: OptionButton
var _apply_driver_btn: Button
var _enable_all_btn: Button
var _auto_map_btn: Button
var _refresh_btn: Button
var _search_edit: LineEdit
var _status_label: Label

var _inputs_container: VBoxContainer
var _outputs_container: VBoxContainer
var _empty_label: Label
var _split_container: HSplitContainer


func _init() -> void:
	name = "Driver I/O"
	custom_minimum_size = Vector2(0, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()


func _ready() -> void:
	_refresh_known_tag_groups()
	if Engine.is_editor_hint():
		if _scene_root == null:
			set_scene_root(EditorInterface.get_edited_scene_root())


func set_scene_root(root: Node) -> void:
	if _scene_root != null and is_instance_valid(_scene_root):
		if _scene_root.tree_changed.is_connected(_on_scene_tree_changed):
			_scene_root.tree_changed.disconnect(_on_scene_tree_changed)

	_scene_root = root

	if _scene_root != null and is_instance_valid(_scene_root):
		if not _scene_root.tree_changed.is_connected(_on_scene_tree_changed):
			_scene_root.tree_changed.connect(_on_scene_tree_changed)

	_rescan_scene()


func _on_scene_tree_changed() -> void:
	call_deferred("_rescan_scene")


func _build_ui() -> void:
	# 1. Main Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	# Active Scene Label
	var scene_icon := Label.new()
	scene_icon.text = "📁 Scene:"
	toolbar.add_child(scene_icon)

	_scene_label = Label.new()
	_scene_label.text = "[No Active Scene]"
	_scene_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	toolbar.add_child(_scene_label)

	# I/O Count Badges
	_inputs_badge = Button.new()
	_inputs_badge.text = "📥 0 Inputs"
	_inputs_badge.flat = true
	_inputs_badge.focus_mode = Control.FOCUS_NONE
	toolbar.add_child(_inputs_badge)

	_outputs_badge = Button.new()
	_outputs_badge.text = "📤 0 Outputs"
	_outputs_badge.flat = true
	_outputs_badge.focus_mode = Control.FOCUS_NONE
	toolbar.add_child(_outputs_badge)

	toolbar.add_child(VSeparator.new())

	# Default Driver selector
	var driver_title := Label.new()
	driver_title.text = "Driver:"
	toolbar.add_child(driver_title)

	_driver_select = OptionButton.new()
	_driver_select.custom_minimum_size = Vector2(110, 0)
	_driver_select.tooltip_text = "Select default communication driver / tag group"
	toolbar.add_child(_driver_select)

	_apply_driver_btn = Button.new()
	_apply_driver_btn.text = "Apply to All"
	_apply_driver_btn.tooltip_text = "Assign the selected driver tag group to all I/O nodes in this scene"
	_apply_driver_btn.pressed.connect(_on_apply_driver_to_all)
	toolbar.add_child(_apply_driver_btn)

	toolbar.add_child(VSeparator.new())

	# Enable All Comms
	_enable_all_btn = Button.new()
	_enable_all_btn.text = "Enable All"
	_enable_all_btn.tooltip_text = "Enable communications (enable_comms = true) on all I/O nodes in this scene"
	_enable_all_btn.pressed.connect(_on_enable_all_comms)
	toolbar.add_child(_enable_all_btn)

	# Auto-Map Modbus
	_auto_map_btn = Button.new()
	_auto_map_btn.text = "Auto-Map (Modbus)"
	_auto_map_btn.tooltip_text = "Automatically assign sequential Modbus coils (Inputs: co1..N, Outputs: co0, co4..N)"
	_auto_map_btn.pressed.connect(_on_auto_map_modbus)
	toolbar.add_child(_auto_map_btn)

	# Refresh Button
	_refresh_btn = Button.new()
	_refresh_btn.text = "Refresh"
	_refresh_btn.tooltip_text = "Rescan active scene for I/O variables"
	_refresh_btn.pressed.connect(_rescan_scene)
	toolbar.add_child(_refresh_btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	# Search / Filter LineEdit
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Filter nodes / tags..."
	_search_edit.custom_minimum_size = Vector2(170, 0)
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_text_changed)
	toolbar.add_child(_search_edit)

	add_child(HSeparator.new())

	# 2. Main Content Split View (Inputs left, Outputs right)
	_split_container = HSplitContainer.new()
	_split_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split_container.split_offset = 0
	add_child(_split_container)

	# Empty Scene Placeholder
	_empty_label = Label.new()
	_empty_label.text = "No simulation scene currently open.\nOpen a scene (.tscn) in the editor to configure its Input and Output driver variables."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.visible = false
	add_child(_empty_label)

	# Left Column: INPUTS
	var left_panel := _create_column_panel("📥 INPUTS (Plant ➔ Driver / PLC)", Color(0.2, 0.7, 0.4))
	_inputs_container = left_panel.get_node("ScrollContainer/Rows") as VBoxContainer
	_split_container.add_child(left_panel)

	# Right Column: OUTPUTS
	var right_panel := _create_column_panel("📤 OUTPUTS (Driver / PLC ➔ Plant)", Color(0.9, 0.6, 0.2))
	_outputs_container = right_panel.get_node("ScrollContainer/Rows") as VBoxContainer
	_split_container.add_child(right_panel)

	add_child(HSeparator.new())

	# 3. Footer Bar
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(footer)

	_status_label = Label.new()
	_status_label.text = "Ready."
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	footer.add_child(_status_label)


func _create_column_panel(title_text: String, header_color: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(300, 100)

	# Header bar
	var header_panel := PanelContainer.new()
	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 6)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_color_override("font_color", header_color)
	header_box.add_child(title_lbl)

	header_panel.add_child(header_box)
	col.add_child(header_panel)

	# Column table header labels
	var cols_header := HBoxContainer.new()
	cols_header.add_theme_constant_override("separation", 6)

	var lbl_node := Label.new()
	lbl_node.text = "Node"
	lbl_node.custom_minimum_size = Vector2(130, 0)
	lbl_node.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cols_header.add_child(lbl_node)

	var lbl_role := Label.new()
	lbl_role.text = "Channel / Role"
	lbl_role.custom_minimum_size = Vector2(90, 0)
	lbl_role.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cols_header.add_child(lbl_role)

	var lbl_group := Label.new()
	lbl_group.text = "Tag Group"
	lbl_group.custom_minimum_size = Vector2(100, 0)
	lbl_group.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cols_header.add_child(lbl_group)

	var lbl_tag := Label.new()
	lbl_tag.text = "Tag / Variable"
	lbl_tag.custom_minimum_size = Vector2(90, 0)
	lbl_tag.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cols_header.add_child(lbl_tag)

	var lbl_type := Label.new()
	lbl_type.text = "Type"
	lbl_type.custom_minimum_size = Vector2(55, 0)
	lbl_type.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cols_header.add_child(lbl_type)

	var lbl_comms := Label.new()
	lbl_comms.text = "Comms"
	lbl_comms.custom_minimum_size = Vector2(50, 0)
	lbl_comms.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cols_header.add_child(lbl_comms)

	col.add_child(cols_header)
	col.add_child(HSeparator.new())

	# Scroll Container for rows
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 100)

	var rows_box := VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 4)
	scroll.add_child(rows_box)

	col.add_child(scroll)
	return col


# ==========================================
# SCENE SCANNING & POPULATION
# ==========================================

func _rescan_scene() -> void:
	_refresh_known_tag_groups()

	if _scene_root == null or not is_instance_valid(_scene_root):
		if Engine.is_editor_hint():
			_scene_root = EditorInterface.get_edited_scene_root()

	if _scene_root == null or not is_instance_valid(_scene_root):
		_scene_label.text = "[No Active Scene]"
		_split_container.visible = false
		_empty_label.visible = true
		_inputs.clear()
		_outputs.clear()
		_update_badges()
		_status_label.text = "No open scene."
		return

	_split_container.visible = true
	_empty_label.visible = false

	# Scene file name
	var scene_path: String = _scene_root.scene_file_path
	if scene_path.is_empty():
		_scene_label.text = _scene_root.name + " (unsaved)"
	else:
		_scene_label.text = scene_path.get_file()

	_inputs.clear()
	_outputs.clear()

	_scan_recursive(_scene_root)
	_render_tables()
	_update_badges()

	_status_label.text = "Found %d Inputs and %d Outputs in '%s'." % [_inputs.size(), _outputs.size(), _scene_label.text]


func _scan_recursive(current_node: Node) -> void:
	if current_node == null:
		return

	_inspect_node_io(current_node)

	for child: Node in current_node.get_children():
		_scan_recursive(child)


func _inspect_node_io(target_node: Node) -> void:
	var script: Variant = target_node.get_script()
	var script_path: String = ""
	if script is Script:
		script_path = (script as Script).resource_path.to_lower()
	var node_name: String = target_node.name

	# 1. PushButton
	if target_node.has_method("press") or "pushbutton_tag_name" in target_node:
		if "pushbutton_tag_name" in target_node:
			_inputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "INPUT",
				"role": "Button Press",
				"data_type": "BOOL",
				"tag_prop": "pushbutton_tag_name",
				"group_prop": "pushbutton_tag_group_name",
				"enum_prop": "pushbutton_tag_groups"
			})
		if "lamp_tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Button Lamp",
				"data_type": "BOOL",
				"tag_prop": "lamp_tag_name",
				"group_prop": "lamp_tag_group_name",
				"enum_prop": "lamp_tag_groups"
			})
		return

	# 2. DiffuseSensor / Photoelectric
	if script_path.contains("diffuse_sensor") or node_name.to_lower().contains("diffuse"):
		if "tag_name" in target_node:
			_inputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "INPUT",
				"role": "Object Detect",
				"data_type": "BOOL",
				"tag_prop": "tag_name",
				"group_prop": "tag_group_name",
				"enum_prop": "tag_groups"
			})
		return

	# 3. LaserSensor (Distance)
	if script_path.contains("laser_sensor") or node_name.to_lower().contains("laser"):
		if "tag_name" in target_node:
			_inputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "INPUT",
				"role": "Laser Distance",
				"data_type": "FLOAT32",
				"tag_prop": "tag_name",
				"group_prop": "tag_group_name",
				"enum_prop": "tag_groups"
			})
		return

	# 4. ColorSensor
	if script_path.contains("color_sensor") or node_name.to_lower().contains("color"):
		if "tag_name" in target_node:
			_inputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "INPUT",
				"role": "Color ID",
				"data_type": "INT32",
				"tag_prop": "tag_name",
				"group_prop": "tag_group_name",
				"enum_prop": "tag_groups"
			})
		return

	# 5. SafetyGate
	if "gate_tag_name" in target_node:
		_inputs.append({
			"node": target_node,
			"node_name": node_name,
			"direction": "INPUT",
			"role": "Gate Switch",
			"data_type": "BOOL",
			"tag_prop": "gate_tag_name",
			"group_prop": "gate_tag_group_name",
			"enum_prop": "gate_tag_groups"
		})
		return

	# 6. Computer / Counter Terminal
	if "count_tag_name" in target_node or "trigger_tag_name" in target_node:
		if "count_tag_name" in target_node:
			_inputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "INPUT",
				"role": "Count Register",
				"data_type": "INT16",
				"tag_prop": "count_tag_name",
				"group_prop": "count_tag_group_name",
				"enum_prop": "count_tag_groups"
			})
		if "trigger_tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Counter Trigger",
				"data_type": "BOOL",
				"tag_prop": "trigger_tag_name",
				"group_prop": "trigger_tag_group_name",
				"enum_prop": "trigger_tag_groups"
			})
		return

	# 7. Conveyors (Belt, Curved, Roller, Spur)
	if "running_tag_name" in target_node or "speed_tag_name" in target_node:
		if "running_tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Motor Run",
				"data_type": "BOOL",
				"tag_prop": "running_tag_name",
				"group_prop": "running_tag_group_name",
				"enum_prop": "running_tag_groups"
			})
		if "speed_tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Motor Speed",
				"data_type": "FLOAT32",
				"tag_prop": "speed_tag_name",
				"group_prop": "speed_tag_group_name",
				"enum_prop": "speed_tag_groups"
			})
		return

	# 8. Turntable Conveyor
	if "target_angle_tag_name" in target_node:
		_outputs.append({
			"node": target_node,
			"node_name": node_name,
			"direction": "OUTPUT",
			"role": "Target Angle",
			"data_type": "FLOAT32",
			"tag_prop": "target_angle_tag_name",
			"group_prop": "target_angle_tag_group_name",
			"enum_prop": "target_angle_tag_groups"
		})
		if "speed_tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Turn Speed",
				"data_type": "FLOAT32",
				"tag_prop": "speed_tag_name",
				"group_prop": "speed_tag_group_name",
				"enum_prop": "speed_tag_groups"
			})
		return

	# 9. ChainTransfer
	if "popup_tag_name" in target_node:
		_outputs.append({
			"node": target_node,
			"node_name": node_name,
			"direction": "OUTPUT",
			"role": "Pop-up Lift",
			"data_type": "BOOL",
			"tag_prop": "popup_tag_name",
			"group_prop": "popup_tag_group_name",
			"enum_prop": "popup_tag_groups"
		})
		if "speed_tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Chain Speed",
				"data_type": "FLOAT32",
				"tag_prop": "speed_tag_name",
				"group_prop": "speed_tag_group_name",
				"enum_prop": "speed_tag_groups"
			})
		return

	# 10. StackLight
	if script_path.contains("stack_light") or node_name.to_lower().contains("stacklight"):
		if "tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Light Indicator",
				"data_type": "BOOL",
				"tag_prop": "tag_name",
				"group_prop": "tag_group_name",
				"enum_prop": "tag_groups"
			})
		return

	# 11. BladeStop & Diverter
	if script_path.contains("blade_stop") or node_name.to_lower().contains("bladestop"):
		if "tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Blade Raise",
				"data_type": "BOOL",
				"tag_prop": "tag_name",
				"group_prop": "tag_group_name",
				"enum_prop": "tag_groups"
			})
		return

	if script_path.contains("diverter") or node_name.to_lower().contains("diverter"):
		if "tag_name" in target_node:
			_outputs.append({
				"node": target_node,
				"node_name": node_name,
				"direction": "OUTPUT",
				"role": "Diverter Arm",
				"data_type": "BOOL",
				"tag_prop": "tag_name",
				"group_prop": "tag_group_name",
				"enum_prop": "tag_groups"
			})
		return

	# 12. Generic fallback
	if "tag_name" in target_node:
		var is_sensor: bool = node_name.to_lower().contains("sensor") or script_path.contains("sensor")
		var dir_type: String = "INPUT" if is_sensor else "OUTPUT"
		var ch_role: String = "Sensor Detect" if is_sensor else "Actuator"
		var item: Dictionary = {
			"node": target_node,
			"node_name": node_name,
			"direction": dir_type,
			"role": ch_role,
			"data_type": "BOOL",
			"tag_prop": "tag_name",
			"group_prop": "tag_group_name",
			"enum_prop": "tag_groups"
		}
		if is_sensor:
			_inputs.append(item)
		else:
			_outputs.append(item)


# ==========================================
# TABLE RENDERING
# ==========================================

func _render_tables() -> void:
	for child: Node in _inputs_container.get_children():
		child.queue_free()
	for child: Node in _outputs_container.get_children():
		child.queue_free()

	var groups: Array[String] = _get_all_known_groups()

	# Render Inputs
	var in_count: int = 0
	for item: Dictionary in _inputs:
		if _matches_filter(item):
			_create_row(item, _inputs_container, groups)
			in_count += 1

	if in_count == 0:
		var empty_in := Label.new()
		empty_in.text = "No input devices found." if _filter_text.is_empty() else "No inputs matching '%s'." % _filter_text
		empty_in.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_inputs_container.add_child(empty_in)

	# Render Outputs
	var out_count: int = 0
	for item: Dictionary in _outputs:
		if _matches_filter(item):
			_create_row(item, _outputs_container, groups)
			out_count += 1

	if out_count == 0:
		var empty_out := Label.new()
		empty_out.text = "No output devices found." if _filter_text.is_empty() else "No outputs matching '%s'." % _filter_text
		empty_out.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_outputs_container.add_child(empty_out)


func _create_row(item: Dictionary, parent_container: Control, groups: Array[String]) -> void:
	var target_node: Node = item.node as Node
	if target_node == null or not is_instance_valid(target_node):
		return

	var row_panel := PanelContainer.new()
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 6)

	# 1. Node Select Button
	var node_btn := Button.new()
	node_btn.text = item.node_name as String
	node_btn.custom_minimum_size = Vector2(130, 0)
	node_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node_btn.tooltip_text = "Click to focus & select '%s' in 3D viewport" % (item.node_name as String)
	node_btn.pressed.connect(func() -> void:
		_select_node_in_editor(target_node)
	)
	row_box.add_child(node_btn)

	# 2. Role Label
	var role_lbl := Label.new()
	role_lbl.text = item.role as String
	role_lbl.custom_minimum_size = Vector2(90, 0)
	var is_input: bool = (item.direction as String) == "INPUT"
	role_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5) if is_input else Color(1.0, 0.7, 0.3))
	row_box.add_child(role_lbl)

	# 3. Tag Group OptionButton
	var group_opt := OptionButton.new()
	group_opt.custom_minimum_size = Vector2(100, 0)
	group_opt.add_item("(None)")
	for g: String in groups:
		group_opt.add_item(g)

	var cur_group: String = String(target_node.get(item.group_prop as String))
	var selected_idx: int = 0
	for i: int in range(group_opt.item_count):
		if group_opt.get_item_text(i) == cur_group:
			selected_idx = i
			break
	group_opt.select(selected_idx)

	group_opt.item_selected.connect(func(idx: int) -> void:
		var val: String = group_opt.get_item_text(idx)
		if val == "(None)":
			val = ""
		target_node.set(item.group_prop as String, val)
		if (item.enum_prop as String) != "" and (item.enum_prop as String) in target_node:
			target_node.set(item.enum_prop as String, val)
		EditorInterface.mark_scene_as_unsaved()
		_status_label.text = "Updated '%s' tag group to '%s'." % [item.node_name, val]
	)
	row_box.add_child(group_opt)

	# 4. Tag / Variable Name LineEdit
	var tag_edit := LineEdit.new()
	tag_edit.custom_minimum_size = Vector2(90, 0)
	tag_edit.placeholder_text = "co0, di1..."
	tag_edit.text = String(target_node.get(item.tag_prop as String))
	tag_edit.text_changed.connect(func(new_text: String) -> void:
		target_node.set(item.tag_prop as String, new_text.strip_edges())
		EditorInterface.mark_scene_as_unsaved()
		_status_label.text = "Updated '%s' %s to '%s'." % [item.node_name, item.role, new_text.strip_edges()]
	)
	row_box.add_child(tag_edit)

	# 5. Data Type Badge
	var type_lbl := Label.new()
	type_lbl.text = item.data_type as String
	type_lbl.custom_minimum_size = Vector2(55, 0)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	row_box.add_child(type_lbl)

	# 6. Enable Comms CheckBox
	var comms_check := CheckBox.new()
	comms_check.custom_minimum_size = Vector2(50, 0)
	if "enable_comms" in target_node:
		comms_check.button_pressed = bool(target_node.get("enable_comms"))
	else:
		comms_check.button_pressed = true
		comms_check.disabled = true

	comms_check.toggled.connect(func(enabled: bool) -> void:
		if "enable_comms" in target_node:
			target_node.set("enable_comms", enabled)
			EditorInterface.mark_scene_as_unsaved()
			_status_label.text = "Set '%s' enable_comms = %s." % [item.node_name, str(enabled)]
	)
	row_box.add_child(comms_check)

	row_panel.add_child(row_box)
	parent_container.add_child(row_panel)


func _select_node_in_editor(target_node: Node) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(target_node)
	_status_label.text = "Selected '%s' in editor viewport." % target_node.name


func _matches_filter(item: Dictionary) -> bool:
	if _filter_text.is_empty():
		return true
	var query: String = _filter_text.to_lower()
	var n_name: String = (item.node_name as String).to_lower()
	var role: String = (item.role as String).to_lower()
	var target_node: Node = item.node as Node
	var cur_tag: String = ""
	if target_node != null and is_instance_valid(target_node):
		cur_tag = String(target_node.get(item.tag_prop as String)).to_lower()

	return n_name.contains(query) or role.contains(query) or cur_tag.contains(query)


func _on_search_text_changed(new_text: String) -> void:
	_filter_text = new_text.strip_edges()
	_render_tables()


func _update_badges() -> void:
	_inputs_badge.text = "📥 %d Inputs" % _inputs.size()
	_outputs_badge.text = "📤 %d Outputs" % _outputs.size()


# ==========================================
# BULK ACTIONS
# ==========================================

func _on_apply_driver_to_all() -> void:
	var selected_driver: String = _driver_select.get_item_text(_driver_select.selected)
	if selected_driver == "(None)":
		selected_driver = ""

	var count: int = 0
	for item: Dictionary in _inputs:
		var target_node: Node = item.node as Node
		if target_node != null and is_instance_valid(target_node):
			target_node.set(item.group_prop as String, selected_driver)
			if (item.enum_prop as String) != "" and (item.enum_prop as String) in target_node:
				target_node.set(item.enum_prop as String, selected_driver)
			count += 1

	for item: Dictionary in _outputs:
		var target_node: Node = item.node as Node
		if target_node != null and is_instance_valid(target_node):
			target_node.set(item.group_prop as String, selected_driver)
			if (item.enum_prop as String) != "" and (item.enum_prop as String) in target_node:
				target_node.set(item.enum_prop as String, selected_driver)
			count += 1

	EditorInterface.mark_scene_as_unsaved()
	_render_tables()
	_status_label.text = "Applied driver '%s' to all %d I/O variables in scene." % [selected_driver, count]


func _on_enable_all_comms() -> void:
	var count: int = 0
	var visited: Array[Node] = []

	var all_items: Array[Dictionary] = []
	all_items.append_array(_inputs)
	all_items.append_array(_outputs)

	for item: Dictionary in all_items:
		var target_node: Node = item.node as Node
		if target_node != null and is_instance_valid(target_node) and not target_node in visited:
			visited.append(target_node)
			if "enable_comms" in target_node:
				target_node.set("enable_comms", true)
				count += 1

	EditorInterface.mark_scene_as_unsaved()
	_render_tables()
	_status_label.text = "Enabled comms (enable_comms = true) on %d nodes." % count


func _on_auto_map_modbus() -> void:
	var default_driver: String = _driver_select.get_item_text(_driver_select.selected)
	if default_driver == "(None)":
		var groups: Array[String] = _get_all_known_groups()
		if not groups.is_empty():
			default_driver = groups[0]

	var in_coil_idx: int = 1
	var out_coil_idx: int = 0

	for item: Dictionary in _inputs:
		var target_node: Node = item.node as Node
		if target_node == null or not is_instance_valid(target_node):
			continue

		if not default_driver.is_empty():
			target_node.set(item.group_prop as String, default_driver)
			if (item.enum_prop as String) != "" and (item.enum_prop as String) in target_node:
				target_node.set(item.enum_prop as String, default_driver)

		if "enable_comms" in target_node:
			target_node.set("enable_comms", true)

		if (item.data_type as String) == "INT16" or (item.role as String).contains("Count"):
			target_node.set(item.tag_prop as String, "hr0")
		else:
			target_node.set(item.tag_prop as String, "co" + str(in_coil_idx))
			in_coil_idx += 1

	for item: Dictionary in _outputs:
		var target_node: Node = item.node as Node
		if target_node == null or not is_instance_valid(target_node):
			continue

		if not default_driver.is_empty():
			target_node.set(item.group_prop as String, default_driver)
			if (item.enum_prop as String) != "" and (item.enum_prop as String) in target_node:
				target_node.set(item.enum_prop as String, default_driver)

		if "enable_comms" in target_node:
			target_node.set("enable_comms", true)

		if (item.role as String).contains("Motor Run"):
			target_node.set(item.tag_prop as String, "co0")
		elif (item.role as String).contains("Trigger"):
			target_node.set(item.tag_prop as String, "co4")
		elif (item.role as String).contains("Lamp") or (item.role as String).contains("Light"):
			target_node.set(item.tag_prop as String, "co5")
		else:
			target_node.set(item.tag_prop as String, "co" + str(in_coil_idx + out_coil_idx + 3))
			out_coil_idx += 1

	EditorInterface.mark_scene_as_unsaved()
	_render_tables()
	_status_label.text = "Auto-mapped sequential Modbus addresses to all I/O channels."


# ==========================================
# TAG GROUPS RETRIEVAL
# ==========================================

func _refresh_known_tag_groups() -> void:
	var groups: Array[String] = _get_all_known_groups()
	var cur_sel: String = ""
	if _driver_select.item_count > 0:
		cur_sel = _driver_select.get_item_text(_driver_select.selected)

	_driver_select.clear()
	_driver_select.add_item("(None)")
	for g: String in groups:
		_driver_select.add_item(g)

	var sel_idx: int = 0
	if not cur_sel.is_empty():
		for i: int in range(_driver_select.item_count):
			if _driver_select.get_item_text(i) == cur_sel:
				sel_idx = i
				break
	elif _driver_select.item_count > 1:
		sel_idx = 1

	_driver_select.select(sel_idx)


func _get_all_known_groups() -> Array[String]:
	var groups: Array[String] = []

	if Engine.has_singleton("OIPComms"):
		var comms_singleton: Object = Engine.get_singleton("OIPComms")
		if comms_singleton != null and comms_singleton.has_method("get_tag_groups"):
			var comms_groups: Variant = comms_singleton.call("get_tag_groups")
			if comms_groups is Array:
				for g: Variant in (comms_groups as Array):
					var gname: String = ""
					if g is Dictionary:
						gname = str((g as Dictionary).get("name", ""))
					elif g is String:
						var s: String = (g as String).strip_edges()
						if s.begins_with("{"):
							var parsed: Variant = JSON.parse_string(s)
							if parsed is Dictionary and (parsed as Dictionary).has("name"):
								gname = str((parsed as Dictionary).get("name", ""))
						else:
							gname = s
					if not gname.is_empty() and not gname in groups:
						groups.append(gname)

	var cfg := ConfigFile.new()
	if cfg.load(TAG_GROUPS_FILE) == OK:
		var count: int = cfg.get_value("info", "group_count", 0)
		for i: int in range(count):
			var gname: String = cfg.get_value("group_" + str(i), "name", "")
			if not gname.is_empty() and not gname in groups:
				groups.append(gname)

	return groups
