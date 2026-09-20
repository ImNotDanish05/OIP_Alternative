@tool
class_name BoxSpawner
extends ResizableNode3D

## The box scene to spawn (must be a Box-derived PackedScene).
@export var scene: PackedScene
## When enabled, stops spawning new boxes.
@export var disable: bool = false:
	set(value):
		if value == disable:
			return
		disable = value
		if is_inside_tree():
			_change_texture()
			if not disable:
				_reset_spawn_cycle()

@export_group("Box")
## The color applied to spawned boxes.
@export var box_color: Color = Color.WHITE:
	set(value):
		box_color = value
## Mass applied to spawned boxes, in kilograms.
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var mass: float = 10.0
## Initial velocity applied to spawned boxes.
@export var initial_linear_velocity: Vector3 = Vector3.ZERO

@export_subgroup("Random Size")
## Enable random sizing for spawned boxes within min/max range.
@export var random_size: bool = false
## Minimum size for randomly sized boxes (X, Y, Z dimensions).
@export var random_size_min: Vector3 = Vector3(0.4, 0.3, 0.3)
## Maximum size for randomly sized boxes (X, Y, Z dimensions).
@export var random_size_max: Vector3 = Vector3(0.8, 0.5, 0.5)

@export_subgroup("Random Mass")
## Enable random mass for spawned boxes within min/max range.
@export var random_mass: bool = false
## Minimum mass for randomly massed boxes, in kilograms.
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var random_mass_min: float = 5.0
## Maximum mass for randomly massed boxes, in kilograms.
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var random_mass_max: float = 15.0

var _updating_rate: bool = false

@export_group("Spawn Timing")
## Initial delay in seconds before the first box spawns after simulation starts.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var start_delay: float = 0.0:
	set(value):
		if value == null:
			start_delay = 0.0
			return
		start_delay = maxf(0.0, float(value))

## Interval between box spawns in seconds. Changing this automatically updates boxes_per_minute.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var spawn_interval: float = 1.33:
	set(value):
		spawn_interval = maxf(0.05, value)
		if not _updating_rate:
			_updating_rate = true
			boxes_per_minute = clampi(roundi(60.0 / spawn_interval), 1, 1000)
			_updating_rate = false
			notify_property_list_changed()

@export_group("Spawn Rate")
## Number of boxes spawned per minute (0-1000). Changing this automatically updates spawn_interval.
@export var boxes_per_minute: int = 45:
	set(value):
		value = clampi(value, 0, 1000)
		boxes_per_minute = value
		if not _updating_rate:
			_updating_rate = true
			if boxes_per_minute > 0:
				spawn_interval = snappedf(60.0 / float(boxes_per_minute), 0.01)
			_updating_rate = false
			notify_property_list_changed()

## When true, boxes spawn at a fixed rate. When false, spawn times vary randomly.
@export var fixed_rate: bool = true
## Optional conveyor reference. Spawning pauses when conveyor speed is zero.
@export var conveyor: Node3D = null:
	set(value):
		conveyor = value
		if not value:
			_conveyor_stopped = false

var _scan_interval: float = 0.0
var _conveyor_stopped: bool = false
var _next_spawn_time: float = 0.0
var _spawn_counter: int = 0
var _first_spawn_done: bool = false

@onready var _preview_mesh: MeshInstance3D = $MeshInstance3D
@onready var disabled_box_texture: MeshInstance3D = $MeshInstance3D2
@onready var _preview_collision: CollisionShape3D = $Area3D/CollisionShape3D

func _init() -> void:
	super._init()
	size_default = Vector3(0.6, 0.4, 0.4)

func _enter_tree() -> void:
	super._enter_tree()
	_reset_spawn_cycle()

func _ready() -> void:
	Simulation.started.connect(_on_simulation_started)
	Simulation.stopped.connect(_on_simulation_ended)
	_on_size_changed()
	_change_texture()

func _on_size_changed() -> void:
	if is_instance_valid(_preview_mesh):
		_preview_mesh.scale = size * 0.5
	if is_instance_valid(disabled_box_texture):
		disabled_box_texture.scale = size * 0.501
	if is_instance_valid(_preview_collision):
		var box_shape := _preview_collision.shape as BoxShape3D
		if box_shape:
			box_shape.size = size

func _physics_process(delta: float) -> void:
	if conveyor and Simulation.is_running() and &"speed" in conveyor:
		_conveyor_stopped = conveyor.speed == 0

	if disable or _conveyor_stopped or not Simulation.is_running() or Simulation.is_paused():
		return

	if boxes_per_minute <= 0 or spawn_interval <= 0.0:
		return
	
	_scan_interval += delta

	if not _first_spawn_done:
		if _scan_interval >= start_delay:
			_spawn_box()
			_first_spawn_done = true
			_spawn_counter += 1
			_scan_interval = 0.0
			_next_spawn_time = spawn_interval * randf_range(0.5, 1.5)
		return

	if fixed_rate:
		var time_between: float = spawn_interval
		if _scan_interval >= time_between:
			_spawn_box()
			_scan_interval -= time_between
	else:
		if _scan_interval >= _next_spawn_time:
			_spawn_box()
			_spawn_counter += 1
			if _spawn_counter >= boxes_per_minute:
				_reset_spawn_cycle()
			else:
				_next_spawn_time = _scan_interval + spawn_interval * randf_range(0.5, 1.5)

func _spawn_box() -> void:
	var box := scene.instantiate() as Box

	if random_size:
		var x := randf_range(random_size_min.x, random_size_max.x)
		var y := randf_range(random_size_min.y, random_size_max.y)
		var z := randf_range(random_size_min.z, random_size_max.z)
		box.size = Vector3(x, y, z)
	else:
		box.size = size

	if random_mass:
		box.mass = randf_range(random_mass_min, random_mass_max)
	else:
		box.mass = mass

	box.initial_linear_velocity = initial_linear_velocity
	box.color = box_color
	box.instanced = true
	add_child(box, true)
	box.global_transform = global_transform
	box.owner = get_tree().edited_scene_root

func _reset_spawn_cycle() -> void:
	_scan_interval = 0.0
	_spawn_counter = 0
	_first_spawn_done = false
	_next_spawn_time = spawn_interval * randf_range(0.5, 1.5)

func _change_texture() -> void:
	if not is_inside_tree():
		return
	disabled_box_texture.visible = disable

func use() -> void:
	disable = not disable

func _on_simulation_started() -> void:
	if conveyor and &"speed" not in conveyor:
		push_warning("Conveyor reference in " + name + " does not have a speed property")
	_reset_spawn_cycle()

func _on_simulation_ended() -> void:
	_conveyor_stopped = false
