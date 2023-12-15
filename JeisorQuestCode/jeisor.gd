# Author(s): Dylan Turner <dylan.turner@tutanota.com>
# Description: Player control

extends CharacterBody3D
class_name Jeisor

const MOVE_SPD := 8.0
const HOP_SPD := 6.0
const HOP_LAT_SPD := 6.0
const HOP_ROLL_SPD := 8.0
const HOP_ROLL_LAT_SPD := 10.0
const MODEL_TURN_WEIGHT := 12.0
const SWORD_STOP_WEIGHT := 3.0
const TARGET_DISTANCE := 55.0
const BREAK_TARGET_DISTANCE := 90.0
const FOCUS_MOVE_SPD := 5.0
const SIDESTEP_SPD := 5.0
const SIDESTEP_LAT_SPD := 8.0
const SIDESTEP_DELAY := 0.3
const ROLL_SPD := 14.0
const ROLL_DELAY := 0.3
const FOCUS_INDIC_HEIGHT := 3.1

enum CamState {
	Normal,
	Focused,
	Free,
	Dialog
}

@export var cam: Camera = null

@onready var model: Node3D = $JeisorModel
@onready var anim: AnimationPlayer = $JeisorModel/AnimationPlayer
var cam_state := CamState.Normal
var can_target: Targetable = null
var curr_target: Targetable = null
var sidestep_reset_timer := 0.0
var roll_reset_timer := 0.0

@onready var _focus_indic_on := $FocusIndicatorOn
@onready var _focus_indic_off := $FocusIndicatorOff
@onready var _sword_anim := $SwordStrikes
var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _last_ground := Vector3.ZERO
var _last_fwd := Vector3.ZERO
var _just_left_ground := true
var _dialog_ind: int = 0

func _physics_process(delta: float) -> void:
	if cam == null:
		printerr("Camera not attached to player!")
		return
	_handle_target_indicator()
	_fall(delta)
	match cam_state:
		CamState.Normal:
			_animate_normal_cam()
			_move_normal_cam(delta)
			if Input.is_action_just_pressed('lock_on'):
				curr_target = null
				var closest_targetable: Targetable = null
				var closest_targetable_dist := INF
				for child in get_tree().current_scene.get_children():
					if child is Targetable:
						var dist: float = child.global_transform.origin.distance_squared_to(
							global_transform.origin
						)
						if dist < TARGET_DISTANCE && dist < closest_targetable_dist:
							closest_targetable = child
							closest_targetable_dist = dist
					for subchild in child.get_children():
						if subchild is Targetable:
							var dist: float = subchild.global_transform.origin.distance_squared_to(
								global_transform.origin
							)
							if dist < TARGET_DISTANCE && dist < closest_targetable_dist:
								closest_targetable = subchild
								closest_targetable_dist = dist
				if closest_targetable != null:
					curr_target = closest_targetable
				cam.focus_bar_anim.play('Focus')
				cam_state = CamState.Focused
			if DualInputManagement.cam_dir().length() > 0.2:
				cam_state = CamState.Free
		CamState.Focused:
			_animate_focused_cam()
			_move_focused_cam(delta)
			if !Input.is_action_pressed('lock_on'):
				cam.focus_bar_anim.play('Unfocus')
				cam_state = CamState.Normal
			if curr_target != null && curr_target is Npc && Input.is_action_just_pressed('action'):
				cam.dialog_obj = curr_target
				cam.dialog_text = (curr_target as Npc).text[0]
				cam_state = CamState.Dialog
				cam.focus_bar_anim.play('Unfocus')
		CamState.Free:
			_animate_free_cam()
			_move_free_cam(delta)
			if Input.is_action_just_pressed('lock_on'):
				curr_target = null
				var closest_targetable: Targetable = null
				var closest_targetable_dist := INF
				for child in get_tree().current_scene.get_children():
					if child is Targetable:
						var dist: float = child.global_transform.origin.distance_squared_to(
							global_transform.origin
						)
						if dist < TARGET_DISTANCE && dist < closest_targetable_dist:
							closest_targetable = child
							closest_targetable_dist = dist
					for subchild in child.get_children():
						if subchild is Targetable:
							var dist: float = subchild.global_transform.origin.distance_squared_to(
								global_transform.origin
							)
							if dist < TARGET_DISTANCE && dist < closest_targetable_dist:
								closest_targetable = subchild
								closest_targetable_dist = dist
				if closest_targetable != null:
					curr_target = closest_targetable
				cam.focus_bar_anim.play('Focus')
				cam_state = CamState.Focused
		CamState.Dialog:
			velocity = Vector3.ZERO
			if cam.dialog_obj != null:
				var cam_pos := Vector2(
					cam.dialog_obj.global_transform.origin.x,
					cam.dialog_obj.global_transform.origin.z
				)
				var my_pos := Vector2(global_transform.origin.x, global_transform.origin.z)
				var diff := cam_pos - my_pos
				model.rotation_degrees.y = -rad_to_deg(diff.angle()) + 90
			anim.play('Idle')
			if Input.is_action_just_pressed('action'):
				if _dialog_ind + 1 < len((curr_target as Npc).text):
					_dialog_ind += 1
					cam.dialog_text = (curr_target as Npc).text[_dialog_ind]
					cam.dialog_view.text = ''
					cam.dialog_text_counter = 0.0
					cam.dialog_text_ind = 0
				else:
					_dialog_ind = 0
					cam_state = CamState.Normal
	move_and_slide()

func _move_normal_cam(delta: float) -> void:
	if anim.current_animation == 'HSlice' || anim.current_animation == 'VSlice' \
	|| anim.current_animation == 'Stab':
		velocity.x = lerp(velocity.x, 0.0, SWORD_STOP_WEIGHT * delta)
		velocity.z = lerp(velocity.z, 0.0, SWORD_STOP_WEIGHT * delta)
	elif anim.current_animation == 'Roll':
		pass
	elif is_on_floor():
		var stick_dir := DualInputManagement.stick_dir()
		
		var dir := Vector3(stick_dir.x, 0.0, stick_dir.y)
		
		# Rotate around camera. Note that -z is treated as "forward"
		var angle = deg_to_rad(cam.rotation_degrees.y)
		dir = dir.rotated(Vector3.UP, angle)
		
		# Check for pivot
		#var floor_dir = Vector2(velocity.x, velocity.z)
		#var stick_floor_dir = Vector2(dir.x, dir.z)
		#if floor_dir.dot(-stick_floor_dir) > 0:
		#	anim.play('RunPivot')
		#elif !(anim.is_playing() && anim.current_animation == 'RunPivot') \
		#&& 
		if stick_dir.length() > 0.1: # Otherwise turn towards movement
			model.rotation_degrees.y = rad_to_deg(lerp_angle(
				deg_to_rad(model.rotation_degrees.y),
				PI / 2 - Vector2(stick_dir.x, stick_dir.y).angle() + angle,
				MODEL_TURN_WEIGHT * delta
			))
		
		if Input.is_action_just_pressed('sword'):
			anim.play('HSlice')
			_sword_anim.play('HSlice')
		
		if Input.is_action_just_pressed('action') && dir.length() > 0.5 && roll_reset_timer <= 0.0:
			anim.play('Roll')
			roll_reset_timer = ROLL_DELAY
			var move_vel = dir.normalized() * ROLL_SPD
			velocity.x = move_vel.x
			velocity.z = move_vel.z
			sidestep_reset_timer = 0.0
			return
		roll_reset_timer -= delta
		
		# Move
		var move_vel = dir * MOVE_SPD
		velocity.x = move_vel.x
		velocity.z = move_vel.z

func _move_focused_cam(delta: float) -> void:
	if anim.current_animation == 'Roll':
		if Input.is_action_just_pressed('action') \
		&& sidestep_reset_timer <= 0.0:
			# Fake roll hopping glitch for speedrunners
			anim.play('Idle')
			sidestep_reset_timer = SIDESTEP_DELAY
			_just_left_ground = true
			velocity.y = SIDESTEP_SPD
			velocity.x *= 1.1
			velocity.z *= 1.1
			roll_reset_timer = 0.0
			return
	elif anim.current_animation == 'HSlice' || anim.current_animation == 'VSlice' \
	|| anim.current_animation == 'Stab':
		velocity.x = lerp(velocity.x, 0.0, SWORD_STOP_WEIGHT * delta)
		velocity.z = lerp(velocity.z, 0.0, SWORD_STOP_WEIGHT * delta)
	elif is_on_floor():
		var stick_dir := DualInputManagement.stick_dir()
		var dir := Vector3(stick_dir.x, 0.0, stick_dir.y).rotated(
			Vector3.UP, deg_to_rad(model.rotation_degrees.y + 180)
		)
		if curr_target != null:
			if  curr_target.global_transform.origin.distance_squared_to(global_transform.origin) \
					>= BREAK_TARGET_DISTANCE:
				curr_target = null
				cam_state = CamState.Normal
				cam.focus_bar_anim.play('Unfocus')
				return
			var target_dir = curr_target.global_transform.origin - global_transform.origin
			target_dir.y = 0
			var angle_to = target_dir.signed_angle_to(Vector3(0, 0, -1), Vector3.UP)
			dir = Vector3(stick_dir.x, 0.0, stick_dir.y).rotated(Vector3.UP, -angle_to)
			model.rotation_degrees.y = -(rad_to_deg(angle_to) + 180)
		
		if Input.is_action_just_pressed('sword') && stick_dir.y < -0.5 && abs(stick_dir.x) < 0.5:
			anim.play('Stab')
			_sword_anim.play('Stab')
		elif Input.is_action_just_pressed('sword'):
			anim.play('VSlice')
			_sword_anim.play('VSlice')
		
		# Dodge by hopping
		if Input.is_action_just_pressed('action') && dir.length() > 0.5 \
		&& sidestep_reset_timer <= 0.0:
			anim.play('Idle')
			_just_left_ground = true
			velocity = Vector3.UP * SIDESTEP_SPD + dir.normalized() * SIDESTEP_LAT_SPD
			sidestep_reset_timer = SIDESTEP_DELAY
			return
		if sidestep_reset_timer > 0.0:
			sidestep_reset_timer -= delta
		
		var move_vel = dir * FOCUS_MOVE_SPD
		velocity.x = move_vel.x
		velocity.z = move_vel.z

func _move_free_cam(delta: float) -> void:
	if anim.current_animation == 'HSlice' || anim.current_animation == 'VSlice' \
	|| anim.current_animation == 'Stab':
		velocity.x = lerp(velocity.x, 0.0, SWORD_STOP_WEIGHT * delta)
		velocity.z = lerp(velocity.z, 0.0, SWORD_STOP_WEIGHT * delta)
	elif anim.current_animation == 'Roll':
		pass
	elif is_on_floor():
		var stick_dir := DualInputManagement.stick_dir()
		var dir := Vector3(stick_dir.x, 0.0, stick_dir.y)
		
		# Rotate around camera. Note that -z is treated as "forward"
		var angle = deg_to_rad(cam.rotation_degrees.y)
		dir = dir.rotated(Vector3.UP, angle)
		
		# Check for pivot
		#var floor_dir = Vector2(velocity.x, velocity.z)
		#var stick_floor_dir = Vector2(dir.x, dir.z)
		#if floor_dir.dot(-stick_floor_dir) > 0:
		#	anim.play('RunPivot')
		#elif !(anim.is_playing() && anim.current_animation == 'RunPivot') \
		#&& 
		if stick_dir.length() > 0.1: # Otherwise turn towards movement
			model.rotation_degrees.y = rad_to_deg(lerp_angle(
				deg_to_rad(model.rotation_degrees.y),
				PI / 2 - Vector2(stick_dir.x, stick_dir.y).angle() + angle,
				MODEL_TURN_WEIGHT * delta
			))
		
		if Input.is_action_just_pressed('sword'):
			anim.play('HSlice')
			_sword_anim.play('HSlice')
		
		if Input.is_action_just_pressed('action') && dir.length() > 0.5 && roll_reset_timer <= 0.0:
			anim.play('Roll')
			roll_reset_timer = ROLL_DELAY
			var move_vel = dir * ROLL_SPD
			velocity.x = move_vel.x
			velocity.z = move_vel.z
			return
		roll_reset_timer -= delta
		
		# Move
		var move_vel = dir * MOVE_SPD
		velocity.x = move_vel.x
		velocity.z = move_vel.z

func _animate_normal_cam() -> void:
	#var stick_dir = DualInputManagement.stick_dir()
	if anim.current_animation == 'HSlice' || anim.current_animation == 'VSlice' \
	|| anim.current_animation == 'Stab':
		pass
	elif anim.current_animation == 'Roll':
		pass
	elif is_on_floor() && abs(velocity.x) < 0.2 && abs(velocity.z) < 0.2:
		if !anim.is_playing() || anim.current_animation != 'Idle':
			anim.play('Idle')
	elif is_on_floor() && Vector2(velocity.x, velocity.z).length() < MOVE_SPD * 0.6:
		if anim.current_animation == 'Idle':
			anim.play('MoveTransition')
		elif anim.current_animation == 'Run':
			anim.play('Walk')
		elif !anim.is_playing() && anim.current_animation != 'MoveTransition':
			anim.play('Walk')
	#elif anim.is_playing() && anim.current_animation == 'RunPivot':
	#	pass
	#elif is_on_floor() && abs(stick_dir.x) > abs(stick_dir.y) && abs(stick_dir.x) > 0.2:
	#	if anim.current_animation == 'Idle':
	#		anim.play('MoveTransition')
	#	elif sign(stick_dir.x) < 0 && (
	#		!anim.is_playing() || anim.current_animation != 'RunTurnLeft'
	#	):
	#		anim.play('RunTurnLeft')
	#	elif sign(stick_dir.x) > 0 && (
	#		!anim.is_playing() || anim.current_animation != 'RunTurnRight'
	#	):
	#		anim.play('RunTurnRight')
	elif is_on_floor():
		if anim.current_animation == 'Idle':
			anim.play('MoveTransition')
		elif !anim.is_playing() || anim.current_animation != 'Run':
			anim.play('Run', -1, 2.0)

func _animate_focused_cam() -> void:
	if anim.current_animation == 'HSlice' || anim.current_animation == 'VSlice' \
	|| anim.current_animation == 'Stab' || anim.current_animation == 'Roll':
		if curr_target != null:
			var target_dir = curr_target.global_transform.origin - global_transform.origin
			target_dir.y = 0
			var angle_to = target_dir.signed_angle_to(Vector3(0, 0, -1), Vector3.UP)
			model.rotation_degrees.y = -(rad_to_deg(angle_to) + 180)
	elif is_on_floor() && abs(velocity.x) < 0.2 && abs(velocity.z) < 0.2:
		if !anim.is_playing() || anim.current_animation != 'Idle':
			anim.play('Idle')
	elif is_on_floor():
		var stick_dir = DualInputManagement.stick_dir()
		if abs(stick_dir.x) < abs(stick_dir.y):
			if stick_dir.y < 0:
				anim.play('Walk', 0.5)
			else:
				anim.play('WalkBack', 0.5)
		else:
			if stick_dir.x < 0:
				anim.play('WalkLeft', 0.5)
			else:
				anim.play('WalkRight', 0.5)

func _animate_free_cam() -> void:
	if anim.current_animation == 'HSlice' || anim.current_animation == 'VSlice' \
	|| anim.current_animation == 'Stab':
		pass
	elif anim.current_animation == 'Roll':
		pass
	elif is_on_floor() && abs(velocity.x) < 0.2 && abs(velocity.z) < 0.2:
		if !anim.is_playing() || anim.current_animation != 'Idle':
			anim.play('Idle')
	elif is_on_floor() && Vector2(velocity.x, velocity.z).length() < MOVE_SPD * 0.6:
		if anim.current_animation == 'Idle':
			anim.play('MoveTransition')
		elif anim.current_animation == 'Run':
			anim.play('Walk')
		elif !anim.is_playing() && anim.current_animation != 'MoveTransition':
			anim.play('Walk')
	#elif anim.is_playing() && anim.current_animation == 'RunPivot':
	#	pass
	elif is_on_floor():
		if anim.current_animation == 'Idle':
			anim.play('MoveTransition')
		elif !anim.is_playing() || anim.current_animation != 'Run':
			#anim.play('RunForward')
			anim.play('Run', -1, 2.0)

# Jump logic
# If on a platform, keep track of position in case of fall
# If just left a platform, perform a quick hop
# Then fall
func _fall(delta: float) -> void:
	velocity.y -= _grav * delta
	#print(velocity.y)
	if is_on_floor():
		_last_ground = global_transform.origin
		_last_fwd = Vector3(velocity.x, 0.0, velocity.z)
		_just_left_ground = false
	else:
		if !_just_left_ground:
			if cam_state == CamState.Focused \
			&& model.global_transform.basis.z.normalized().dot(
				Vector3(velocity.x, 0, velocity.z).normalized()
			) < 0.0:
				_just_left_ground = true
			else:
				_just_left_ground = true
				if anim.current_animation == 'Roll':
					velocity = Vector3.UP * HOP_ROLL_SPD \
						+ model.global_transform.basis.z.normalized() * HOP_ROLL_LAT_SPD
				else:
					velocity = Vector3.UP * HOP_SPD \
						+ model.global_transform.basis.z.normalized() * HOP_LAT_SPD
					anim.play('Hop')
		if global_transform.origin.y < -10.0:
			velocity = Vector3.ZERO
			var back = -_last_fwd.normalized()
			back.y = 0
			global_transform.origin = _last_ground + back
		if cam_state == CamState.Focused && curr_target != null:
			var target_dir = curr_target.global_transform.origin - global_transform.origin
			target_dir.y = 0
			var angle_to = target_dir.signed_angle_to(Vector3(0, 0, -1), Vector3.UP)
			model.rotation_degrees.y = -(rad_to_deg(angle_to) + 180)

func _handle_target_indicator() -> void:
	_focus_indic_on.global_rotation_degrees = Vector3.ZERO
	_focus_indic_off.global_rotation_degrees = Vector3.ZERO
	if cam_state != CamState.Focused:
		_focus_indic_off.visible = false
		_focus_indic_on.visible = false
		var closest_targetable: Targetable = null
		var closest_targetable_dist := INF
		for child in get_tree().current_scene.get_children():
			if child is Targetable:
				var dist: float = child.global_transform.origin.distance_squared_to(
					global_transform.origin
				)
				if dist < TARGET_DISTANCE && dist < closest_targetable_dist:
					closest_targetable = child
					closest_targetable_dist = dist
			for subchild in child.get_children():
				if subchild is Targetable:
					var dist: float = subchild.global_transform.origin.distance_squared_to(
						global_transform.origin
					)
					if dist < TARGET_DISTANCE && dist < closest_targetable_dist:
						closest_targetable = subchild
						closest_targetable_dist = dist
		if closest_targetable != null:
			_focus_indic_off.visible = true
			_focus_indic_off.global_transform.origin = \
				closest_targetable.global_transform.origin + Vector3.UP * FOCUS_INDIC_HEIGHT
	else:
		_focus_indic_off.visible = false
		_focus_indic_on.visible = false
		if curr_target != null:
			_focus_indic_on.visible = true
			_focus_indic_on.global_transform.origin = \
				curr_target.global_transform.origin + Vector3.UP * FOCUS_INDIC_HEIGHT
