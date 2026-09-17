class_name EditorCamera3D
extends Camera3D

## Godot 3D Editor-style runtime camera.
## Features:
## - Right Mouse Button (RMB) held: Free-fly look + WASD / QE movement.
##   Shift = 2.5x speed, Ctrl/Alt = 0.3x speed. Mouse wheel while RMB held = adjust fly speed.
## - Middle Mouse Button (MMB) held: Orbit around pivot point.
## - Shift + Middle Mouse Button (MMB) held: Pan along local camera axes.
## - Scroll Wheel (without RMB): Zoom in / out toward pivot.
## - Mouse cursor: Visible and free by default; captured while dragging RMB or MMB.
## - Clean view: 100% no UI overlay.

const CONFIG_PATH: String = "res://oip_data/editor_camera.cfg"
const PITCH_LIMIT: float = 1.55334 # deg_to_rad(89.0)

@export var fly_speed: float = 12.0
@export var fly_fast_mult: float = 2.5
@export var fly_slow_mult: float = 0.3
@export var mouse_sensitivity: float = 0.003
@export var orbit_sensitivity: float = 0.005
@export var default_orbit_distance: float = 12.0

var orbit_distance: float = 12.0
var orbit_pivot: Vector3 = Vector3.ZERO

var _yaw: float = 0.0
var _pitch: float = 0.0
var _is_rmb_down: bool = false
var _is_mmb_down: bool = false
var _is_active: bool = true
var _move_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	load_editor_camera_transform()
	_update_angles_from_basis()
	_recalculate_orbit_pivot()
	current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func activate() -> void:
	_is_active = true
	current = true
	_is_rmb_down = false
	_is_mmb_down = false
	_move_velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func deactivate() -> void:
	_is_active = false
	_is_rmb_down = false
	_is_mmb_down = false
	_move_velocity = Vector3.ZERO


func is_active() -> bool:
	return _is_active


func sync_from_camera(source_cam: Camera3D) -> void:
	if source_cam == null:
		return
	global_transform = source_cam.global_transform
	fov = source_cam.fov
	_update_angles_from_basis()
	_recalculate_orbit_pivot()


func load_editor_camera_transform() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(CONFIG_PATH)
	if err == OK and cfg.has_section_key("camera", "transform"):
		var t_val: Variant = cfg.get_value("camera", "transform")
		if t_val is Transform3D:
			global_transform = t_val as Transform3D
		if cfg.has_section_key("camera", "fov"):
			fov = cfg.get_value("camera", "fov") as float
	else:
		# Fallback: overview of building center
		global_position = Vector3(0.0, 12.0, 20.0)
		look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _update_angles_from_basis() -> void:
	var euler: Vector3 = global_transform.basis.get_euler(EULER_ORDER_YXZ)
	_pitch = clamp(euler.x, -PITCH_LIMIT, PITCH_LIMIT)
	_yaw = euler.y


func _recalculate_orbit_pivot() -> void:
	orbit_distance = default_orbit_distance
	orbit_pivot = global_position - global_transform.basis.z * orbit_distance


func _input(event: InputEvent) -> void:
	if not _is_active or Engine.is_editor_hint():
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_is_rmb_down = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_is_rmb_down = false
				if not _is_mmb_down:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_is_mmb_down = true
				_recalculate_orbit_pivot()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_is_mmb_down = false
				if not _is_rmb_down:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _is_rmb_down:
				fly_speed = clamp(fly_speed * 1.15, 1.0, 150.0)
			else:
				orbit_distance = max(0.5, orbit_distance * 0.85)
				global_position = orbit_pivot + global_transform.basis.z * orbit_distance

		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _is_rmb_down:
				fly_speed = clamp(fly_speed / 1.15, 1.0, 150.0)
			else:
				orbit_distance = min(1500.0, orbit_distance * 1.15)
				global_position = orbit_pivot + global_transform.basis.z * orbit_distance

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_rmb_down:
			# Free fly look
			_yaw -= mm.relative.x * mouse_sensitivity
			_pitch -= mm.relative.y * mouse_sensitivity
			_pitch = clamp(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
			global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
			orbit_pivot = global_position - global_transform.basis.z * orbit_distance

		elif _is_mmb_down:
			if Input.is_key_pressed(KEY_SHIFT):
				# Pan
				var pan_factor: float = max(1.0, orbit_distance) * 0.0012
				var pan_vec: Vector3 = (-global_transform.basis.x * mm.relative.x + global_transform.basis.y * mm.relative.y) * pan_factor
				global_position += pan_vec
				orbit_pivot += pan_vec
			else:
				# Orbit
				_yaw -= mm.relative.x * orbit_sensitivity
				_pitch -= mm.relative.y * orbit_sensitivity
				_pitch = clamp(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
				var rot_basis: Basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
				global_transform.basis = rot_basis
				global_position = orbit_pivot + rot_basis.z * orbit_distance


func _process(delta: float) -> void:
	if not _is_active or Engine.is_editor_hint():
		return

	if _is_rmb_down:
		var move_dir: Vector3 = Vector3.ZERO

		# Forward / backward along look direction
		if Input.is_key_pressed(KEY_W):
			move_dir -= global_transform.basis.z
		if Input.is_key_pressed(KEY_S):
			move_dir += global_transform.basis.z

		# Strafe left / right
		if Input.is_key_pressed(KEY_A):
			move_dir -= global_transform.basis.x
		if Input.is_key_pressed(KEY_D):
			move_dir += global_transform.basis.x

		# Fly up / down (E = Up, Q = Down)
		if Input.is_key_pressed(KEY_E):
			move_dir += Vector3.UP
		if Input.is_key_pressed(KEY_Q):
			move_dir -= Vector3.UP

		if move_dir.length_squared() > 1.0:
			move_dir = move_dir.normalized()

		var speed_mult: float = 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed_mult = fly_fast_mult
		elif Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
			speed_mult = fly_slow_mult

		var target_vel: Vector3 = move_dir * (fly_speed * speed_mult)
		_move_velocity = _move_velocity.lerp(target_vel, 14.0 * delta)
		global_position += _move_velocity * delta
		orbit_pivot = global_position - global_transform.basis.z * orbit_distance
	else:
		if _move_velocity.length_squared() > 0.001:
			_move_velocity = _move_velocity.lerp(Vector3.ZERO, 16.0 * delta)
			global_position += _move_velocity * delta
			orbit_pivot = global_position - global_transform.basis.z * orbit_distance
