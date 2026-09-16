class_name Player
extends CharacterBody3D

## Runtime capsule player for OIP_Alternative.
## Spawned automatically at runtime if no Camera/Player exists, or placed manually via parts/Player.tscn.
## No model - just capsule mesh + collider. FPS-style WASD + mouse look + jump.

@export_category("Movement")
@export var walk_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var floor_max_angle_degrees: float = 58.0
@export var floor_snap_distance: float = 0.35

var _head: Node3D
var _camera: Camera3D
var _gravity: float = 9.8
var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	_head = get_node_or_null("Head") as Node3D
	_camera = get_node_or_null("Head/Camera3D") as Camera3D
	if _head == null or _camera == null:
		push_warning("Player: missing Head/Camera3D")
		return

	# Use project gravity if available.
	var g_variant: Variant = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if typeof(g_variant) == TYPE_FLOAT or typeof(g_variant) == TYPE_INT:
		_gravity = float(g_variant)
	else:
		_gravity = 9.8

	floor_max_angle = deg_to_rad(floor_max_angle_degrees)
	floor_snap_length = floor_snap_distance
	floor_stop_on_slope = true
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	_ensure_input_map()

	# Make this camera current if no other camera is current.
	if _camera and get_viewport().get_camera_3d() == null:
		_camera.current = true
	else:
		if _camera:
			_camera.current = true

	# Capture mouse when running (not in editor).
	if not Engine.is_editor_hint():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Enable input.
	set_process_input(true)
	set_physics_process(true)


func _ensure_input_map() -> void:
	# Create fallback actions so the player works even if project.godot [input] was not edited.
	# We keep the editor-pilot actions (pilot_move_*) AND common aliases (move_*/forward/back etc).
	_ensure_action_with_keys("pilot_move_forward", [KEY_W] as Array[Key])
	_ensure_action_with_keys("pilot_move_back", [KEY_S] as Array[Key])
	_ensure_action_with_keys("pilot_move_left", [KEY_A] as Array[Key])
	_ensure_action_with_keys("pilot_move_right", [KEY_D] as Array[Key])
	_ensure_action_with_keys("pilot_jump", [KEY_SPACE] as Array[Key])

	# Common FPS aliases (also used if user prefers project.godot inputs)
	_ensure_action_with_keys("move_forward", [KEY_W, KEY_UP] as Array[Key])
	_ensure_action_with_keys("forward", [KEY_W] as Array[Key])
	_ensure_action_with_keys("move_back", [KEY_S, KEY_DOWN] as Array[Key])
	_ensure_action_with_keys("back", [KEY_S] as Array[Key])
	_ensure_action_with_keys("move_left", [KEY_A, KEY_LEFT] as Array[Key])
	_ensure_action_with_keys("left", [KEY_A] as Array[Key])
	_ensure_action_with_keys("move_right", [KEY_D, KEY_RIGHT] as Array[Key])
	_ensure_action_with_keys("right", [KEY_D] as Array[Key])
	_ensure_action_with_keys("jump", [KEY_SPACE] as Array[Key])
	_ensure_action_with_physical_key("sprint", KEY_CTRL)
	_ensure_action_with_keys("pilot_sprint", [KEY_CTRL] as Array[Key])


func _ensure_action_with_keys(action: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key_code: Key in keys:
		var already: bool = false
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev as InputEventKey).keycode == key_code:
				already = true
				break
		if not already:
			var ev_key: InputEventKey = InputEventKey.new()
			ev_key.keycode = key_code
			InputMap.action_add_event(action, ev_key)


func _ensure_action_with_physical_key(action: String, physical: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var already: bool = false
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == physical:
			already = true
			break
	if not already:
		var ev_key: InputEventKey = InputEventKey.new()
		ev_key.physical_keycode = physical
		InputMap.action_add_event(action, ev_key)


func _unhandled_input(event: InputEvent) -> void:
	# ESC toggles mouse capture.
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()
			return
	# Click to recapture.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()
			return
	# Mouse look.
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_yaw -= motion.relative.x * mouse_sensitivity
			_pitch -= motion.relative.y * mouse_sensitivity
			_pitch = clampf(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
			if _head:
				_head.rotation.y = _yaw
				_head.rotation.x = _pitch
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _head == null or _camera == null:
		return

	# Keep head rotation in sync if set via _yaw/_pitch (also needed on first frame).
	_head.rotation.y = _yaw
	_head.rotation.x = _pitch

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var wants_jump: bool = Input.is_action_pressed("pilot_jump") or Input.is_action_pressed("jump")
	if wants_jump and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("pilot_move_forward") or Input.is_action_pressed("move_forward") or Input.is_action_pressed("forward"):
		input_dir.y += 1.0
	if Input.is_action_pressed("pilot_move_back") or Input.is_action_pressed("move_back") or Input.is_action_pressed("back"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("pilot_move_left") or Input.is_action_pressed("move_left") or Input.is_action_pressed("left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("pilot_move_right") or Input.is_action_pressed("move_right") or Input.is_action_pressed("right"):
		input_dir.x += 1.0
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()

	var is_sprinting: bool = Input.is_action_pressed("sprint") or Input.is_action_pressed("pilot_sprint") or Input.is_physical_key_pressed(KEY_CTRL)
	var current_speed: float = sprint_speed if is_sprinting else walk_speed

	var forward: Vector3 = -_head.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = _head.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var direction: Vector3 = (right * input_dir.x + forward * input_dir.y)
	# When both forward/right degenerate (head exactly down), fallback to basis.
	if direction.length_squared() < 0.0001:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)
	else:
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()
