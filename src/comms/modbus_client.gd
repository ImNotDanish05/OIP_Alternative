@tool
class_name ModbusClient
extends Node

## Pure GDScript Modbus TCP client for Open Industry Project.
## Works cross-platform on Linux and Windows without native C++ compilation.

signal connected_to_plc(group: String)
signal disconnected_from_plc(group: String)
signal tags_polled(group: String)

var group_name: String = ""
var host: String = "localhost"
var port: int = 502
var unit_id: int = 1
var polling_rate_ms: int = 20
var auto_fallback_docker: bool = true

var _tcp: StreamPeerTCP = StreamPeerTCP.new()
var _current_target_host: String = ""
var _is_connected: bool = false
var _reconnect_cooldown: float = 0.0
var _poll_accumulator: float = 0.0
var _tx_id: int = 0
var _rx_buffer: PackedByteArray = PackedByteArray()

# Active in-flight requests: tx_id -> Dictionary
var _active_requests: Dictionary = {}

# Registered tags: tag_name -> {type: int, prefix: String, address: int}
var _registered_tags: Dictionary = {}

# Cached tag values: tag_name -> Variant
var _tag_values: Dictionary = {}

# Pending write queue when disconnected: Array of {fc: int, addr: int, val: Variant}
var _pending_writes: Array[Dictionary] = []
var _first_poll_logged: bool = false


func _ready() -> void:
	_current_target_host = host


func _process(delta: float) -> void:
	_tcp.poll()
	var status: StreamPeerTCP.Status = _tcp.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not _is_connected:
			_is_connected = true
			print("ModbusClient: Connected to %s:%d (group: '%s')" % [_current_target_host, port, group_name])
			connected_to_plc.emit(group_name)
			_flush_pending_writes()

		# Read any available incoming data
		var avail: int = _tcp.get_available_bytes()
		if avail > 0:
			var read_res: Array = _tcp.get_data(avail)
			if read_res[0] == OK:
				_rx_buffer.append_array(read_res[1] as PackedByteArray)
				_process_rx_buffer()

		# Handle polling timer
		_poll_accumulator += delta
		var interval_sec: float = maxf(0.01, float(polling_rate_ms) / 1000.0)
		if _poll_accumulator >= interval_sec:
			_poll_accumulator = 0.0
			_send_poll_requests()

	elif status == StreamPeerTCP.STATUS_CONNECTING:
		# Still establishing TCP handshake
		pass
	else:
		# STATUS_NONE or STATUS_ERROR
		if _is_connected:
			_is_connected = false
			print("ModbusClient: Disconnected from %s:%d (group: '%s')" % [_current_target_host, port, group_name])
			disconnected_from_plc.emit(group_name)

		_handle_reconnect(delta)


func connect_to_plc() -> void:
	if _current_target_host.is_empty():
		_current_target_host = host
	_do_connect(_current_target_host, port)


func disconnect_from_plc() -> void:
	_tcp.disconnect_from_host()
	_is_connected = false
	_rx_buffer.clear()
	_active_requests.clear()


func is_connected_to_plc() -> bool:
	return _is_connected


func _do_connect(target_host: String, target_port: int) -> void:
	_tcp.disconnect_from_host()
	_rx_buffer.clear()
	_active_requests.clear()
	var err: Error = _tcp.connect_to_host(target_host, target_port)
	if err != OK:
		push_warning("ModbusClient: Could not initiate connection to %s:%d (%d)" % [target_host, target_port, err])


func _handle_reconnect(delta: float) -> void:
	_reconnect_cooldown -= delta
	if _reconnect_cooldown <= 0.0:
		_reconnect_cooldown = 2.5
		if auto_fallback_docker:
			var os_name: String = OS.get_name()
			if os_name == "Linux":
				# On Linux: If localhost fails (e.g. docker port 502 not mapped to host), try docker bridge IP
				if _current_target_host == host and (host == "localhost" or host == "127.0.0.1"):
					_current_target_host = "172.17.0.2"
				else:
					_current_target_host = host
			elif os_name == "Windows":
				# On Windows: If linux docker IP 172.17.0.2 is configured, try localhost
				if _current_target_host == host and host.begins_with("172.17."):
					_current_target_host = "localhost"
				else:
					_current_target_host = host
			else:
				_current_target_host = host
		else:
			_current_target_host = host

		_do_connect(_current_target_host, port)


func register_tag(tag: String, data_type: int) -> bool:
	var parsed: Dictionary = _parse_tag(tag)
	_registered_tags[tag] = {
		"type": data_type,
		"prefix": parsed.prefix,
		"address": parsed.address
	}
	if not _tag_values.has(tag):
		match data_type:
			OIPComms.TAG_TYPE_BOOL: _tag_values[tag] = false
			OIPComms.TAG_TYPE_FLOAT32, OIPComms.TAG_TYPE_FLOAT64: _tag_values[tag] = 0.0
			_: _tag_values[tag] = 0
	return true


func read_bit(tag: String) -> bool:
	return bool(_tag_values.get(tag, false))


func write_bit(tag: String, value: bool) -> void:
	_tag_values[tag] = value
	var parsed: Dictionary = _parse_tag(tag)
	if parsed.prefix == "co":
		print("ModbusClient [%s]: Writing coil %s = %s" % [group_name, tag, value])
		_send_modbus_write_coil(parsed.address, value)


func read_float32(tag: String) -> float:
	return float(_tag_values.get(tag, 0.0))


func write_float32(tag: String, value: float) -> void:
	_tag_values[tag] = value
	var parsed: Dictionary = _parse_tag(tag)
	if parsed.prefix == "hr":
		_send_modbus_write_float32(parsed.address, value)


func read_int16(tag: String) -> int:
	var val: int = int(_tag_values.get(tag, 0))
	if val >= 0x8000:
		val -= 0x10000
	return val


func write_int16(tag: String, value: int) -> void:
	_tag_values[tag] = value
	var parsed: Dictionary = _parse_tag(tag)
	if parsed.prefix == "hr":
		_send_modbus_write_int16(parsed.address, value)


func read_int32(tag: String) -> int:
	return int(_tag_values.get(tag, 0))


func write_int32(tag: String, value: int) -> void:
	_tag_values[tag] = value
	var parsed: Dictionary = _parse_tag(tag)
	if parsed.prefix == "hr":
		_send_modbus_write_int32(parsed.address, value)


func read_uint8(tag: String) -> int:
	var val: Variant = _tag_values.get(tag, 0)
	if val is bool:
		return 1 if val else 0
	return int(val) & 0xFF


func write_uint8(tag: String, value: int) -> void:
	_tag_values[tag] = value
	var parsed: Dictionary = _parse_tag(tag)
	if parsed.prefix == "co":
		_send_modbus_write_coil(parsed.address, (value & 1) != 0)
	elif parsed.prefix == "hr":
		_send_modbus_write_int16(parsed.address, value & 0xFF)


func _send_poll_requests() -> void:
	if _registered_tags.is_empty():
		return

	# Group registered tags by prefix
	var coil_addrs: Array[int] = []
	var input_addrs: Array[int] = []
	var hr_addrs: Array[int] = []

	for tag: String in _registered_tags:
		var info: Dictionary = _registered_tags[tag]
		var pfx: String = info.prefix
		var addr: int = info.address
		if pfx == "co":
			coil_addrs.append(addr)
		elif pfx == "di":
			input_addrs.append(addr)
		elif pfx == "hr":
			hr_addrs.append(addr)
			if info.type == OIPComms.TAG_TYPE_FLOAT32 or info.type == OIPComms.TAG_TYPE_INT32:
				hr_addrs.append(addr + 1)

	# Read coils
	if not coil_addrs.is_empty():
		var min_a: int = int(coil_addrs.min())
		var max_a: int = int(coil_addrs.max())
		var count: int = max_a - min_a + 1
		_send_modbus_read(1, min_a, count)

	# Read discrete inputs
	if not input_addrs.is_empty():
		var min_a: int = int(input_addrs.min())
		var max_a: int = int(input_addrs.max())
		var count: int = max_a - min_a + 1
		_send_modbus_read(2, min_a, count)

	# Read holding registers
	if not hr_addrs.is_empty():
		var min_a: int = int(hr_addrs.min())
		var max_a: int = int(hr_addrs.max())
		var count: int = max_a - min_a + 1
		_send_modbus_read(3, min_a, count)


func _build_mbap(tx_id: int, pdu_len: int) -> PackedByteArray:
	var buf := PackedByteArray()
	# Transaction ID (16-bit Big Endian)
	buf.append((tx_id >> 8) & 0xFF)
	buf.append(tx_id & 0xFF)
	# Protocol ID (0x0000)
	buf.append(0)
	buf.append(0)
	# Length (16-bit Big Endian): 1 byte unit_id + pdu_len
	var length: int = 1 + pdu_len
	buf.append((length >> 8) & 0xFF)
	buf.append(length & 0xFF)
	# Unit ID (1 byte)
	buf.append(unit_id & 0xFF)
	return buf


func _send_modbus_read(fc: int, start_addr: int, quantity: int) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	_tx_id = (_tx_id + 1) & 0xFFFF
	var tx: int = _tx_id

	var pdu := PackedByteArray()
	pdu.append(fc & 0xFF)
	pdu.append((start_addr >> 8) & 0xFF)
	pdu.append(start_addr & 0xFF)
	pdu.append((quantity >> 8) & 0xFF)
	pdu.append(quantity & 0xFF)

	var packet: PackedByteArray = _build_mbap(tx, pdu.size())
	packet.append_array(pdu)

	_active_requests[tx] = {"fc": fc, "start": start_addr, "count": quantity}
	_tcp.put_data(packet)


func _send_modbus_write_coil(addr: int, value: bool) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_pending_writes.append({"type": "coil", "addr": addr, "val": value})
		return

	_tx_id = (_tx_id + 1) & 0xFFFF
	var tx: int = _tx_id

	var pdu := PackedByteArray()
	pdu.append(5) # FC 5: Write Single Coil
	pdu.append((addr >> 8) & 0xFF)
	pdu.append(addr & 0xFF)
	var val_bytes: int = 0xFF00 if value else 0x0000
	pdu.append((val_bytes >> 8) & 0xFF)
	pdu.append(val_bytes & 0xFF)

	var packet: PackedByteArray = _build_mbap(tx, pdu.size())
	packet.append_array(pdu)

	_active_requests[tx] = {"fc": 5, "addr": addr}
	_tcp.put_data(packet)


func _send_modbus_write_float32(addr: int, value: float) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_pending_writes.append({"type": "float32", "addr": addr, "val": value})
		return

	_tx_id = (_tx_id + 1) & 0xFFFF
	var tx: int = _tx_id

	var spb := StreamPeerBuffer.new()
	spb.big_endian = true
	spb.put_float(value)
	var float_bytes: PackedByteArray = spb.data_array

	var pdu := PackedByteArray()
	pdu.append(16) # FC 16 (0x10): Write Multiple Registers
	pdu.append((addr >> 8) & 0xFF)
	pdu.append(addr & 0xFF)
	pdu.append(0)  # Quantity high
	pdu.append(2)  # Quantity low (2 registers)
	pdu.append(4)  # Byte count (4 bytes)
	pdu.append_array(float_bytes)

	var packet: PackedByteArray = _build_mbap(tx, pdu.size())
	packet.append_array(pdu)

	_active_requests[tx] = {"fc": 16, "addr": addr}
	_tcp.put_data(packet)


func _send_modbus_write_int32(addr: int, value: int) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_pending_writes.append({"type": "int32", "addr": addr, "val": value})
		return

	_tx_id = (_tx_id + 1) & 0xFFFF
	var tx: int = _tx_id

	var spb := StreamPeerBuffer.new()
	spb.big_endian = true
	spb.put_32(value)
	var int_bytes: PackedByteArray = spb.data_array

	var pdu := PackedByteArray()
	pdu.append(16) # FC 16
	pdu.append((addr >> 8) & 0xFF)
	pdu.append(addr & 0xFF)
	pdu.append(0)
	pdu.append(2)
	pdu.append(4)
	pdu.append_array(int_bytes)

	var packet: PackedByteArray = _build_mbap(tx, pdu.size())
	packet.append_array(pdu)

	_active_requests[tx] = {"fc": 16, "addr": addr}
	_tcp.put_data(packet)


func _send_modbus_write_int16(addr: int, value: int) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_pending_writes.append({"type": "int16", "addr": addr, "val": value})
		return

	_tx_id = (_tx_id + 1) & 0xFFFF
	var tx: int = _tx_id

	var pdu := PackedByteArray()
	pdu.append(6) # FC 6: Write Single Register
	pdu.append((addr >> 8) & 0xFF)
	pdu.append(addr & 0xFF)
	var uval: int = value & 0xFFFF
	pdu.append((uval >> 8) & 0xFF)
	pdu.append(uval & 0xFF)

	var packet: PackedByteArray = _build_mbap(tx, pdu.size())
	packet.append_array(pdu)

	_active_requests[tx] = {"fc": 6, "addr": addr}
	_tcp.put_data(packet)


func _flush_pending_writes() -> void:
	while not _pending_writes.is_empty():
		var w: Dictionary = _pending_writes.pop_front()
		match w.get("type", ""):
			"coil": _send_modbus_write_coil(int(w.addr), bool(w.val))
			"float32": _send_modbus_write_float32(int(w.addr), float(w.val))
			"int32": _send_modbus_write_int32(int(w.addr), int(w.val))
			"int16": _send_modbus_write_int16(int(w.addr), int(w.val))


func _process_rx_buffer() -> void:
	while _rx_buffer.size() >= 7:
		var pdu_len: int = (_rx_buffer[4] << 8) | _rx_buffer[5]
		var total_len: int = 6 + pdu_len # 6 bytes MBAP + pdu_len
		if _rx_buffer.size() < total_len:
			break # Wait for remaining packet data

		var packet: PackedByteArray = _rx_buffer.slice(0, total_len)
		_rx_buffer = _rx_buffer.slice(total_len)
		_handle_response(packet)


func _handle_response(packet: PackedByteArray) -> void:
	if packet.size() < 8:
		return

	var tx: int = (packet[0] << 8) | packet[1]
	var fc: int = packet[7]

	if fc >= 0x80:
		var err_code: int = packet[8] if packet.size() > 8 else 0
		push_warning("ModbusClient [%s]: Modbus exception response for FC %d (code %d)" % [group_name, fc - 0x80, err_code])
		_active_requests.erase(tx)
		return

	var req_info: Dictionary = _active_requests.get(tx, {})
	_active_requests.erase(tx)

	if fc == 1 or fc == 2: # Read Coils / Discrete Inputs
		if packet.size() < 9:
			return
		var byte_count: int = packet[8]
		var start: int = req_info.get("start", 0)
		var count: int = req_info.get("count", 0)
		var prefix: String = "co" if fc == 1 else "di"

		for i: int in range(count):
			var byte_idx: int = 9 + (i >> 3)
			var bit_idx: int = i % 8
			if byte_idx < packet.size():
				var bit_val: bool = (packet[byte_idx] & (1 << bit_idx)) != 0
				var tag_key: String = prefix + str(start + i)
				var old_val: Variant = _tag_values.get(tag_key, null)
				if old_val != null and bool(old_val) != bit_val:
					print("ModbusClient [%s]: Tag changed '%s' = %s" % [group_name, tag_key, bit_val])
				_tag_values[tag_key] = bit_val

		if not _first_poll_logged:
			_first_poll_logged = true
			print("ModbusClient [%s]: Polling active. Received initial tags: %s" % [group_name, _tag_values])

		tags_polled.emit(group_name)

	elif fc == 3: # Read Holding Registers
		if packet.size() < 9:
			return
		var byte_count: int = packet[8]
		var start: int = req_info.get("start", 0)
		var reg_count: int = byte_count >> 1

		for r: int in range(reg_count):
			var b_idx: int = 9 + r * 2
			if b_idx + 1 < packet.size():
				var word_val: int = (packet[b_idx] << 8) | packet[b_idx + 1]
				var tag_key: String = "hr" + str(start + r)
				_tag_values[tag_key] = word_val

		# Update float32, int32, and int16 tags from holding registers
		for tag: String in _registered_tags:
			var info: Dictionary = _registered_tags[tag]
			if info.get("prefix", "") != "hr":
				continue
			var tag_type: int = int(info.get("type", 0))
			var addr: int = int(info.get("address", 0))
			var rel_r: int = addr - start

			if tag_type == OIPComms.TAG_TYPE_FLOAT32:
				if rel_r >= 0 and rel_r + 1 < reg_count:
					var b_idx: int = 9 + rel_r * 2
					var spb := StreamPeerBuffer.new()
					spb.big_endian = true
					spb.data_array = packet.slice(b_idx, b_idx + 4)
					_tag_values[tag] = spb.get_float()
			elif tag_type == OIPComms.TAG_TYPE_INT32:
				if rel_r >= 0 and rel_r + 1 < reg_count:
					var b_idx: int = 9 + rel_r * 2
					var spb := StreamPeerBuffer.new()
					spb.big_endian = true
					spb.data_array = packet.slice(b_idx, b_idx + 4)
					_tag_values[tag] = spb.get_32()
			elif tag_type == OIPComms.TAG_TYPE_INT16:
				if rel_r >= 0 and rel_r < reg_count:
					var b_idx: int = 9 + rel_r * 2
					var spb := StreamPeerBuffer.new()
					spb.big_endian = true
					spb.data_array = packet.slice(b_idx, b_idx + 2)
					_tag_values[tag] = spb.get_16()

		tags_polled.emit(group_name)


func _parse_tag(tag: String) -> Dictionary:
	var prefix: String = ""
	var num_str: String = ""
	for i: int in range(tag.length()):
		var c: String = tag[i]
		if c >= "0" and c <= "9":
			num_str += c
		else:
			prefix += c
	var addr: int = num_str.to_int() if not num_str.is_empty() else 0
	return {"prefix": prefix.to_lower(), "address": addr}
