@tool
extends Node

## Autoload that manages runtime simulation playback controls:
## 1 = Resume / Play (Default)
## 2 = Pause
## 3 = Restart (Reset dynamic objects & restart from beginning)
## Screen is kept completely clean without UI overlay.


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Default is 1: Auto-start simulation after scene is fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	Simulation.start()
	print("SimulationController: Playback started (Default [1] Play). is_running = ", Simulation.is_running())


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var code: Key = key_event.keycode
	if code == KEY_NONE:
		code = key_event.physical_keycode

	if code == KEY_1 or code == KEY_KP_1:
		_action_play()
		get_viewport().set_input_as_handled()
	elif code == KEY_2 or code == KEY_KP_2:
		_action_pause()
		get_viewport().set_input_as_handled()
	elif code == KEY_3 or code == KEY_KP_3:
		_action_restart()
		get_viewport().set_input_as_handled()


func _action_play() -> void:
	if not Simulation.is_running():
		Simulation.start()
	elif Simulation.is_paused():
		Simulation.toggle_pause()
	print("SimulationController: [1] PLAY/RESUME (is_running=%s, is_paused=%s)" % [Simulation.is_running(), Simulation.is_paused()])


func _action_pause() -> void:
	if Simulation.is_running() and not Simulation.is_paused():
		Simulation.toggle_pause()
	print("SimulationController: [2] PAUSE (is_paused=%s)" % Simulation.is_paused())


func _action_restart() -> void:
	print("SimulationController: [3] RESTART simulation")
	Simulation.restart()
