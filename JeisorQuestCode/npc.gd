# Author(s): Dylan Turner <dylan.turner@tutanota.com>
# Description: Define travel path and dialog for NPCs

extends Targetable

class_name Npc

@export var text: Array[String] = []

@onready var _anim := $AnimationPlayer

func _ready() -> void:
	_anim.play('Idle')
