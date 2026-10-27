extends CharacterBody2D

signal diajak_bicara
@export var potret: Texture2D

func _ready():
	input_event.connect(_on_input_event)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		diajak_bicara.emit()
