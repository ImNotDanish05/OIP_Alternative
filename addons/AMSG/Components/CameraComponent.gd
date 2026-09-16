extends Node
class_name CameraComponent
## Script used to control the camera for the player

@export var networking : PlayerNetworkingComponent
#####################################
#Refrences
@export var SpringArm : SpringArm3D
@export var Camera : Camera3D
@export var PlayerRef : CharacterMovementComponent
@onready var HObject = SpringArm
@onready var VObject = SpringArm
#####################################

var CameraHOffset := 0.0
@export var view_angle : Global.view_angle = Global.view_angle.right_shoulder:
	get: return view_angle
	set(Newview_angle):
#		if view_mode == Global.view_mode.first_person:
#			return
		view_angle = Newview_angle
		if Camera:
			match Newview_angle:
				Global.view_angle.right_shoulder:
					CameraHOffset = 0.45
					update_camera_offset()
				Global.view_angle.left_shoulder:
					CameraHOffset = -0.45
					update_camera_offset()
				Global.view_angle.head:
					CameraHOffset = 0.0
					update_camera_offset()

			
@export var view_mode : Global.view_mode = Global.view_mode.first_person :
	get: return view_mode
	set(Newview_mode):
		view_mode = Newview_mode
		if VObject:
			VObject.rotation.x = 0.0
		if SpringArm:
			match view_mode:
				Global.view_mode.first_person:
					view_angle = Global.view_angle.head
					if PlayerRef:
						PlayerRef.rotation_mode = Global.rotation_mode.looking_direction
					SpringArm.spring_length = -0.4
					VObject = Camera
				Global.view_mode.third_person:
					SpringArm.spring_length = 3.5
					VObject = SpringArm
		update_capsule_visibility()


var camera_h : float = 0
var camera_v : float = 0
@export var camera_vertical_min : float = -90
@export var camera_vertical_max : float = 90

## Assign a [camera_values] resource to it and change its values to tweak camera settings
@export var camera_settings : camera_values
@export var first_person_camera_bone : BoneAttachment3D

var current_fov: float = 90.0
@export var acceleration_h = 10
var acceleration_v = 10

var spring_arm_position_relative_to_player: Vector3
var base_spring_y: float = 1.2
var current_first_person_height: float = 1.6
@export var crouch_camera_drop: float = 0.45
@export var crouch_first_person_drop: float = 0.40
@export var crouch_transition_speed: float = 5.0
@export var fov_walk: float = 75.0
@export var fov_run: float = 82.0
@export var fov_sprint: float = 90.0
var zoom_scroll_offset: float = 0.0
@export var zoom_base_fov: float = 50.0
@export var zoom_min_fov: float = 30.0
@export var zoom_max_fov: float = 75.0

func _ready() -> void:
	if SpringArm:
		spring_arm_position_relative_to_player = SpringArm.position
		base_spring_y = SpringArm.position.y
	else:
		spring_arm_position_relative_to_player = Vector3.ZERO
		base_spring_y = 1.2
	current_first_person_height = 1.6
	zoom_scroll_offset = 0.0
	if SpringArm:
		SpringArm.top_level = true
		var parent_node: Node3D = get_parent() as Node3D
		if parent_node:
			var init_pos: Vector3 = parent_node.global_position + spring_arm_position_relative_to_player if view_mode == Global.view_mode.third_person else parent_node.global_position + Vector3(0, current_first_person_height, 0)
			SpringArm.global_position = init_pos
		match view_mode:
			Global.view_mode.first_person:
				view_angle = Global.view_angle.head
				if PlayerRef:
					PlayerRef.rotation_mode = Global.rotation_mode.looking_direction
				SpringArm.spring_length = -0.4
				VObject = Camera
			Global.view_mode.third_person:
				SpringArm.spring_length = 3.5
				VObject = SpringArm
	set_process_input(true)
	call_deferred("update_capsule_visibility")

func _physics_process(delta: float) -> void:
	if PlayerRef == null or SpringArm == null or Camera == null:
		return
	# Crouch camera drop - smooth lerp for third-person spring offset and first-person height
	if PlayerRef:
		var is_crouching: bool = PlayerRef.stance == Global.stance.crouching and not PlayerRef.is_flying
		var desired_y: float = base_spring_y - (crouch_camera_drop if is_crouching else 0.0)
		spring_arm_position_relative_to_player.y = lerpf(spring_arm_position_relative_to_player.y, desired_y, delta * crouch_transition_speed)
		var desired_first_person_height: float = 1.6 - (crouch_first_person_drop if is_crouching else 0.0)
		current_first_person_height = lerpf(current_first_person_height, desired_first_person_height, delta * crouch_transition_speed)
	if camera_settings and camera_settings.camera_change_fov_on_speed and PlayerRef.actual_velocity.length() > camera_settings.camera_fov_change_starting_speed:
		smooth_fov(current_fov + clampf((PlayerRef.actual_velocity.length()-camera_settings.camera_fov_change_starting_speed)*(camera_settings.camera_max_fov_change/10.0),0,camera_settings.camera_max_fov_change))

	var target_pos: Vector3 = get_parent().global_position + spring_arm_position_relative_to_player if view_mode == Global.view_mode.third_person else (first_person_camera_bone.global_position if first_person_camera_bone else get_parent().global_position + Vector3(0, current_first_person_height, 0))
	var lerp_factor: float = (1.0 / camera_settings.camera_inertia) if view_mode == Global.view_mode.third_person and camera_settings else 1.0
	SpringArm.position = SpringArm.position.lerp(target_pos, lerp_factor)
	
	camera_v = clampf(camera_v, deg_to_rad(camera_vertical_min), deg_to_rad(camera_vertical_max))
	HObject.rotation.y = lerpf(HObject.rotation.y, camera_h, delta * acceleration_h)
	VObject.rotation.x = lerpf(VObject.rotation.x, camera_v, delta * acceleration_v)
	
	# FOV handling - gait-based + zoom override (zoom held with "c" smoothly zooms in)
	var is_zooming: bool = Input.is_action_pressed("zoom") or Input.is_physical_key_pressed(KEY_C)
	var gait_fov: float = fov_walk
	if PlayerRef.gait == Global.gait.running:
		gait_fov = fov_run
	elif PlayerRef.gait == Global.gait.sprinting:
		gait_fov = fov_sprint
	var target_fov: float = gait_fov
	if is_zooming:
		target_fov = clampf(zoom_base_fov + zoom_scroll_offset, zoom_min_fov, zoom_max_fov)
	match PlayerRef.rotation_mode:
		Global.rotation_mode.aiming:
			if PlayerRef.gait == Global.gait.sprinting:
				PlayerRef.gait = Global.gait.running
			smooth_fov(60.0)
		Global.rotation_mode.velocity_direction:
			smooth_fov(target_fov)
		Global.rotation_mode.looking_direction:
			smooth_fov(target_fov)
	update_capsule_visibility()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var is_zoom_held: bool = Input.is_action_pressed("zoom") or Input.is_physical_key_pressed(KEY_C)
		if is_zoom_held:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_scroll_offset = clampf(zoom_scroll_offset - 2.0, zoom_min_fov - zoom_base_fov, zoom_max_fov - zoom_base_fov)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_scroll_offset = clampf(zoom_scroll_offset + 2.0, zoom_min_fov - zoom_base_fov, zoom_max_fov - zoom_base_fov)
				get_viewport().set_input_as_handled()


func update_camera_offset() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(Camera, "h_offset", CameraHOffset, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_EXPO)

func update_capsule_visibility() -> void:
	if PlayerRef == null or PlayerRef.mesh_ref == null:
		return
	var mesh_ref_node: Node = PlayerRef.mesh_ref as Node
	var mesh_instance: MeshInstance3D = null
	if mesh_ref_node is MeshInstance3D:
		mesh_instance = mesh_ref_node as MeshInstance3D
	else:
		mesh_instance = mesh_ref_node.get_node_or_null("Capsule") as MeshInstance3D
		if mesh_instance == null:
			for child: Node in mesh_ref_node.get_children():
				if child is MeshInstance3D:
					mesh_instance = child as MeshInstance3D
					break
	if mesh_instance == null:
		return
	if view_mode == Global.view_mode.first_person:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		# Keep visible true so shadow is cast, mesh not rendered
		mesh_instance.visible = true
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.visible = true

var changing_view := false
func smooth_fov(_current_fov:float):
	current_fov = _current_fov
	if changing_view:
		return
	changing_view=true
	var tween := create_tween()
	tween.tween_property(Camera,"fov",current_fov,0.1)
	tween.tween_callback(func(): changing_view=false)
	
	

func smooth_camera_transition(pos:Vector3, look_at:Vector3, duration:float = 1.0 ,ease:Tween.EaseType = Tween.EASE_IN_OUT, trans:Tween.TransitionType = Tween.TRANS_LINEAR):
#	Camera.global_position = Camera.to_global(Camera.global_position)
	Camera.top_level = true
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(Camera,"position",pos,duration).set_ease(ease).set_trans(trans)
	tween.tween_method(func(arr:Array): Camera.look_at_from_position(arr[0],arr[1]),[Camera.position,look_at],[pos,look_at],duration).set_ease(ease).set_trans(trans)
	
var reseting : bool = false
func reset_camera_transition(smooth_transition: bool = true):
	if Camera.top_level == false:
		return
	if smooth_transition:
		
		if reseting == true:
			return
		reseting = true
		Camera.top_level = false
		var tween := create_tween()
		tween.set_parallel()
		tween.tween_property(Camera,"position",Vector3(0,0,SpringArm.spring_length),1.0)
		tween.tween_property(Camera,"rotation",Vector3.ZERO,1.0)
		tween.tween_callback(func(): reseting=false)
		
	else:
		Camera.rotation = Vector3.ZERO
		Camera.top_level = false
