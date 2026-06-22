# cinematic_hud.gd
# ============================================================================
# HUD cinematográfico (CanvasLayer alto). Trata DOIS eventos do EventBus:
#
#   boss_intro_cine(name, epithet, color)
#     -> escurece a tela, mostra um RETRATO grande (cor do boss),
#        o NOME e o EPÍTETO. Fade in/out, ~2.5s.
#
#   mechanic_announce(text, kind, color)
#     -> "card" colorido descendo do topo:
#          kind "phase" -> azul (mudança de fase)
#          kind "mech"  -> branco/cor (mecânica nomeada)
#          kind "gate"  -> dourado (portão de stagger — quebre!)
#          kind "wipe"  -> vermelho (atenção máxima — defenda!)
#
# Esta cena é instanciada em cada arena (depois do BossHUD), via arena.gd.
# Sem dependências externas — usa só Tween + Control nodes (placeholder).
# ============================================================================
extends CanvasLayer

# --- nós da intro (escurecimento + retrato + textos) ---
var _intro_layer : Control
var _intro_dim   : ColorRect
var _intro_box   : Panel
var _intro_card  : ColorRect
var _intro_name  : Label
var _intro_epi   : Label
var _intro_tween : Tween

# --- nós do anúncio de mecânica (card escorregando) ---
var _card_root   : Control
var _card_box    : Panel
var _card_label  : Label
var _card_kind   : Label
var _card_tween  : Tween


func _ready() -> void:
	layer = 50    # sempre por cima
	_build_intro()
	_build_card()
	EventBus.boss_intro_cine.connect(_on_intro)
	EventBus.mechanic_announce.connect(_on_announce)


# =============================================================================
# INTRO DO BOSS
# =============================================================================
func _build_intro() -> void:
	_intro_layer = Control.new()
	_intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.visible = false
	add_child(_intro_layer)

	_intro_dim = ColorRect.new()
	_intro_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_dim.color = Color(0, 0, 0, 0)
	_intro_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(_intro_dim)

	# Caixa central com retrato colorido + nome + epíteto
	_intro_box = Panel.new()
	_intro_box.position = Vector2(40, 80)
	_intro_box.size     = Vector2(400, 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.85)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.6)
	_intro_box.add_theme_stylebox_override("panel", sb)
	_intro_box.modulate.a = 0.0
	_intro_layer.add_child(_intro_box)

	_intro_card = ColorRect.new()
	_intro_card.position = Vector2(12, 12)
	_intro_card.size     = Vector2(78, 86)
	_intro_card.color    = Color(0.6, 0.6, 0.7)
	_intro_box.add_child(_intro_card)

	_intro_name = Label.new()
	_intro_name.position = Vector2(102, 18)
	_intro_name.size     = Vector2(286, 26)
	_intro_name.add_theme_font_size_override("font_size", 18)
	_intro_name.add_theme_color_override("font_color", Color(1, 1, 1))
	_intro_box.add_child(_intro_name)

	_intro_epi = Label.new()
	_intro_epi.position = Vector2(102, 52)
	_intro_epi.size     = Vector2(286, 40)
	_intro_epi.autowrap_mode = TextServer.AUTOWRAP_WORD
	_intro_epi.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_intro_box.add_child(_intro_epi)


func _on_intro(boss_name: String, epithet: String, color: Color) -> void:
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_layer.visible = true
	_intro_name.text = boss_name
	_intro_epi.text  = epithet
	_intro_card.color = color
	_intro_dim.color = Color(0, 0, 0, 0)
	_intro_box.modulate.a = 0.0
	_intro_box.position.x = 30   # entra deslizando

	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(_intro_dim, "color", Color(0, 0, 0, 0.55), 0.35)
	_intro_tween.tween_property(_intro_box, "modulate:a", 1.0, 0.35)
	_intro_tween.tween_property(_intro_box, "position:x", 40.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# segura ~2.0s e depois fade-out
	_intro_tween.chain().tween_interval(2.0)
	_intro_tween.chain().set_parallel(true)
	_intro_tween.tween_property(_intro_dim, "color", Color(0, 0, 0, 0), 0.6)
	_intro_tween.tween_property(_intro_box, "modulate:a", 0.0, 0.6)
	_intro_tween.chain().tween_callback(func(): _intro_layer.visible = false)


# =============================================================================
# CARD DE MECÂNICA (entra do topo, segura, desaparece)
# =============================================================================
func _build_card() -> void:
	_card_root = Control.new()
	_card_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_root)

	_card_box = Panel.new()
	_card_box.position = Vector2(40, -40)   # começa escondido (fora da tela)
	_card_box.size     = Vector2(400, 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.8)
	_card_box.add_theme_stylebox_override("panel", sb)
	_card_root.add_child(_card_box)

	_card_kind = Label.new()
	_card_kind.position = Vector2(8, 4)
	_card_kind.size     = Vector2(60, 20)
	_card_kind.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_card_box.add_child(_card_kind)

	_card_label = Label.new()
	_card_label.position = Vector2(72, 4)
	_card_label.size     = Vector2(316, 20)
	_card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_card_box.add_child(_card_label)


func _on_announce(text: String, kind: String, color: Color) -> void:
	if _card_tween and _card_tween.is_running():
		_card_tween.kill()
	# borda colorida muda por categoria
	var sb := _card_box.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color = color
	_card_kind.add_theme_color_override("font_color", color)
	_card_kind.text  = _kind_tag(kind)
	_card_label.text = text
	_card_box.position = Vector2(40, -40)

	_card_tween = create_tween()
	_card_tween.tween_property(_card_box, "position:y", 50.0, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_interval(2.0)
	_card_tween.tween_property(_card_box, "position:y", -40.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _kind_tag(kind: String) -> String:
	match kind:
		"phase": return "[FASE]"
		"gate":  return "[PORTÃO]"
		"wipe":  return "[!!]"
		_:       return "[MEC]"
