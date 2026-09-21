@tool
extends EditorPlugin

var tag_group_enum: TagGroupOptionButtonPlugin = TagGroupOptionButtonPlugin.new()

func _enter_tree() -> void:
	add_inspector_plugin(tag_group_enum)


func _exit_tree() -> void:
	remove_inspector_plugin(tag_group_enum)

class TagGroupOptionButtonPlugin extends EditorInspectorPlugin:
	func _can_handle(object: Object) -> bool:
		return true
	
	func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
		if hint_string == "tag_group_enum" and type in [TYPE_NIL, TYPE_STRING]:
			add_property_editor(name, TagGroupOptionButton.new())
			return true
		return false
		
class TagGroupOptionButton extends EditorProperty:
	var option_button: OptionButton
	
	func _init() -> void:
		option_button = OptionButton.new()
		option_button.flat = true
		option_button.allow_reselect = true
		option_button.clip_text = true
		option_button.fit_to_longest_item = false
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(option_button)
		add_focusable(option_button)
		_populate_options()
		option_button.item_selected.connect(_on_item_selected)
		OIPComms.tag_groups_registered.connect(_tag_groups_registered)
	
	func _on_item_selected(index: int) -> void:
		if index < 0 or index >= option_button.item_count:
			return
		var value := option_button.get_item_text(index)
		if value == "(None)":
			value = ""
		elif value.begins_with("⚠️ "):
			value = value.substr(3)
		var prop := get_edited_property()
		var storage_prop := prop.replace("tag_groups", "tag_group_name")
		var obj := get_edited_object()
		if obj != null:
			obj.set(storage_prop, value)
			obj.set(prop, value)
		emit_changed(prop, value)
		emit_changed(storage_prop, value)
	
	func _get_all_known_groups() -> Array[String]:
		var groups: Array[String] = []
		var comms_groups: Array = OIPComms.get_tag_groups()
		for g: Variant in comms_groups:
			var gname: String = ""
			if g is Dictionary:
				gname = str((g as Dictionary).get("name", ""))
			elif g is String:
				var s: String = (g as String).strip_edges()
				if s.begins_with("{"):
					var parsed: Variant = JSON.parse_string(s)
					if parsed is Dictionary and (parsed as Dictionary).has("name"):
						gname = str((parsed as Dictionary).get("name", ""))
				else:
					gname = s
			if not gname.is_empty() and not gname in groups:
				groups.append(gname)

		# 1. Direct file fallback from res://oip_data/tag_groups.cfg
		var cfg := ConfigFile.new()
		if cfg.load("res://oip_data/tag_groups.cfg") == OK:
			var count: int = cfg.get_value("info", "group_count", 0)
			for i in range(count):
				var gname: String = cfg.get_value("group_" + str(i), "name", "")
				if not gname.is_empty() and not gname in groups:
					groups.append(gname)

		# 2. If OIPComms was empty but tag_groups.cfg had groups, bootstrap OIPComms
		if comms_groups.is_empty() and not groups.is_empty():
			var svc_script: GDScript = load("res://src/comms/oip_comms_service.gd")
			if svc_script != null:
				var svc: Node = svc_script.new()
				if svc != null and svc.has_method("register_tag_groups"):
					svc.register_tag_groups()
				if svc != null:
					svc.free()

		# 3. Preserved value from edited object in scene (prevents disappearing on moved scenes)
		var obj := get_edited_object()
		if obj != null:
			var prop := get_edited_property()
			var storage_prop := prop.replace("tag_groups", "tag_group_name")
			var obj_val: Variant = obj.get(storage_prop)
			if obj_val == null or not obj_val is String or (obj_val as String).is_empty():
				obj_val = obj.get(prop)
			if obj_val is String and not (obj_val as String).is_empty():
				var val_str: String = (obj_val as String).strip_edges()
				if val_str.begins_with("{"):
					var parsed: Variant = JSON.parse_string(val_str)
					if parsed is Dictionary and (parsed as Dictionary).has("name"):
						val_str = str((parsed as Dictionary).get("name", ""))
					else:
						val_str = ""
				if not val_str.is_empty() and not val_str in groups:
					groups.append(val_str)

		return groups

	func _populate_options() -> void:
		option_button.clear()
		option_button.add_item("(None)")
		var groups := _get_all_known_groups()
		for group: String in groups:
			option_button.add_item(group)
		option_button.disabled = false
	
	func _select_current_value() -> void:
		var obj := get_edited_object()
		if obj == null:
			return
		var prop := get_edited_property()
		var storage_prop := prop.replace("tag_groups", "tag_group_name")
		var current_value: Variant = obj.get(storage_prop)
		if current_value == null or not current_value is String or (current_value as String).is_empty():
			current_value = obj.get(prop)
		if current_value == null or not current_value is String or (current_value as String).is_empty():
			option_button.select(0)
			return
		var cur_str: String = (current_value as String).strip_edges()
		if cur_str.begins_with("{"):
			var parsed: Variant = JSON.parse_string(cur_str)
			if parsed is Dictionary and (parsed as Dictionary).has("name"):
				cur_str = str((parsed as Dictionary).get("name", ""))
			else:
				cur_str = ""
			if obj != null:
				obj.set(storage_prop, cur_str)
				obj.set(prop, cur_str)
		if cur_str.is_empty():
			option_button.select(0)
			return
		for i in range(option_button.item_count):
			var item_text := option_button.get_item_text(i)
			if item_text == cur_str:
				option_button.select(i)
				return
		if not cur_str.begins_with("{"):
			option_button.add_item(cur_str)
			var new_index := option_button.item_count - 1
			option_button.select(new_index)
		else:
			option_button.select(0)
	
	func _update_property() -> void:
		_populate_options()
		_select_current_value()
	
	func _tag_groups_registered() -> void:
		_populate_options()
		_select_current_value()
				
