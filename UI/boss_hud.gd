# boss_hud.gd — HUD do boss (nome, vida em barras, stagger, banner de fase).
# Placeholder com ProgressBars simples. Reage ao EventBus.
extends CanvasLayer

@onready var name_label   : Label       = $Name
@onready var bar_label    : Label       = $BarCount
@onready var health_bar   : ProgressBar = $Health
@onready var stagger_bar  : ProgressBar = $Stagger
@onready var banner_label : Label       = $Banner

var hp_per_bar  : float = 1000.0
var total_bars  : int   = 1
var _banner_t   : float = 0.0


func _ready() -> void:
	EventBus.boss_intro.connect(_on_intro)
	EventBus.boss_max_health_set.connect(_on_max)
	EventBus.boss_health_updated.connect(_on_health)
	EventBus.boss_stagger_updated.connect(_on_stagger)
	EventBus.boss_banner.connect(_on_banner)
	banner_label.text = ""
	stagger_bar.value = 0


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			banner_label.text = ""


func _on_intro(n: String) -> void:
	name_label.text = n


func _on_max(max_health, p_hp_per_bar) -> void:
	hp_per_bar = float(p_hp_per_bar)
	if hp_per_bar <= 0.0:
		return
	total_bars = int(ceil(float(max_health) / hp_per_bar))
	health_bar.max_value = hp_per_bar
	health_bar.value = hp_per_bar
	_on_health(max_health)


func _on_health(current_health) -> void:
	if hp_per_bar <= 0.0:
		return
	var hp := float(current_health)
	var bars := int(ceil(hp / hp_per_bar)) if hp > 0.0 else 0
	bar_label.text = str(bars) + "x"
	if hp <= 0.0:
		health_bar.value = 0
	else:
		health_bar.value = hp - float(maxi(bars - 1, 0)) * hp_per_bar


func _on_stagger(cur: float, mx: float) -> void:
	stagger_bar.max_value = mx
	stagger_bar.value = cur


func _on_banner(text: String) -> void:
	banner_label.text = text
	_banner_t = 2.5
