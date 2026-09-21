@tool
class_name Computer
extends Node3D

## Emitted whenever the counter value changes.
signal count_changed(new_count: int)

@export_category("Counter")
## The title displayed at the top of the monitor display.
@export var title: String = "PRODUCTION COUNTER":
	set(value):
		title = value
		_update_display()

## Current count value.
@export var count: int = 0:
	set(value):
		count = value
		_update_display()
		count_changed.emit(count)
		if enable_comms and _count_tag.is_ready():
			_count_tag.write_int16(count)

## Increment step added to the counter on each trigger.
@export var step: int = 1

## Automatically reset counter to 0 when simulation starts.
@export var auto_reset_on_start: bool = false

@export_category("Legs")
## Height of the console desk from the floor in meters.
## When auto_floor_detection is true, this is automatically adjusted based on position.
@export_range(0.2, 5.0, 0.05, "suffix:m") var height: float = 0.9:
	set(value):
		if is_equal_approx(height, value):
			return
		height = value
		_request_legs_refresh()

## Automatically extend the legs down to touch the ground or floor collider.
@export var auto_floor_detection: bool = true:
	set(value):
		if auto_floor_detection == value:
			return
		auto_floor_detection = value
		_request_legs_refresh()

## Use a single central pedestal column (true) or dual posts with cross-bracing (false).
@export var single_post: bool = true:
	set(value):
		if single_post == value:
			return
		single_post = value
		_request_legs_refresh()

## Enable top clamps on the leg posts.
@export var clamp_enabled: bool = false:
	set(value):
		if clamp_enabled == value:
			return
		clamp_enabled = value
		_request_legs_refresh()

## Reference width used for leg sizing (meters).
@export_range(0.2, 2.0, 0.05, "suffix:m") var leg_width: float = 0.5:
	set(value):
		if is_equal_approx(leg_width, value):
			return
		leg_width = value
		_request_legs_refresh()

## Fallback ground plane in world space (default at Y=0).
@export var floor_plane: Plane = Plane(Vector3.UP, 0.0):
	set(value):
		if value == floor_plane:
			return
		floor_plane = value
		_request_legs_refresh()

@export_category("Communications")
## Enable communication with external PLC / control systems.
@export var enable_comms: bool = false

@export var trigger_tag_group_name: String
## The tag group for reading the trigger signal (e.g. sensor or coil).
@export_custom(0, "tag_group_enum") var trigger_tag_groups: String:
	get:
		return trigger_tag_group_name
	set(value):
		trigger_tag_group_name = value

## The tag name for detecting count trigger pulses (rising edge 0 -> 1).
## Modbus: co* or di* (e.g. co3) | OPC UA: NodeId.
@export var trigger_tag_name: String = ""

@export var count_tag_group_name: String
## The tag group for writing the current count value.
@export_custom(0, "tag_group_enum") var count_tag_groups: String:
	get:
		return count_tag_group_name
	set(value):
		count_tag_group_name = value

## The tag name for publishing count value to PLC holding registers.
## Modbus: hr* (e.g. hr0) | OPC UA: NodeId.
@export var count_tag_name: String = ""

# Internal tags & state
var _trigger_tag: OIPCommsTag = OIPCommsTag.new()
var _count_tag: OIPCommsTag = OIPCommsTag.new()
var _last_trigger_tag_val: bool = false
var _legs_refresh_pending: bool = false
var _current_leg_height: float = -1.0
var _led_tween: Tween

# Node references
var _leg: StraightLeg
var _header_label: Label3D
var _count_label: Label3D
var _status_label: Label3D
var _led_mesh: MeshInstance3D


func _init() -> void:
	set_notify_transform(true)


func _validate_property(property: Dictionary) -> void:
	if not OIPCommsSetup.validate_tag_property(property, "trigger_tag_group_name", "trigger_tag_groups", "trigger_tag_name"):
		OIPCommsSetup.validate_tag_property(property, "count_tag_group_name", "count_tag_groups", "count_tag_name")


func _enter_tree() -> void:
	trigger_tag_group_name = OIPCommsSetup.default_tag_group(trigger_tag_group_name)
	count_tag_group_name = OIPCommsSetup.default_tag_group(count_tag_group_name)
	if not Simulation.started.is_connected(_on_simulation_started):
		Simulation.started.connect(_on_simulation_started)
	OIPCommsSetup.connect_comms(self, _tag_group_initialized, _tag_group_polled)


func _exit_tree() -> void:
	if Simulation.started.is_connected(_on_simulation_started):
		Simulation.started.disconnect(_on_simulation_started)
	OIPCommsSetup.disconnect_comms(self, _tag_group_initialized, _tag_group_polled)


func _ready() -> void:
	_resolve_nodes()
	_update_display()
	_request_legs_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_request_legs_refresh()


func _resolve_nodes() -> void:
	_leg = get_node_or_null("StraightLeg") as StraightLeg
	_header_label = get_node_or_null("Screen/HeaderLabel") as Label3D
	_count_label = get_node_or_null("Screen/CountLabel") as Label3D
	_status_label = get_node_or_null("Screen/StatusLabel") as Label3D
	_led_mesh = get_node_or_null("LedIndicator") as MeshInstance3D


## Increments count by step, flashes the indicator LED, and synchronizes to PLC.
func trigger() -> void:
	count += step
	_flash_led()


## Resets counter to zero.
func reset_count() -> void:
	count = 0
	_flash_led()


## Sets counter to an explicit value.
func set_count(new_count: int) -> void:
	count = new_count


## Called by interaction HUD when player right-clicks or presses E while looking at terminal.
func use() -> void:
	trigger()


## Returns interactive tooltip information for InteractionHUD in English.
func get_interaction_info() -> Dictionary:
	var label_str: String = title
	if label_str.is_empty():
		label_str = String(name)

	var comms_info: String = ""
	if enable_comms:
		if not trigger_tag_name.is_empty():
			comms_info += " | In: %s" % trigger_tag_name
		if not count_tag_name.is_empty():
			comms_info += " | Out: %s" % count_tag_name

	return {
		"name": "Industrial Terminal [%s]" % label_str,
		"description": "Digital production counter workstation linked to PLC signals & sensors.",
		"state": "Count: %d | Step: +%d%s" % [count, step, comms_info],
		"action": "Right Click / Press [E] to Count",
		"accent_color": Color(0.0, 0.9, 0.4)
	}


func _update_display() -> void:
	if _header_label:
		_header_label.text = title
	if _count_label:
		if count >= 0 and count <= 99999:
			_count_label.text = "%05d" % count
		else:
			_count_label.text = str(count)
	if _status_label:
		if enable_comms and _trigger_tag.is_ready():
			_status_label.text = "PLC CONNECTED [%s]" % trigger_tag_name
		elif enable_comms:
			_status_label.text = "COMMS WAITING..."
		else:
			_status_label.text = "ONLINE | STANDBY"


func _flash_led() -> void:
	if _led_mesh == null:
		return

	var mat: StandardMaterial3D = _led_mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		var orig_mat: Material = _led_mesh.mesh.surface_get_material(0) if _led_mesh.mesh else null
		if orig_mat is StandardMaterial3D:
			mat = (orig_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.1, 0.9, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 1.0, 0.35)
		_led_mesh.set_surface_override_material(0, mat)

	if _led_tween and _led_tween.is_valid():
		_led_tween.kill()

	mat.emission_energy_multiplier = 3.5
	_led_tween = create_tween()
	_led_tween.tween_property(mat, "emission_energy_multiplier", 0.4, 0.25)


func _request_legs_refresh() -> void:
	if _legs_refresh_pending or not is_inside_tree():
		return
	_legs_refresh_pending = true
	call_deferred("_apply_legs")


func _apply_legs() -> void:
	_legs_refresh_pending = false
	if not is_inside_tree():
		return
	if _leg == null:
		_leg = get_node_or_null("StraightLeg") as StraightLeg
	if _leg == null:
		return

	var target_h: float = _calculate_leg_height()
	_current_leg_height = target_h

	# Position the leg so its footplate touches the floor and its top meets the bottom of desk (Y=0)
	_leg.position = Vector3(0.0, -target_h, 0.0)
	_leg.scale = Vector3(1.0, target_h, maxf(0.1, leg_width * 0.5))
	_leg.single_post = single_post
	_leg.clamp_enabled = clamp_enabled


func _calculate_leg_height() -> float:
	if not auto_floor_detection:
		return maxf(0.1, height)

	var desk_world_pos: Vector3 = global_position
	var normal_world: Vector3 = floor_plane.normal.normalized()
	var detected_foot_world: Variant = null

	# Attempt physics raycast downward to detect actual floor colliders if available
	var world := get_world_3d()
	if world != null and world.direct_space_state != null:
		var exclude_rids: Array[RID] = []
		_collect_collision_rids(self, exclude_rids)
		var query := PhysicsRayQueryParameters3D.new()
		query.from = desk_world_pos
		query.to = desk_world_pos - normal_world * 100.0
		query.exclude = exclude_rids
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			detected_foot_world = hit.position

	# Fall back to floor_plane intersection if raycast didn't hit
	if detected_foot_world == null:
		detected_foot_world = floor_plane.intersects_ray(desk_world_pos, -normal_world)
		if detected_foot_world == null:
			detected_foot_world = floor_plane.intersects_ray(desk_world_pos, normal_world)

	if detected_foot_world != null:
		var foot_w: Vector3 = detected_foot_world as Vector3
		var dist: float = (desk_world_pos - foot_w).dot(normal_world)
		if dist > 0.05:
			return dist

	return maxf(0.1, height)


static func _collect_collision_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child: Node in node.get_children(true):
		_collect_collision_rids(child, out)


func _on_simulation_started() -> void:
	if auto_reset_on_start:
		count = 0
	if enable_comms:
		if not trigger_tag_name.is_empty():
			_trigger_tag.register(trigger_tag_group_name, trigger_tag_name, OIPComms.TAG_TYPE_BOOL)
		if not count_tag_name.is_empty():
			_count_tag.register(count_tag_group_name, count_tag_name, OIPComms.TAG_TYPE_INT16)


func _tag_group_initialized(tag_group_name_param: String) -> void:
	_trigger_tag.on_group_initialized(tag_group_name_param)
	if _count_tag.on_group_initialized(tag_group_name_param):
		_count_tag.write_int16(count)
	_update_display()


func _tag_group_polled(tag_group_name_param: String) -> void:
	if not enable_comms:
		return

	if _trigger_tag.matches_group(tag_group_name_param) and _trigger_tag.is_ready():
		var current_val: bool = _trigger_tag.read_bit()
		# Rising edge trigger detection (0 -> 1)
		if current_val and not _last_trigger_tag_val:
			trigger()
		_last_trigger_tag_val = current_val
