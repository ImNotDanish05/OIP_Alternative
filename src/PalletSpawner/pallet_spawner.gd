@tool
class_name PalletSpawner
extends Node3D

## The pallet scene to spawn (must be a Pallet-derived PackedScene).
@export var scene: PackedScene
## When enabled, stops spawning new pallets.
@export var disable: bool = false:
	set(value):
		if value == disable:
			return
		disable = value
		if not disable:
			_reset_spawn_cycle()
		_change_texture()

## Initial velocity applied to spawned pallets.
@export var spawn_initial_linear_velocity: Vector3 = Vector3.ZERO
## Mass applied to spawned pallets, in kilograms.
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var mass: float = 20.0
var _updating_rate: bool = false

@export_group("Spawn Timing")
## Initial delay in seconds before the first pallet spawns after simulation starts.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var start_delay: float = 0.0:
	set(value):
		if value == null:
			start_delay = 0.0
			return
		start_delay = maxf(0.0, float(value))

## Interval between pallet spawns in seconds. Changing this automatically updates pallets_per_minute.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var spawn_interval: float = 6.0:
	set(value):
		spawn_interval = maxf(0.05, value)
		if not _updating_rate:
			_updating_rate = true
			pallets_per_minute = clampi(roundi(60.0 / spawn_interval), 1, 1000)
			_updating_rate = false
			notify_property_list_changed()

@export_group("Spawn Rate")
## Number of pallets spawned per minute (1-1000). Changing this automatically updates spawn_interval.
@export var pallets_per_minute: int = 10:
	set(value):
		value = clampi(value, 1, 1000)
		pallets_per_minute = value
		if not _updating_rate:
			_updating_rate = true
			spawn_interval = snappedf(60.0 / float(pallets_per_minute), 0.01)
			_updating_rate = false
			notify_property_list_changed()

## When true, pallets spawn at a fixed rate. When false, spawn times vary randomly.
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
var _first_spawn_done: bool = false

@onready var disabled_pallet: MeshInstance3D = $Disabled_Pallet

func _enter_tree() -> void:
	set_notify_local_transform(true)
	_reset_spawn_cycle()
	Simulation.started.connect(_on_simulation_started)
	Simulation.stopped.connect(_on_simulation_ended)

func _ready() -> void:
	set_physics_process(Simulation.is_running())
	_change_texture()

func _exit_tree() -> void:
	Simulation.started.disconnect(_on_simulation_started)
	Simulation.stopped.disconnect(_on_simulation_ended)

func _physics_process(delta: float) -> void:
	if conveyor and Simulation.is_running() and &"speed" in conveyor:
		_conveyor_stopped = conveyor.speed == 0

	if disable or _conveyor_stopped or not Simulation.is_running() or Simulation.is_paused():
		return

	if pallets_per_minute <= 0 or spawn_interval <= 0.0:
		return

	_scan_interval += delta

	if not _first_spawn_done:
		if _scan_interval >= start_delay:
			_spawn_box()
			_first_spawn_done = true
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
			_next_spawn_time = spawn_interval * randf_range(0.5, 1.5)
			_scan_interval = 0.0

func _spawn_box() -> void:
	var pallet := scene.instantiate() as Pallet

	pallet.initial_linear_velocity = spawn_initial_linear_velocity
	pallet.mass = mass
	pallet.instanced = true
	add_child(pallet, true)
	pallet.global_transform = global_transform
	pallet.owner = get_tree().edited_scene_root

func _reset_spawn_cycle() -> void:
	_scan_interval = 0.0
	_first_spawn_done = false
	_next_spawn_time = spawn_interval * randf_range(0.5, 1.5)

func use() -> void:
	disable = not disable

func _change_texture() -> void:
	if not is_inside_tree():
		return
	disabled_pallet.visible = disable

func _on_simulation_started() -> void:
	if conveyor and &"speed" not in conveyor:
		push_warning("Conveyor reference in " + name + " does not have a speed property")
	set_physics_process(true)
	_reset_spawn_cycle()

func _on_simulation_ended() -> void:
	set_physics_process(false)
	_conveyor_stopped = false
