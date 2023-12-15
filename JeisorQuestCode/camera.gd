# Author(s): Dylan Turner <dylan.turner@tutanota.com>
# Description: Camera system

extends Camera3D
class_name Camera

const FOLLOW_WEIGHT := 4.0
const FOLLOW_HEIGHT := 3.0
const FOLLOW_DIST := 4.0
const NORMAL_RESET_TIME := 3.0
const NORMAL_RESET_WEIGHT := 3.0
const FOCUSED_FOLLOW_HEIGHT := 2.0
const FOCUSED_FOLLOW_WEIGHT := 12.0
const FREE_ROT_SPD := 5.0
const FREE_ROT_FOLLOW_WEIGHT := 24.0
const FREE_HEIGHT_SPD := 8.0
const FREE_MIN_HEIGHT_CHANGE := -3.0
const FREE_MAX_HEIGHT_CHANGE := 2.0
const TEXT_SPD := 100.0

@export var player: Jeisor = null

@onready var focus_bar_anim: AnimationPlayer = $FocusedBarsCanvas/AnimationPlayer
@onready var dialog_view: Label = $UI/DialogBackdrop/Margin/DialogText
var dialog_obj: Npc = null
var dialog_text := ''
var dialog_text_counter := 0.0
var dialog_text_ind: int = 0

@onready var _rot_follower: CamRotationFollower = $CamRotationFollower
@onready var _dialog_backdrop := $UI/DialogBackdrop
@onready var _mode_str: Label = $UI/ModeStr
@onready var _action_str: Label = $UI/ActionStr
@onready var _sword_str: Label = $UI/SwordStr
var _normal_reset_timer := Timer.new()
var _normal_wait := false
var _normal_reset := false
var _rot_offset_x := 0.0
var _rot_height := 0.0

func _ready() -> void:
	_normal_reset_timer.wait_time = NORMAL_RESET_TIME
	_normal_reset_timer.one_shot = true
	add_child(_normal_reset_timer)

func _physics_process(delta: float) -> void:
	if player == null:
		printerr('No player attached to camera!')
		return
	
	_handle_action_str()
	_handle_sword_str()
	match player.cam_state:
		Jeisor.CamState.Normal:
			_mode_str.text = '📷 Normal'
			_normal_mode(delta)
			dialog_view.text = ''
			dialog_text_counter = 0.0
			dialog_text_ind = 0
			_dialog_backdrop.visible = false
		Jeisor.CamState.Focused:
			_mode_str.text = '📷 Focused'
			_focused_mode(delta)
			dialog_view.text = ''
			dialog_text_counter = 0.0
			dialog_text_ind = 0
			_dialog_backdrop.visible = false
		Jeisor.CamState.Free:
			_mode_str.text = '📷 Free'
			_free_mode(delta)
			dialog_view.text = ''
			dialog_text_counter = 0.0
			dialog_text_ind = 0
			_dialog_backdrop.visible = false
		Jeisor.CamState.Dialog:
			_mode_str.text = '📷 Dialog'
			_dialog_backdrop.visible = true
			_dialog_mode(delta)
			if dialog_view.text != dialog_text:
				if dialog_text_counter > 1.0:
					dialog_text_counter = 0.0
					dialog_view.text += dialog_text[dialog_text_ind]
					dialog_text_ind += 1
				dialog_text_counter += delta * TEXT_SPD

func _normal_mode(delta: float) -> void:
	var player_dist := player.global_transform.origin.distance_squared_to(global_transform.origin)
	if player_dist != (FOLLOW_DIST * FOLLOW_DIST):
		var fwd := -_rot_follower.basis.z.normalized()
		fwd.y = 0
		var target := player.global_transform.origin \
			- fwd * FOLLOW_DIST \
			+ Vector3.UP * FOLLOW_HEIGHT
		global_transform.origin = global_transform.origin.lerp(target, FOLLOW_WEIGHT * delta)
	
	if abs(player.velocity.x) > 1.0 || abs(player.velocity.z) > 1.0:
		_normal_reset_timer.stop()
		_normal_wait = false
		_normal_reset = false
	elif _normal_reset_timer.is_stopped() \
	&& -player.global_transform.basis.z != -_rot_follower.basis.z \
	&& !_normal_wait:
		_normal_reset_timer.start()
		_normal_wait = true
	elif _normal_wait && _normal_reset_timer.is_stopped():
		_normal_reset = true
	if _normal_reset:
		var fwd := player.model.global_transform.basis.z.normalized()
		fwd.y = 0
		var target := player.global_transform.origin \
			- fwd * FOLLOW_DIST \
			+ Vector3.UP * FOLLOW_HEIGHT
		global_transform.origin = global_transform.origin.lerp(target, NORMAL_RESET_WEIGHT * delta)
	
	look_at(player.global_transform.origin)
	
	_rot_offset_x = 0.0
	_rot_height = 0.0

func _focused_mode(delta: float) -> void:
	var fwd := player.model.global_transform.basis.z.normalized()
	fwd.y = 0
	var target := player.global_transform.origin \
		- fwd * FOLLOW_DIST \
		+ Vector3.UP * FOCUSED_FOLLOW_HEIGHT
	global_transform.origin = global_transform.origin.lerp(target, FOCUSED_FOLLOW_WEIGHT * delta)
	look_at(player.global_transform.origin)
	
	_rot_offset_x = 0.0
	_rot_height = 0.0

func _free_mode(delta: float) -> void:
	var cam_dir := DualInputManagement.cam_dir()
	
	var fwd := -_rot_follower.basis.z.normalized()
	fwd.y = 0
	fwd = fwd.rotated(Vector3.UP, _rot_offset_x)
	_rot_offset_x += -cam_dir.x * FREE_ROT_SPD * delta
	
	var target := player.global_transform.origin \
		- fwd * (FOLLOW_DIST - _rot_height) \
		+ Vector3.UP * (FOLLOW_HEIGHT + _rot_height)
	_rot_height += cam_dir.y * FREE_HEIGHT_SPD * delta
	_rot_height = clamp(_rot_height, FREE_MIN_HEIGHT_CHANGE, FREE_MAX_HEIGHT_CHANGE)
	global_transform.origin = global_transform.origin.lerp(target, FREE_ROT_FOLLOW_WEIGHT * delta)
	
	look_at(player.global_transform.origin)

func _dialog_mode(delta: float) -> void:
	if dialog_obj == null:
		return
	var center := (dialog_obj.global_transform.origin + player.global_transform.origin) / 2.0
	var fwd := player.model.global_transform.basis.z.normalized()
	fwd.y = 0
	var target := center \
		- fwd.rotated(Vector3.UP, PI / 2) * FOLLOW_DIST \
		+ Vector3.UP * (FOLLOW_HEIGHT + _rot_height)
	global_transform.origin = global_transform.origin.lerp(target, NORMAL_RESET_WEIGHT * delta)
	look_at(center)

func _handle_action_str() -> void:
	_action_str.text = 'No Action'
	var stick_dir = DualInputManagement.stick_dir()
	if player.cam_state == Jeisor.CamState.Dialog:
		_action_str.text = 'Next'
	elif player.cam_state == Jeisor.CamState.Focused && player.curr_target is Npc:
		_action_str.text = 'Talk'
	elif player.cam_state == Jeisor.CamState.Focused && stick_dir.length() > 0.2 \
	&& player.sidestep_reset_timer <= 0.0:
		_action_str.text = 'Sidestep'
	elif player.cam_state != Jeisor.CamState.Focused && stick_dir.length() > 0.2 \
	&& player.roll_reset_timer <= 0.0:
		_action_str.text = 'Roll'

func _handle_sword_str() -> void:
	_sword_str.text = 'Hor. Slice'
	var stick_dir = DualInputManagement.stick_dir()
	if player.cam_state == Jeisor.CamState.Focused && stick_dir.y < -0.5 && abs(stick_dir.x) < 0.5:
		_sword_str.text = 'Stab'
	elif player.cam_state == Jeisor.CamState.Focused:
		_sword_str.text = 'Vert. Slice'
