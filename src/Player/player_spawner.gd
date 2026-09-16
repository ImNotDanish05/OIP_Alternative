extends Node

## Autoload that guarantees a playable capsule player exists at runtime.
## If the current running scene already contains a Camera3D or Player/CharacterBody3D, we do nothing.
## Otherwise we instance parts/Player.tscn and place it near the building center, slightly above ground.

const PLAYER_SCENE_PATH: String = "res://parts/Player.tscn"
const SPAWN_HEIGHT: float = 2.2
const FALLBACK_SPAWN: Vector3 = Vector3(0.0, 3.0, 8.0)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Delay one frame so the main scene is fully in the tree (handles both "Run Current Scene" and "Play").
	await get_tree().process_frame
	await get_tree().process_frame
	_try_spawn()


func _try_spawn() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		# Fallback: use root's last child as the scene.
		var root: Window = tree.root
		if root and root.get_child_count() > 0:
			current_scene = root.get_child(root.get_child_count() - 1)

	if current_scene == null:
		return

	# If there's already a Player (our class) or any Camera3D or CharacterBody3D that looks like a player, don't spawn.
	if _has_existing_player_or_camera(current_scene):
		return

	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		push_warning("PlayerSpawner: Player scene not found at %s" % PLAYER_SCENE_PATH)
		return

	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("PlayerSpawner: Failed to load %s" % PLAYER_SCENE_PATH)
		return

	var player: Node3D = packed.instantiate() as Node3D
	if player == null:
		push_warning("PlayerSpawner: Scene root is not Node3D")
		return

	# Choose spawn position: center of Building if present, else fallback.
	var spawn_pos: Vector3 = _find_spawn_position(current_scene)

	# Ensure player is not spawned inside collision - lift slightly and try to place on ground via ray.
	spawn_pos.y = _find_ground_height(current_scene, spawn_pos)

	player.position = spawn_pos
	# Ensure camera is current.
	current_scene.add_child(player)
	# Make sure ownership is correct when running (not needed but keeps tree clean).
	player.owner = current_scene

	# Ensure its camera is current next frame.
	await get_tree().process_frame
	var cam: Camera3D = _find_camera_in(player)
	if cam:
		cam.current = true
	# Also ensure mouse is captured.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("PlayerSpawner: Spawned runtime Player at ", spawn_pos)


func _has_existing_player_or_camera(root: Node) -> bool:
	# Look for our Player class specifically.
	var players: Array[Node] = root.find_children("*", "Player", true, false)
	if not players.is_empty():
		return true
	# Any CharacterBody3D that has a Camera3D descendant is likely a player/controller.
	var bodies: Array[Node] = root.find_children("*", "CharacterBody3D", true, false)
	for body: Node in bodies:
		var cams: Array[Node] = body.find_children("*", "Camera3D", true, false)
		if not cams.is_empty():
			return true
	# Any current/active Camera3D in the scene (e.g., user placed Camera3D)
	var cams_all: Array[Node] = root.find_children("*", "Camera3D", true, false)
	# If we find a Camera3D that is not inside Building's preview helpers, treat as existing.
	if not cams_all.is_empty():
		# Filter out non-gameplay cameras? For safety, if any Camera3D exists at root level, assume user intentional.
		return true
	return false


func _find_spawn_position(root: Node) -> Vector3:
	# Prefer Building center (with its offset), otherwise fallback.
	var buildings: Array[Node] = root.find_children("*", "Building", true, false)
	if not buildings.is_empty():
		var building: Node3D = buildings[0] as Node3D
		if building:
			# Building at origin with offset, but center is roughly at 0,0,0 plus its transform.
			# Spawn near center but offset forward so we see the hall.
			var b_pos: Vector3 = building.global_position
			# If building still at local origin, use 0,0,0
			if b_pos == Vector3.ZERO and building.position != Vector3.ZERO:
				b_pos = building.position
			# Nudge forward (+Z) and up.
			return b_pos + Vector3(0.0, SPAWN_HEIGHT, 6.0)
	# Try Simulation node position.
	var sim: Node = root.find_child("Simulation", true, false)
	if sim and sim is Node3D:
		return (sim as Node3D).global_position + Vector3(0.0, SPAWN_HEIGHT, 6.0)
	return FALLBACK_SPAWN


func _find_ground_height(_root: Node, spawn_pos: Vector3) -> float:
	# Raycast down to find floor, otherwise keep proposed Y.
	if not is_inside_tree():
		return spawn_pos.y
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	if space == null:
		return spawn_pos.y
	var from: Vector3 = spawn_pos + Vector3(0.0, 5.0, 0.0)
	var to: Vector3 = spawn_pos - Vector3(0.0, 20.0, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1) # Static layer 1
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
