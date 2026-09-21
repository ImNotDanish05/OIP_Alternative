extends CanvasLayer
class_name InteractionHUD

## Runtime 2D Tooltip & Interaction HUD.
## - Projects 3D world coordinates to screen-space 2D tooltip.
## - Displays part name, description, current state/condition, and click guide.
## - Handles Right-Click (RMB) / E key to operate the interactable part (`use()`).

var _current_target: Node = null
var _last_hit_position: Vector3 = Vector3.ZERO
var _is_player_mode: bool = false
var _player_body: CharacterBody3D = null

# UI Nodes
var _crosshair: Control = null
var _tooltip_panel: PanelContainer = null
var _accent_bar: ColorRect = null
var _title_label: Label = null
var _desc_label: Label = null
var _state_label: Label = null
var _action_label: Label = null


func _ready() -> void:
	layer = 99
	_build_ui()
	_set_tooltip_visible(false)


func set_player_mode(is_player: bool, player_node: Node = null) -> void:
	_is_player_mode = is_player
	if player_node is CharacterBody3D:
		_player_body = player_node as CharacterBody3D
	elif player_node is Node:
		var cb: CharacterBody3D = player_node.find_child("AMSGCapsuleController", true, false) as CharacterBody3D
		if cb:
			_player_body = cb
		else:
			for c: Node in player_node.get_children():
				if c is CharacterBody3D:
					_player_body = c as CharacterBody3D
					break

	if _crosshair:
		_crosshair.visible = _is_player_mode
		_crosshair.queue_redraw()


func _process(_delta: float) -> void:
	if _current_target != null and is_instance_valid(_current_target):
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			_update_tooltip_position(camera, _last_hit_position)


func _physics_process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_clear_target()
		return

	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	if space == null:
		_clear_target()
		return

	var ray_origin: Vector3 = Vector3.ZERO
	var ray_target: Vector3 = Vector3.ZERO
	var reach_distance: float = 3.5 if _is_player_mode else 50.0

	if _is_player_mode:
		# Player mode: center of camera forward
		ray_origin = camera.global_position
		ray_target = ray_origin - camera.global_transform.basis.z * reach_distance
	else:
		# Free editor camera mode: from mouse cursor position
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		ray_origin = camera.project_ray_origin(mouse_pos)
		ray_target = ray_origin + camera.project_ray_normal(mouse_pos) * reach_distance

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _player_body:
		query.exclude = [_player_body.get_rid()]

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		_clear_target()
		return

	var collider: Object = hit["collider"]
	var interactable: Node = _resolve_interactable(collider)

	if interactable != null and interactable.has_method("use"):
		_current_target = interactable
		_last_hit_position = hit["position"] as Vector3
		_update_tooltip_content(_current_target)
		_update_tooltip_position(camera, _last_hit_position)
		if _crosshair:
			_crosshair.queue_redraw()
	else:
		_clear_target()


func _input(event: InputEvent) -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return

	var should_interact: bool = false

	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			should_interact = true
		elif mb.button_index == MOUSE_BUTTON_LEFT and not _is_player_mode:
			# In free editor camera mode, left-click can also click 3D buttons
			should_interact = true

	elif event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event as InputEventKey
		if k.keycode == KEY_E:
			should_interact = true

	if should_interact:
		if _current_target.has_method("use"):
			_current_target.call("use")
			# Immediate visual feedback on tooltip
			_update_tooltip_content(_current_target)
			get_viewport().set_input_as_handled()


func _resolve_interactable(collider: Object) -> Node:
	var node: Node = collider as Node
	var scene_root: Node = get_tree().current_scene
	var tree_root: Node = get_tree().root

	while node and node != scene_root and node != tree_root:
		if node.has_method("use"):
			return node
		node = node.get_parent()

	return null


func _clear_target() -> void:
	var had_target: bool = (_current_target != null)
	_current_target = null
	_set_tooltip_visible(false)
	if had_target and _crosshair:
		_crosshair.queue_redraw()


func _set_tooltip_visible(is_vis: bool) -> void:
	if _tooltip_panel:
		_tooltip_panel.visible = is_vis


func _update_tooltip_position(camera: Camera3D, target_3d_pos: Vector3) -> void:
	if _tooltip_panel == null:
		return

	if camera.is_position_behind(target_3d_pos):
		_tooltip_panel.visible = false
		return

	_tooltip_panel.visible = true
	var screen_pos: Vector2 = camera.unproject_position(target_3d_pos)
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var min_size: Vector2 = _tooltip_panel.get_combined_minimum_size()
	var panel_size: Vector2 = Vector2(maxf(_tooltip_panel.size.x, min_size.x), maxf(_tooltip_panel.size.y, min_size.y))

	# Offset slightly to the top-right of the object/hit point
	var desired_pos: Vector2 = screen_pos + Vector2(24.0, -panel_size.y * 0.5)

	# Clamp to keep inside screen viewport margins
	desired_pos.x = clampf(desired_pos.x, 12.0, vp_rect.size.x - panel_size.x - 12.0)
	desired_pos.y = clampf(desired_pos.y, 12.0, vp_rect.size.y - panel_size.y - 12.0)

	_tooltip_panel.position = desired_pos


func _update_tooltip_content(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	var info: Dictionary = {}
	if target.has_method("get_interaction_info"):
		info = target.call("get_interaction_info") as Dictionary
	else:
		info = _get_default_interaction_info(target)

	var p_name: String = info.get("name", String(target.name)) as String
	var p_desc: String = info.get("description", "Interactive industrial simulation component.") as String
	var p_state: String = info.get("state", "State: STANDBY") as String
	var p_action: String = info.get("action", "Right Click to Use") as String

	if not _is_player_mode and target.has_method("use"):
		p_action = "Right Click / Left Click to Press"

	if _title_label:
		_title_label.text = p_name
	if _desc_label:
		_desc_label.text = p_desc
	if _state_label:
		_state_label.text = p_state
	if _action_label:
		_action_label.text = "👉 [%s]" % p_action

	# Update accent bar color depending on object state
	if _accent_bar:
		if info.has("accent_color") and info["accent_color"] is Color:
			_accent_bar.color = info["accent_color"] as Color
		elif target is PushButton:
			var pb: PushButton = target as PushButton
			_accent_bar.color = pb.button_color if pb.pressed else Color(0.2, 0.6, 1.0)
		else:
			_accent_bar.color = Color(0.2, 0.6, 1.0)


func _get_default_interaction_info(target: Node) -> Dictionary:
	var t_name: String = String(target.name)
	var t_desc: String = "Interactive industrial simulation component."
	var t_state: String = "State: STANDBY"
	var t_action: String = "Right Click to Operate"

	if target.is_class("BladeStop") or (target.get_script() != null and "blade_stop" in (target.get_script() as Script).resource_path):
		t_name = "Blade Stop [%s]" % String(target.name)
		t_desc = "Pneumatic stopper to hold boxes/pallets on conveyor."
		var is_active: bool = bool(target.get("active"))
		t_state = "State: %s" % ("RAISED (UP/HOLD)" if is_active else "LOWERED (DOWN/PASS)")
		t_action = "Right Click to Toggle Position"

	elif target.is_class("Diverter") or (target.get_script() != null and "diverter" in (target.get_script() as Script).resource_path):
		t_name = "Conveyor Diverter [%s]" % String(target.name)
		t_desc = "Mechanical divert arm to route boxes to another conveyor lane."
		var is_diverted: bool = bool(target.get("_diverted"))
		t_state = "State: %s" % ("DIVERTING (OPEN)" if is_diverted else "STANDBY (STRAIGHT)")
		t_action = "Right Click to Divert Lane"

	elif target.is_class("SafetyGate") or (target.get_script() != null and "safety_gate" in (target.get_script() as Script).resource_path):
		t_name = "Safety Gate [%s]" % String(target.name)
		t_desc = "Automated operational area safety gate."
		var is_open: bool = bool(target.get("is_open"))
		t_state = "State: %s" % ("OPEN" if is_open else "CLOSED")
		t_action = "Right Click to Open/Close Gate"

	elif target.is_class("BoxSpawner") or (target.get_script() != null and "box_spawner" in (target.get_script() as Script).resource_path):
		t_name = "Box Spawner [%s]" % String(target.name)
		t_desc = "Automated material handling box feeder unit."
		t_state = "State: READY TO SPAWN"
		t_action = "Right Click to Spawn Box Manually"

	elif target.is_class("PalletSpawner") or (target.get_script() != null and "pallet_spawner" in (target.get_script() as Script).resource_path):
		t_name = "Pallet Spawner [%s]" % String(target.name)
		t_desc = "Wooden pallet feeder unit."
		t_state = "State: READY TO SPAWN"
		t_action = "Right Click to Spawn Pallet Manually"

	return {
		"name": t_name,
		"description": t_desc,
		"state": t_state,
		"action": t_action
	}


func _build_ui() -> void:
	# 1. Reticle Crosshair for Player Mode
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.draw.connect(_on_crosshair_draw)
	add_child(_crosshair)

	# 2. 2D Tooltip Floating Box
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "InteractionTooltip"
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.custom_minimum_size = Vector2(250, 90)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.11, 0.90)
	style.border_color = Color(0.22, 0.55, 0.95, 0.80)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 5)
	_tooltip_panel.add_child(vbox)

	# Header Row (Accent Bar + Title)
	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	_accent_bar = ColorRect.new()
	_accent_bar.custom_minimum_size = Vector2(4, 16)
	_accent_bar.color = Color(0.2, 0.6, 1.0)
	header_hbox.add_child(_accent_bar)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_title_label.text = "Push Button"
	header_hbox.add_child(_title_label)

	# Description
	_desc_label = Label.new()
	_desc_label.name = "DescLabel"
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.86))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(250, 0)
	_desc_label.text = "Component description..."
	vbox.add_child(_desc_label)

	# Divider line
	var sep: HSeparator = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# State / Condition
	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.add_theme_font_size_override("font_size", 12)
	_state_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.65))
	_state_label.text = "State: STANDBY"
	vbox.add_child(_state_label)

	# Action Instruction
	_action_label = Label.new()
	_action_label.name = "ActionLabel"
	_action_label.add_theme_font_size_override("font_size", 12)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_action_label.text = "👉 [ Right Click ] Press Button"
	vbox.add_child(_action_label)

	add_child(_tooltip_panel)


func _on_crosshair_draw() -> void:
	if not _is_player_mode or _crosshair == null:
		return

	var center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var is_focused: bool = (_current_target != null)

	if is_focused:
		# Focused on interactable: larger bright green/amber reticle
		var ring_color: Color = Color(0.2, 1.0, 0.5, 0.95)
		_crosshair.draw_arc(center, 6.0, 0.0, TAU, 16, ring_color, 1.5)
		_crosshair.draw_circle(center, 2.0, ring_color)
	else:
		# Standby: subtle clean white dot
		var dot_color: Color = Color(1.0, 1.0, 1.0, 0.65)
		_crosshair.draw_circle(center, 2.0, dot_color)

