extends Node

## Autoload that manages the runtime dual-camera system:
## - Camera 1 (Default): Godot 3D Editor-style camera (RMB Fly, MMB Orbit, Shift+MMB Pan, Scroll Zoom).
##   Initial view matches the editor 3D viewport camera position and orientation before play.
##   Player character is hidden and collision/inputs are disabled while in Camera 1.
## - Camera 2: Player capsule character (AMSG walking, running, crouching, jumping, flying, flashlight).
##   Player becomes visible and controllable.
## - Press TAB to seamlessly switch between Camera 1 and Camera 2 with position synchronization.
## - Clean view: 100% no UI overlay.

const EditorCameraScript: GDScript = preload("res://src/Camera/editor_camera.gd")
const InteractionHUDScript: GDScript = preload("res://src/Player/interaction_hud.gd")
const PLAYER_SCENE_PATH: String = "res://parts/Player.tscn"
const SPAWN_HEIGHT: float = 2.2
const FALLBACK_SPAWN: Vector3 = Vector3(0.0, 3.0, 8.0)

enum CameraMode {
	EDITOR = 1,
	PLAYER = 2,
}

var _current_mode: CameraMode = CameraMode.EDITOR
var _editor_camera: Camera3D = null
var _player_instance: Node3D = null
var _interaction_hud: InteractionHUD = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Wait for physics frames so Jolt physics space state is fully active
	await get_tree().physics_frame
	await get_tree().physics_frame
	_try_spawn()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_TAB:
			toggle_camera_mode()
			get_viewport().set_input_as_handled()


func toggle_camera_mode() -> void:
	if _editor_camera == null or _player_instance == null:
		return

	if _current_mode == CameraMode.EDITOR:
		# Switch to Camera 2 (Player)
		await get_tree().physics_frame
		_sync_player_from_editor_camera()
		if _editor_camera.has_method("deactivate"):
			_editor_camera.call("deactivate")
		_set_player_enabled(_player_instance, true)

		var p_cam: Camera3D = _find_camera_in(_player_instance)
		if p_cam:
			p_cam.current = true

		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_current_mode = CameraMode.PLAYER
		if _interaction_hud:
			_interaction_hud.set_player_mode(true, _player_instance)
		print("[Camera] Switched to Camera 2 (Player Camera). Press TAB to toggle back.")
	else:
		# Switch to Camera 1 (Editor Camera)
		var p_cam: Camera3D = _find_camera_in(_player_instance)
		if p_cam and _editor_camera.has_method("sync_from_camera"):
			_editor_camera.call("sync_from_camera", p_cam)

		_set_player_enabled(_player_instance, false)
		if _editor_camera.has_method("activate"):
			_editor_camera.call("activate")
		_editor_camera.current = true

		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_current_mode = CameraMode.EDITOR
		if _interaction_hud:
			_interaction_hud.set_player_mode(false, _player_instance)
		print("[Camera] Switched to Camera 1 (Godot Editor Camera). Press TAB to toggle back.")


func get_current_camera_mode() -> CameraMode:
	return _current_mode


func _try_spawn() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		var root: Window = tree.root
		if root and root.get_child_count() > 0:
			current_scene = root.get_child(root.get_child_count() - 1)

	if current_scene == null:
		return

	# 1. Locate or spawn Player instance
	_player_instance = _find_existing_player(current_scene)
	if _player_instance == null:
		if ResourceLoader.exists(PLAYER_SCENE_PATH):
			var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
			if packed:
				_player_instance = packed.instantiate() as Node3D
				if _player_instance:
					var spawn_pos: Vector3 = _find_spawn_position(current_scene)
					spawn_pos.y = _find_ground_height(current_scene, spawn_pos)
					_player_instance.position = spawn_pos
					current_scene.add_child(_player_instance)
					_player_instance.owner = current_scene
					print("[PlayerSpawner] Spawned runtime Player at ", spawn_pos)

	# 2. Spawn runtime EditorCamera3D
	_editor_camera = EditorCameraScript.new() as Camera3D
	_editor_camera.name = "RuntimeEditorCamera"
	current_scene.add_child(_editor_camera)
	_editor_camera.owner = current_scene

	# Ensure scene and nodes are ready
	await get_tree().process_frame

	# 3. Initialize default to Camera 1 (Godot Editor Camera)
	if _editor_camera.has_method("activate"):
		_editor_camera.call("activate")
	_editor_camera.current = true

	if _player_instance:
		_set_player_enabled(_player_instance, false)
		var p_cam: Camera3D = _find_camera_in(_player_instance)
		if p_cam:
			p_cam.current = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_current_mode = CameraMode.EDITOR

	# 4. Spawn runtime InteractionHUD
	_interaction_hud = InteractionHUDScript.new() as InteractionHUD
	_interaction_hud.name = "RuntimeInteractionHUD"
	current_scene.add_child(_interaction_hud)
	_interaction_hud.set_player_mode(false, _player_instance)

	print("[PlayerSpawner] Dual Camera system active. Default: Camera 1 (Godot Editor Camera). Press TAB to switch to Player.")


func _set_player_enabled(player: Node, enabled: bool) -> void:
	if player == null:
		return

	# Hide / show visuals
	if player is Node3D:
		(player as Node3D).visible = enabled

	# Enable / disable physics body
	if player is CharacterBody3D:
		var cb: CharacterBody3D = player as CharacterBody3D
		cb.velocity = Vector3.ZERO
		cb.set_physics_process(enabled)
		cb.set_process(enabled)
		cb.set_process_input(enabled)

	# Enable / disable collision shapes so invisible player does not block physics
	for child: Node in player.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled

	# Enable / disable components
	var ctrl: Node = player.find_child("AMSGCapsuleController", true, false)
	if ctrl:
		ctrl.set_process_input(enabled)
		ctrl.set_physics_process(enabled)
		ctrl.set_process(enabled)

	var cmc: Node = player.find_child("CharacterMovementComponent", true, false)
	if cmc:
		cmc.set_physics_process(enabled)
		cmc.set_process(enabled)
		if cmc.get("velocity") != null:
			cmc.set("velocity", Vector3.ZERO)

	var cc: Node = player.find_child("CameraComponent", true, false)
	if cc:
		cc.set_physics_process(enabled)
		cc.set_process(enabled)
		cc.set_process_input(enabled)

	var audio: AudioStreamPlayer3D = player.find_child("FootstepAudio", true, false) as AudioStreamPlayer3D
	if audio and not enabled:
		audio.stop()


func _sync_player_from_editor_camera() -> void:
	if _player_instance == null or _editor_camera == null:
		return

	var cam_pos: Vector3 = _editor_camera.global_position
	# Player eye height in First Person is roughly 1.6m from player base
	var target_player_pos: Vector3 = cam_pos - Vector3(0.0, 1.6, 0.0)

	var space: PhysicsDirectSpaceState3D = null
	if is_inside_tree() and get_viewport() and get_viewport().get_world_3d():
		space = get_viewport().get_world_3d().direct_space_state

	var is_airborne: bool = true

	if space:
		var from: Vector3 = cam_pos
		var to: Vector3 = cam_pos - Vector3(0.0, 100.0, 0.0)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = space.intersect_ray(query)
		if hit.has("position"):
			var floor_y: float = (hit["position"] as Vector3).y
			var feet_y: float = cam_pos.y - 1.6
			var clearance: float = feet_y - floor_y
			# If feet are close to the ground (within 0.5m), snap feet to floor
			if clearance <= 0.5 and clearance >= -0.8:
				target_player_pos.y = floor_y
				is_airborne = false
			else:
				is_airborne = true

	_player_instance.global_position = target_player_pos

	var cb: CharacterBody3D = _player_instance as CharacterBody3D
	if cb:
		cb.velocity = Vector3.ZERO
		if is_airborne:
			cb.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			cb.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	var cmc: Node = _player_instance.find_child("CharacterMovementComponent", true, false)
	if cmc:
		cmc.set("is_flying", is_airborne)
		cmc.set("vertical_velocity", Vector3.ZERO)
		var stair_col: CollisionShape3D = cmc.get("stair_collision_shape_3d") as CollisionShape3D
		if stair_col:
			stair_col.disabled = is_airborne

	# Sync look orientation
	var euler: Vector3 = _editor_camera.global_transform.basis.get_euler(EULER_ORDER_YXZ)
	var cam_comp: CameraComponent = _player_instance.find_child("CameraComponent", true, false) as CameraComponent
	if cam_comp:
		cam_comp.camera_h = euler.y
		cam_comp.camera_v = euler.x
		if cam_comp.HObject:
			cam_comp.HObject.rotation.y = euler.y
		if cam_comp.VObject:
			cam_comp.VObject.rotation.x = euler.x
		if cam_comp.SpringArm:
			cam_comp.SpringArm.global_position = cam_pos


func _find_existing_player(root: Node) -> Node3D:
	var players: Array[Node] = root.find_children("*", "Player", true, false)
	if not players.is_empty():
		return players[0] as Node3D
	var bodies: Array[Node] = root.find_children("*", "CharacterBody3D", true, false)
	for body: Node in bodies:
		var cams: Array[Node] = body.find_children("*", "Camera3D", true, false)
		if not cams.is_empty():
			return body as Node3D
	return null


func _find_spawn_position(root: Node) -> Vector3:
	var buildings: Array[Node] = root.find_children("*", "Building", true, false)
	if not buildings.is_empty():
		var building: Node3D = buildings[0] as Node3D
		if building:
			var b_pos: Vector3 = building.global_position
			if b_pos == Vector3.ZERO and building.position != Vector3.ZERO:
				b_pos = building.position
			return b_pos + Vector3(0.0, SPAWN_HEIGHT, 6.0)
	var sim: Node = root.find_child("Simulation", true, false)
	if sim and sim is Node3D:
		return (sim as Node3D).global_position + Vector3(0.0, SPAWN_HEIGHT, 6.0)
	return FALLBACK_SPAWN


func _find_ground_height(_root: Node, spawn_pos: Vector3) -> float:
	if not is_inside_tree() or get_viewport() == null or get_viewport().get_world_3d() == null:
		return spawn_pos.y
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	if space == null:
		return spawn_pos.y
	var from: Vector3 = spawn_pos + Vector3(0.0, 5.0, 0.0)
	var to: Vector3 = spawn_pos - Vector3(0.0, 20.0, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = space.intersect_ray(query)
	if result.has("position"):
		var hit_y: float = (result["position"] as Vector3).y
		return hit_y + SPAWN_HEIGHT
	return spawn_pos.y


func _find_camera_in(root: Node) -> Camera3D:
	var cams: Array[Node] = root.find_children("*", "Camera3D", true, false)
	if cams.is_empty():
		return null
	return cams[0] as Camera3D
