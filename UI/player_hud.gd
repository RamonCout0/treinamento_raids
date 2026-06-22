# player_hud.gd — HUD de vida do player (ProgressBar no canto).
extends CanvasLayer

@onready var bar   : ProgressBar = $Health
@onready var label : Label       = $Health/Label


func _ready() -> void:
	EventBus.player_max_health_set.connect(_on_max)
	EventBus.player_health_updated.connect(_on_updated)


func _on_max(max_health) -> void:
	bar.max_value = float(max_health)
	bar.value = float(max_health)
	_update_label()


func _on_updated(current_health) -> void:
	bar.value = clampf(float(current_health), 0.0, bar.max_value)
	_update_label()


func _update_label() -> void:
	if label:
		label.text = "%d / %d" % [int(bar.value), int(bar.max_value)]
