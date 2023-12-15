# Author(s): Dylan Turner <dylan.turner@tutanota.com>
# Description: Follow the flat 2D direction of camera for use in math stuff

extends Node3D
class_name CamRotationFollower

var _camera: Camera = null

func _ready() -> void:
	_camera = get_parent()
	get_parent().call_deferred('remove_child', self)
	get_tree().current_scene.call_deferred('add_child', self)

func _process(_delta: float) -> void:
	if _camera == get_parent():
		return
	if _camera.player.cam_state != Jeisor.CamState.Free:
		rotation_degrees.x = 0
		rotation_degrees.z = 0
		rotation_degrees.y = _camera.rotation_degrees.y
