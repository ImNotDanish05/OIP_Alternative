extends Node
class_name AMSGCapsuleController

## Simplified AMSG input controller for capsule - keeps AMSG movement code but no model/skeleton.
## Based on AMSG PlayerController.gd but stripped of networking/lock/pose-warping dependencies.

@export var character_component: CharacterMovementComponent
@export var camera_component: CameraComponent
@export var mouse_sensitivity: float = 0.008

@export var OnePressJump: bool = false
@export var UsingCrouchToggle: bool = false
@export var UsingSprintToggle: bool = false

@export_category("Flight")
@export var fly_speed: float = 5.0
@export var fly_fast_speed: float = 10.0
@export var fly_vertical_speed: float = 5.0

@export_category("Audio & Flashlight")
@export var footstep_player: AudioStreamPlayer3D
@export var flashlight: SpotLight3D
@export var flashlight_audio: AudioStreamPlayer3D
@export var footstep_sounds: Array[AudioStream] = []
@export var light_on_sound: AudioStream
@export var light_off_sound: AudioStream

var _previous_rotation_mode: int = 0
var _direction: Vector3 = Vector3.ZERO
var _view_changed_recently: bool = false
var _camera_cycle_index: int = 0 # start at 0 (First Person)
var _last_jump_press_time: float = -10.0
var _double_tap_threshold: float = 0.35
var _fly_toggle_block_until_release: bool = false
var _step_timer: float = 0.0
var _was_on_floor: bool = true
var _last_footstep_index: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process_input(true)
	# Fallback resolve if exports failed (strict typing / load order)
	if character_component == null:
		character_component = get_node_or_null("../CharacterMovementComponent") as CharacterMovementComponent
	if camera_component == null:
		camera_component = get_node_or_null("../CameraComponent") as CameraComponent
	if footstep_player == null:
		footstep_player = get_node_or_null("../FootstepAudio") as AudioStreamPlayer3D
	if flashlight == null:
		flashlight = get_node_or_null("../SpringArm3D/Camera/Flashlight") as SpotLight3D
	if flashlight_audio == null:
		flashlight_audio = get_node_or_null("../SpringArm3D/Camera/FlashlightAudio") as AudioStreamPlayer3D

	# Preload 10 footstep sounds from addons/AMSG/Character/sfx/footsteps
	if footstep_sounds.is_empty():
		for i: int in range(1, 11):
			var path: String = "res://addons/AMSG/Character/sfx/footsteps/footstep%d.wav" % i
			if ResourceLoader.exists(path):
				var s: AudioStream = load(path) as AudioStream
				if s:
					footstep_sounds.append(s)

	# Preload flashlight sounds from addons/AMSG/Character/sfx/flashlight
	if light_on_sound == null and ResourceLoader.exists("res://addons/AMSG/Character/sfx/flashlight/light_on.wav"):
		light_on_sound = load("res://addons/AMSG/Character/sfx/flashlight/light_on.wav") as AudioStream
	if light_off_sound == null and ResourceLoader.exists("res://addons/AMSG/Character/sfx/flashlight/light_off.wav"):
		light_off_sound = load("res://addons/AMSG/Character/sfx/flashlight/light_off.wav") as AudioStream

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Ensure camera is current and set to First Person initially
	if camera_component:
		if camera_component.Camera:
			camera_component.Camera.current = true
		camera_component.view_mode = Global.view_mode.first_person
		camera_component.view_angle = Global.view_angle.head
	_camera_cycle_index = 0
	_previous_rotation_mode = character_component.rotation_mode if character_component else 0
	print("AMSG Player ready. View: First Person. Footstep sounds loaded: ", footstep_sounds.size(), ", Flashlight: ", (flashlight != null))

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or character_component == null or camera_component == null:
		return

	# Camera yaw
	var h_rotation: float = camera_component.HObject.transform.basis.get_euler().y
	var v_rotation: float = camera_component.VObject.transform.basis.get_euler().x

	# Double-tap Space to toggle fly (press Space twice quickly to fly, double-tap again while flying to stop)
	var _fly_toggled_this_frame: bool = false
	if Input.is_action_just_pressed("jump"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_jump_press_time < _double_tap_threshold and not _fly_toggle_block_until_release:
			character_component.is_flying = not character_component.is_flying
			character_component.vertical_velocity = Vector3.ZERO
			character_component.stance = Global.stance.standing
			if character_component.character_node is CharacterBody3D:
				var body: CharacterBody3D = character_component.character_node as CharacterBody3D
				body.velocity = Vector3.ZERO
				if character_component.is_flying:
					body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
				else:
					body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			if character_component.stair_collision_shape_3d:
				character_component.stair_collision_shape_3d.disabled = character_component.is_flying
			if character_component.is_flying:
				print("Fly ON (WASD speed 5, Ctrl speed 10, Space up, Shift down)")
			else:
				print("Fly OFF")
			_last_jump_press_time = -10.0
			_fly_toggle_block_until_release = true
			_fly_toggled_this_frame = true
		else:
			_last_jump_press_time = now
			_fly_toggle_block_until_release = false
	if Input.is_action_just_released("jump"):
		_fly_toggle_block_until_release = false

	var is_flying: bool = character_component.is_flying
	if is_flying:
		_was_on_floor = false
		_step_timer = 0.0
		character_component.stance = Global.stance.standing
		character_component.vertical_velocity = Vector3.ZERO
		if character_component.character_node is CharacterBody3D:
			var body: CharacterBody3D = character_component.character_node as CharacterBody3D
			if body.motion_mode != CharacterBody3D.MOTION_MODE_FLOATING:
				body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
			if character_component.stair_collision_shape_3d and not character_component.stair_collision_shape_3d.disabled:
				character_component.stair_collision_shape_3d.disabled = true

			# WASD: pure horizontal direction (strictly Y = 0.0)
			var input_x: float = Input.get_action_strength("right") - Input.get_action_strength("left")
			var input_z: float = Input.get_action_strength("back") - Input.get_action_strength("forward")
			var h_input: Vector3 = Vector3(input_x, 0.0, input_z)
			if h_input.length_squared() > 1.0:
				h_input = h_input.normalized()
			var h_dir: Vector3 = h_input.rotated(Vector3.UP, h_rotation)

			# Ctrl (sprint): pure horizontal speed boost (speed 10) - NEVER alters altitude
			var is_fast: bool = Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_CTRL)
			var h_speed: float = fly_fast_speed if is_fast else fly_speed

			# Vertical movement: Space (+up) and Shift (-down). Ctrl NEVER touches this!
			var v_speed: float = 0.0
			if Input.is_action_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE):
				v_speed += fly_vertical_speed
			# Fly down with Shift (crouch key)
			if Input.is_action_pressed("crouch") or Input.is_physical_key_pressed(KEY_SHIFT):
				v_speed -= fly_vertical_speed

			# Absolute safeguard: if Ctrl/sprint is held, downward flight is strictly blocked!
			if is_fast and v_speed < 0.0:
				v_speed = 0.0

			# Assign velocity directly:
			# Y is strictly v_speed (0.0 if neither Space nor Shift is held!)
			body.velocity.x = h_dir.x * h_speed
			body.velocity.z = h_dir.z * h_speed
			body.velocity.y = v_speed
			body.move_and_slide()
	else:
		if character_component.character_node is CharacterBody3D:
			var body: CharacterBody3D = character_component.character_node as CharacterBody3D
			if body.motion_mode != CharacterBody3D.MOTION_MODE_GROUNDED:
				body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			if character_component.stair_collision_shape_3d and character_component.stair_collision_shape_3d.disabled:
				character_component.stair_collision_shape_3d.disabled = false

		# Grounded movement input
		var has_horizontal: bool = Input.is_action_pressed("forward") or Input.is_action_pressed("back") or Input.is_action_pressed("right") or Input.is_action_pressed("left")
		if has_horizontal:
			_direction = Vector3(
				Input.get_action_strength("right") - Input.get_action_strength("left"),
				0.0,
				Input.get_action_strength("back") - Input.get_action_strength("forward")
			).rotated(Vector3.UP, h_rotation).normalized()
			if character_component.gait == Global.gait.sprinting:
				character_component.add_movement_input(_direction, character_component.current_movement_data.sprint_speed, character_component.current_movement_data.sprint_acceleration)
			elif character_component.gait == Global.gait.running:
				character_component.add_movement_input(_direction, character_component.current_movement_data.run_speed, character_component.current_movement_data.run_acceleration)
			else:
				character_component.add_movement_input(_direction, character_component.current_movement_data.walk_speed, character_component.current_movement_data.walk_acceleration)
		else:
			character_component.add_movement_input(Vector3.ZERO, 0.0, character_component.deacceleration)

	# Crouch - disabled when flying (Shift is used for down)
	if not is_flying:
		if UsingCrouchToggle == false:
			if Input.is_action_pressed("crouch"):
				if character_component.stance != Global.stance.crouching:
					character_component.stance = Global.stance.crouching
			else:
				if character_component.stance != Global.stance.standing:
					character_component.stance = Global.stance.standing
		else:
			if Input.is_action_just_pressed("crouch"):
				character_component.stance = Global.stance.standing if character_component.stance == Global.stance.crouching else Global.stance.crouching
	else:
		# Guarantee standing stance while flying so camera and collision NEVER crouch or drop
		if character_component.stance != Global.stance.standing:
			character_component.stance = Global.stance.standing

	# Sprint - disabled when flying (Shift is used for down, Ctrl is 2x speed)
	if not is_flying:
		if UsingSprintToggle:
			if Input.is_action_just_pressed("sprint"):
				if character_component.gait == Global.gait.walking:
					character_component.gait = Global.gait.running
				elif character_component.gait == Global.gait.running:
					character_component.gait = Global.gait.sprinting
				elif character_component.gait == Global.gait.sprinting:
					character_component.gait = Global.gait.walking
		else:
			if Input.is_action_just_pressed("sprint"):
				if character_component.gait == Global.gait.walking:
					character_component.gait = Global.gait.running
				elif character_component.gait == Global.gait.running:
					character_component.gait = Global.gait.sprinting
			if Input.is_action_just_released("sprint"):
				if character_component.gait == Global.gait.sprinting or character_component.gait == Global.gait.walking:
					character_component.gait = Global.gait.walking
				elif character_component.gait == Global.gait.running:
					await get_tree().create_timer(0.4).timeout
					if character_component and character_component.gait == Global.gait.running:
						character_component.gait = Global.gait.walking

	# Aim (right mouse)
	if Input.is_action_pressed("aim"):
		if character_component.rotation_mode != Global.rotation_mode.aiming:
			_previous_rotation_mode = character_component.rotation_mode as int
			character_component.rotation_mode = Global.rotation_mode.aiming
	else:
		if character_component.rotation_mode == Global.rotation_mode.aiming:
			character_component.rotation_mode = _previous_rotation_mode as Global.rotation_mode

	# Jump (skip if we just toggled fly or if flying - Space is for fly up)
	if not _fly_toggled_this_frame and not is_flying:
		var jumped: bool = false
		if OnePressJump:
			if Input.is_action_just_pressed("jump"):
				if character_component.stance != Global.stance.standing:
					character_component.stance = Global.stance.standing
				else:
					character_component.jump()
					jumped = true
		else:
			if Input.is_action_just_pressed("jump"):
				if character_component.stance != Global.stance.standing:
					character_component.stance = Global.stance.standing
				else:
					character_component.jump()
					jumped = true
			elif Input.is_action_pressed("jump"):
				character_component.jump()
		if jumped and _was_on_floor:
			_play_footstep(0.0)

	# Ragdoll (X)
	if Input.is_action_pressed("ragdoll"):
		character_component.ragdoll = true
		if character_component.rotation_mode == Global.rotation_mode.velocity_direction:
			if camera_component and camera_component.view_mode == Global.view_mode.first_person:
				camera_component.view_mode = Global.view_mode.third_person

	# Footsteps update when grounded
	if not is_flying:
		_update_footsteps(delta)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or character_component == null or camera_component == null:
		return

	if event is InputEventMouseMotion:
		camera_component.camera_h += -event.relative.x * mouse_sensitivity
		camera_component.camera_v += -event.relative.y * mouse_sensitivity

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if event.keycode == KEY_1:
			# Debug toggle if available
			pass

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Zoom wheel handled in CameraComponent._input via zoom_scroll_offset (hold C + wheel)

	# Flashlight toggle: L key or "flashlight" action
	var toggle_light: bool = false
	if event.is_action_pressed("flashlight"):
		toggle_light = true
	elif event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_L or k.physical_keycode == KEY_L):
			toggle_light = true

	if toggle_light and flashlight:
		flashlight.visible = not flashlight.visible
		if flashlight_audio:
			var s: AudioStream = light_on_sound if flashlight.visible else light_off_sound
			if s:
				flashlight_audio.stream = s
				flashlight_audio.pitch_scale = randf_range(0.98, 1.02)
				flashlight_audio.play()

	# Camera cycling with F5: first -> third center -> third shoulder -> first
	var f5_pressed: bool = Input.is_action_just_pressed("switch_camera_view")
	# Fallback direct key check (in case action map missed) + V as alternative
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_F5 or k.physical_keycode == KEY_F5 or k.keycode == KEY_V or k.physical_keycode == KEY_V):
			f5_pressed = true
			print("F5/V direct detected, keycode=", k.keycode, " physical=", k.physical_keycode)
	if f5_pressed:
		print("F5 triggered, before cycle=", _camera_cycle_index)
		if _view_changed_recently:
			return
		_view_changed_recently = true
		_camera_cycle_index = (_camera_cycle_index + 1) % 3
		print("F5 camera cycle -> ", _camera_cycle_index)
		match _camera_cycle_index:
			0: # First person
				camera_component.view_mode = Global.view_mode.first_person as Global.view_mode
				camera_component.view_angle = Global.view_angle.head as Global.view_angle
			1: # Third center (head)
				camera_component.view_mode = Global.view_mode.third_person as Global.view_mode
				camera_component.view_angle = Global.view_angle.head as Global.view_angle
				# Reset spring length for third
				if camera_component.SpringArm:
					camera_component.SpringArm.spring_length = 3.5
			2: # Third shoulder (right)
				camera_component.view_mode = Global.view_mode.third_person as Global.view_mode
				camera_component.view_angle = Global.view_angle.right_shoulder as Global.view_angle
				if camera_component.SpringArm:
					camera_component.SpringArm.spring_length = 3.5
		await get_tree().create_timer(0.3).timeout
		_view_changed_recently = false

func _update_footsteps(delta: float) -> void:
	if character_component == null:
		return
	var body: CharacterBody3D = character_component.character_node as CharacterBody3D
	if body == null:
		return

	var is_on_floor: bool = body.is_on_floor() or (character_component.ground_check != null and character_component.ground_check.is_colliding())

	# Landed detection
	if not _was_on_floor and is_on_floor:
		_play_footstep(1.5)
		_step_timer = 0.2
	_was_on_floor = is_on_floor

	if not is_on_floor:
		return

	var h_velocity: Vector2 = Vector2(body.velocity.x, body.velocity.z)
	var h_speed: float = h_velocity.length()

	# Don't step if virtually stationary
	if h_speed < 0.35:
		_step_timer = 0.0
		return

	# Cadence and volume based on stance and gait
	var interval: float = 0.45
	var volume_offset: float = -5.0

	if character_component.stance == Global.stance.crouching:
		interval = 0.55
		volume_offset = -9.0
	elif character_component.gait == Global.gait.sprinting:
		interval = 0.27
		volume_offset = 1.0
	elif character_component.gait == Global.gait.running:
		interval = 0.35
		volume_offset = -1.5
	else:
		# walking
		interval = 0.45
		volume_offset = -5.0

	_step_timer += delta
	if _step_timer >= interval:
		_step_timer = 0.0
		_play_footstep(volume_offset)

func _play_footstep(volume_offset: float = 0.0) -> void:
	if footstep_player == null or footstep_sounds.is_empty():
		return
	var count: int = footstep_sounds.size()
	var idx: int = randi() % count
	if count > 1 and idx == _last_footstep_index:
		idx = (idx + 1 + randi() % (count - 1)) % count
	_last_footstep_index = idx

	footstep_player.stream = footstep_sounds[idx]
	footstep_player.pitch_scale = randf_range(0.92, 1.08)
	footstep_player.volume_db = volume_offset
	footstep_player.play()
