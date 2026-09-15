@tool
class_name Simulation
extends Node

signal started_signal
signal stopped_signal
signal pause_toggled_signal

static var _instance: Simulation = null
static var _running: bool = false
static var _paused: bool = false

static var started: Signal:
	get:
		_ensure_instance()
		return _instance.started_signal

static var stopped: Signal:
	get:
		_ensure_instance()
		return _instance.stopped_signal

static var pause_toggled: Signal:
	get:
		_ensure_instance()
		return _instance.pause_toggled_signal


static func _ensure_instance() -> void:
	if _instance == null or not is_instance_valid(_instance):
		_instance = Simulation.new()
		_instance.name = "Simulation"
		_instance._hook_native()


func _enter_tree() -> void:
	_instance = self
	_hook_native()


func _hook_native() -> void:
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native != self:
			if native.has_signal("started") and not native.is_connected("started", _on_native_started):
				native.connect("started", _on_native_started)
			if native.has_signal("stopped") and not native.is_connected("stopped", _on_native_stopped):
				native.connect("stopped", _on_native_stopped)
			if native.has_signal("pause_toggled") and not native.is_connected("pause_toggled", _on_native_pause_toggled):
				native.connect("pause_toggled", _on_native_pause_toggled)


func _on_native_started() -> void:
	_running = true
	_paused = false
	started_signal.emit()


func _on_native_stopped() -> void:
	_running = false
	_paused = false
	stopped_signal.emit()


func _on_native_pause_toggled() -> void:
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native.has_method("is_paused"):
			_paused = bool(native.call("is_paused"))
		else:
			_paused = not _paused
	else:
		_paused = not _paused
	pause_toggled_signal.emit()


static func start() -> void:
	_ensure_instance()
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native.has_method("start"):
			native.call("start")
			return
	if not _running:
		_running = true
		_paused = false
		_instance.started_signal.emit()


static func stop() -> void:
	_ensure_instance()
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native.has_method("stop"):
			native.call("stop")
			return
	if _running:
		_running = false
		_paused = false
		_instance.stopped_signal.emit()


static func toggle_pause() -> void:
	_ensure_instance()
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native.has_method("toggle_pause"):
			native.call("toggle_pause")
			return
	_paused = not _paused
	_instance.pause_toggled_signal.emit()


static func is_running() -> bool:
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native.has_method("is_running"):
			return bool(native.call("is_running"))
	return _running


static func is_paused() -> bool:
	if Engine.has_singleton("Simulation"):
		var native: Object = Engine.get_singleton("Simulation")
		if native.has_method("is_paused"):
			return bool(native.call("is_paused"))
	return _paused
