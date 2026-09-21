@tool
extends Node

const TAG_GROUPS_FILE: String = "res://oip_data/tag_groups.cfg"
const SETTINGS_FILE: String = "res://oip_data/comms_settings.cfg"


func _ready() -> void:
	bootstrap()


func _exit_tree() -> void:
	if Simulation.started.is_connected(_on_simulation_started):
		Simulation.started.disconnect(_on_simulation_started)
	if Simulation.stopped.is_connected(_on_simulation_ended):
		Simulation.stopped.disconnect(_on_simulation_ended)
	if OIPComms.comms_error.is_connected(_on_comms_error):
		OIPComms.comms_error.disconnect(_on_comms_error)


func bootstrap() -> void:
	var oip_data_path := ProjectSettings.globalize_path("res://oip_data")
	if not DirAccess.dir_exists_absolute(oip_data_path):
		DirAccess.make_dir_recursive_absolute(oip_data_path)
	_apply_settings()
	register_tag_groups()

	if not Simulation.started.is_connected(_on_simulation_started):
		Simulation.started.connect(_on_simulation_started)
	if not Simulation.stopped.is_connected(_on_simulation_ended):
		Simulation.stopped.connect(_on_simulation_ended, CONNECT_DEFERRED)
	if not OIPComms.comms_error.is_connected(_on_comms_error):
		OIPComms.comms_error.connect(_on_comms_error)


func register_tag_groups() -> void:
	OIPComms.clear_tag_groups()
	for group: Dictionary in _load_tag_groups():
		var group_name: String = group.name
		var polling_rate: String = group.polling_rate

		var pt_num: String = group.protocol
		var pt: String = ""
		if pt_num == "0": pt = "ab_eip"
		elif pt_num == "1": pt = "modbus_tcp"
		elif pt_num == "2": pt = "opc_ua"
		elif pt_num == "3": pt = "s7"
		elif pt_num == "4": pt = "ads"
		elif pt_num == "5": pt = "rtde"
		elif pt_num == "6": pt = "mqtt"
		elif pt_num == "7": pt = "soft_plc"

		var gateway: String = group.gateway
		var path: String = group.path
		var cpu: String = group.cpu
		OIPComms.register_tag_group(group_name, int(polling_rate), pt, gateway, path, cpu)
	OIPComms.tag_groups_registered.emit()


func _load_tag_groups() -> Array:
	var groups: Array = []
	var config: ConfigFile = ConfigFile.new()
	if config.load(TAG_GROUPS_FILE) != OK:
		return groups

	var group_count: int = config.get_value("info", "group_count", 0)
	for i: int in range(group_count):
		var section: String = "group_" + str(i)
		groups.append({
			"name": config.get_value(section, "name", "TagGroup" + str(i)),
			"polling_rate": config.get_value(section, "polling_rate", "100"),
			"protocol": config.get_value(section, "protocol", "0"),
			"gateway": config.get_value(section, "gateway", "localhost"),
			"path": config.get_value(section, "path", "1,0"),
			"cpu": config.get_value(section, "cpu", "ControlLogix"),
		})
	return groups


func _apply_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return
	OIPComms.set_enable_comms(config.get_value("settings", "enable_comms", false))


func _on_simulation_started() -> void:
	OIPComms.set_sim_running(true)
	_notify_groups_initialized.call_deferred()


func _notify_groups_initialized() -> void:
	for group: Dictionary in _load_tag_groups():
		var group_name: String = str(group.get("name", ""))
		if OIPComms.is_tag_group_initialized(group_name):
			OIPComms.tag_group_initialized.emit(group_name)


func _on_simulation_ended() -> void:
	OIPComms.set_sim_running(false)


func _on_comms_error() -> void:
	push_warning("OIPComms: Communication error on PLC tag group. Check network/PLC connection.")
