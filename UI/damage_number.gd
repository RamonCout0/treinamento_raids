# damage_number.gd — número flutuante (Label2D que sobe e desaparece).
# Instanciado pelo GameFeel.spawn_damage_number(). Auto-destrói no fim.
extends Node2D

@onready var label : Label = $Label

const RISE  := 22.0   # pixels que sobe
const LIFE  := 0.65   # segundos antes de morrer


func setup(amount: int, color: Color = Color(1.0, 0.95, 0.4), text_override: String = "") -> void:
	# Tem que esperar _ready se chamado antes (instantiate + add_child + setup).
	if label == null:
		await ready
	label.text = text_override if text_override != "" else str(amount)
	label.add_theme_color_override("font_color", color)


func _ready() -> void:
	z_index = 100
	var start := position
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", start.y - RISE, LIFE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, LIFE).set_delay(LIFE * 0.4)
	t.chain().tween_callback(queue_free)
