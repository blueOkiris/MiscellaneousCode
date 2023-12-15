extends Targetable

class_name TrainingPost

const RESPAWN_TIME := 2.0

enum RequiredStrike {
	Horizontal,
	Vertical,
	Stab
}

@export var required_strike: RequiredStrike = RequiredStrike.Horizontal

@onready var _anim := $AnimationPlayer
var _respawn_timer := 0.0
var _cut := false
var _jeisor: Jeisor = null

func _ready() -> void:
	_anim.play('Idle')

func _process(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer <= 0.0 && _cut:
		_cut = false
	if !_cut:
		_anim.play('Idle', 0.1)
	
	if _jeisor:
		var jeisor_pos := Vector2(
			_jeisor.global_transform.origin.x,
			_jeisor.global_transform.origin.z
		)
		var my_pos := Vector2(global_transform.origin.x, global_transform.origin.z)
		var diff := jeisor_pos - my_pos
		rotation_degrees.y = -rad_to_deg(diff.angle()) + 90
	else:
		for child in get_tree().current_scene.get_children():
			if child is Jeisor:
				_jeisor = child
				break

func _on_sword_hit(area: Area3D) -> void:
	if _cut:
		return
	var parent := area.get_parent().get_parent() as Jeisor
	match required_strike:
		RequiredStrike.Horizontal:
			if parent.anim.current_animation == 'HSlice':
				_cut = true
				_respawn_timer = RESPAWN_TIME
				_anim.play('Break', 0.01, 4.0)
				await _anim.animation_finished
		RequiredStrike.Vertical:
			if parent.anim.current_animation == 'VSlice':
				_cut = true
				_respawn_timer = RESPAWN_TIME
				_anim.play('Break', 0.01, 4.0)
				await _anim.animation_finished
		RequiredStrike.Stab:
			if parent.anim.current_animation == 'Stab':
				_cut = true
				_respawn_timer = RESPAWN_TIME
				_anim.play('Break', 0.01, 4.0)
				await _anim.animation_finished
