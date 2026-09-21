@tool
class_name OIPComms
extends Node

const TAG_TYPE_BOOL: int = 0
const TAG_TYPE_INT16: int = 1
const TAG_TYPE_INT32: int = 2
const TAG_TYPE_FLOAT32: int = 3
const TAG_TYPE_FLOAT64: int = 4
const TAG_TYPE_UINT8: int = 5

signal tag_groups_registered_signal
signal tag_group_initialized_signal(group_name: String)
signal tag_group_polled_signal(group_name: String)
signal comms_error_signal
signal enable_comms_changed_signal

static var _instance: OIPComms = null
static var _enable_comms: bool = false
static var _enable_log: bool = false
static var _sim_running: bool = false
static var _tag_groups: Array = []
static var _tag_values: Dictionary = {}
static var _modbus_clients: Dictionary = {}

static var tag_groups_registered: Signal:
	get:
		_ensure_instance()
		return _instance.tag_groups_registered_signal

static var tag_group_initialized: Signal:
	get:
		_ensure_instance()
		return _instance.tag_group_initialized_signal

static var tag_group_polled: Signal:
	get:
		_ensure_instance()
		return _instance.tag_group_polled_signal

static var comms_error: Signal:
	get:
		_ensure_instance()
		return _instance.comms_error_signal

static var enable_comms_changed: Signal:
	get:
		_ensure_instance()
		return _instance.enable_comms_changed_signal


static func _ensure_instance() -> void:
	if _instance == null or not is_instance_valid(_instance):
		_instance = OIPComms.new()
		_instance.name = "OIPComms"
		_instance._hook_native()
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.add_child.call_deferred(_instance)


func _enter_tree() -> void:
	_instance = self
	_hook_native()


func _hook_native() -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != self:
			if native.has_signal("tag_groups_registered") and not native.is_connected("tag_groups_registered", _on_native_tag_groups_registered):
				native.connect("tag_groups_registered", _on_native_tag_groups_registered)
			if native.has_signal("tag_group_initialized") and not native.is_connected("tag_group_initialized", _on_native_tag_group_initialized):
				native.connect("tag_group_initialized", _on_native_tag_group_initialized)
			if native.has_signal("tag_group_polled") and not native.is_connected("tag_group_polled", _on_native_tag_group_polled):
				native.connect("tag_group_polled", _on_native_tag_group_polled)
			if native.has_signal("comms_error") and not native.is_connected("comms_error", _on_native_comms_error):
				native.connect("comms_error", _on_native_comms_error)
			if native.has_signal("enable_comms_changed") and not native.is_connected("enable_comms_changed", _on_native_enable_comms_changed):
				native.connect("enable_comms_changed", _on_native_enable_comms_changed)


func _on_native_tag_groups_registered() -> void:
	tag_groups_registered_signal.emit()


func _on_native_tag_group_initialized(group_name: String) -> void:
	tag_group_initialized_signal.emit(group_name)


func _on_native_tag_group_polled(group_name: String) -> void:
	tag_group_polled_signal.emit(group_name)


func _on_native_comms_error() -> void:
	comms_error_signal.emit()


func _on_native_enable_comms_changed() -> void:
	enable_comms_changed_signal.emit()


static func register_tag_group(group_name: String, polling_rate: int, protocol: String, gateway: String, path: String, cpu: String) -> void:
	_ensure_instance()
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("register_tag_group"):
			native.call("register_tag_group", group_name, polling_rate, protocol, gateway, path, cpu)
			return
	_tag_groups.append({
		"name": group_name,
		"polling_rate": polling_rate,
		"protocol": protocol,
		"gateway": gateway,
		"path": path,
		"cpu": cpu
	})

	if protocol == "modbus_tcp":
		var client: ModbusClient = _modbus_clients.get(group_name)
		if client == null:
			client = ModbusClient.new()
			client.name = "ModbusClient_" + group_name
			_modbus_clients[group_name] = client
			if _instance.is_inside_tree():
				_instance.add_child(client)
			else:
				_instance.add_child.call_deferred(client)

			client.connected_to_plc.connect(func(g: String) -> void:
				_instance.tag_group_initialized_signal.emit(g)
			)
			client.tags_polled.connect(func(g: String) -> void:
				_instance.tag_group_polled_signal.emit(g)
			)
			client.disconnected_from_plc.connect(func(_g: String) -> void:
				_instance.comms_error_signal.emit()
			)

		client.group_name = group_name
		client.host = gateway
		client.unit_id = path.to_int() if not path.is_empty() else 1
		client.polling_rate_ms = polling_rate
		client.connect_to_plc()
	else:
		_instance.tag_group_initialized_signal.emit(group_name)


static func clear_tag_groups() -> void:
	_ensure_instance()
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("clear_tag_groups"):
			native.call("clear_tag_groups")
			return
	_tag_groups.clear()
	_tag_values.clear()
	for client: ModbusClient in _modbus_clients.values():
		if is_instance_valid(client):
			client.disconnect_from_plc()
			client.queue_free()
	_modbus_clients.clear()


static func is_tag_group_initialized(group_name: String) -> bool:
	_ensure_instance()
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("is_tag_group_initialized"):
			return bool(native.call("is_tag_group_initialized", group_name))
	var client: ModbusClient = _modbus_clients.get(group_name)
	if client != null:
		return client.is_connected_to_plc()
	for g: Dictionary in _tag_groups:
		if str(g.get("name", "")) == group_name:
			return true
	return false


static func register_tag(group: String, tag: String, data_type: int = TAG_TYPE_BOOL) -> bool:
	_ensure_instance()
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("register_tag"):
			return bool(native.call("register_tag", group, tag, data_type))
	var key := group + "::" + tag
	if not _tag_values.has(key):
		match data_type:
			TAG_TYPE_BOOL: _tag_values[key] = false
			TAG_TYPE_INT16, TAG_TYPE_INT32, TAG_TYPE_UINT8: _tag_values[key] = 0
			TAG_TYPE_FLOAT32, TAG_TYPE_FLOAT64: _tag_values[key] = 0.0
			_: _tag_values[key] = 0

	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		client.register_tag(tag, data_type)

	return true


static func read_bit(group: String, tag: String) -> bool:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("read_bit"):
			return bool(native.call("read_bit", group, tag))
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		return client.read_bit(tag)
	return bool(_tag_values.get(group + "::" + tag, false))


static func write_bit(group: String, tag: String, value: bool) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("write_bit"):
			native.call("write_bit", group, tag, value)
			return
	_tag_values[group + "::" + tag] = value
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		client.write_bit(tag, value)


static func read_float32(group: String, tag: String) -> float:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("read_float32"):
			return float(native.call("read_float32", group, tag))
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		return client.read_float32(tag)
	return float(_tag_values.get(group + "::" + tag, 0.0))


static func write_float32(group: String, tag: String, value: float) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("write_float32"):
			native.call("write_float32", group, tag, value)
			return
	_tag_values[group + "::" + tag] = value
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		client.write_float32(tag, value)


static func read_float64(group: String, tag: String) -> float:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("read_float64"):
			return float(native.call("read_float64", group, tag))
	return float(_tag_values.get(group + "::" + tag, 0.0))


static func write_float64(group: String, tag: String, value: float) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("write_float64"):
			native.call("write_float64", group, tag, value)
			return
	_tag_values[group + "::" + tag] = value


static func read_int16(group: String, tag: String) -> int:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("read_int16"):
			return int(native.call("read_int16", group, tag))
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		return client.read_int16(tag)
	return int(_tag_values.get(group + "::" + tag, 0))


static func write_int16(group: String, tag: String, value: int) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("write_int16"):
			native.call("write_int16", group, tag, value)
			return
	_tag_values[group + "::" + tag] = value
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		client.write_int16(tag, value)


static func read_int32(group: String, tag: String) -> int:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("read_int32"):
			return int(native.call("read_int32", group, tag))
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		return client.read_int32(tag)
	return int(_tag_values.get(group + "::" + tag, 0))


static func write_int32(group: String, tag: String, value: int) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("write_int32"):
			native.call("write_int32", group, tag, value)
			return
	_tag_values[group + "::" + tag] = value
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		client.write_int32(tag, value)


static func read_uint8(group: String, tag: String) -> int:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("read_uint8"):
			return int(native.call("read_uint8", group, tag))
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		return client.read_uint8(tag)
	return int(_tag_values.get(group + "::" + tag, 0))


static func write_uint8(group: String, tag: String, value: int) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("write_uint8"):
			native.call("write_uint8", group, tag, value)
			return
	_tag_values[group + "::" + tag] = value
	var client: ModbusClient = _modbus_clients.get(group)
	if client != null:
		client.write_uint8(tag, value)


static func get_enable_comms() -> bool:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("get_enable_comms"):
			return bool(native.call("get_enable_comms"))
	return _enable_comms


static func set_enable_comms(enabled: bool) -> void:
	_ensure_instance()
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("set_enable_comms"):
			native.call("set_enable_comms", enabled)
			return
	_enable_comms = enabled
	_instance.enable_comms_changed_signal.emit()
	if not enabled:
		for client: ModbusClient in _modbus_clients.values():
			if is_instance_valid(client):
				client.disconnect_from_plc()
	else:
		for client: ModbusClient in _modbus_clients.values():
			if is_instance_valid(client):
				client.connect_to_plc()


static func set_sim_running(running: bool) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("set_sim_running"):
			native.call("set_sim_running", running)
			return
	_sim_running = running


static func set_enable_log(enabled: bool) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("set_enable_log"):
			native.call("set_enable_log", enabled)
			return
	_enable_log = enabled


static func get_comms_error() -> String:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("get_comms_error"):
			return String(native.call("get_comms_error"))
	return ""


static func get_tag_groups() -> Array:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("get_tag_groups"):
			return native.call("get_tag_groups") as Array
	return _tag_groups


static func set_soft_plc_program(group: String, program: String) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("set_soft_plc_program"):
			native.call("set_soft_plc_program", group, program)


static func compile_soft_plc(group: String, program: String) -> String:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("compile_soft_plc"):
			return String(native.call("compile_soft_plc", group, program))
	return ""


static func set_soft_plc_watch_enabled(group: String, enabled: bool) -> void:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("set_soft_plc_watch_enabled"):
			native.call("set_soft_plc_watch_enabled", group, enabled)


static func get_soft_plc_watch(group: String) -> Dictionary:
	if Engine.has_singleton("OIPComms"):
		var native: Object = Engine.get_singleton("OIPComms")
		if native != _instance and native.has_method("get_soft_plc_watch"):
			return native.call("get_soft_plc_watch", group) as Dictionary
	return {}
