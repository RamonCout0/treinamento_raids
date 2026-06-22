# menu.gd — Seleção de chefe estilo Mega Man clássico (grade 3x3 de retratos).
# Setas navegam · Enter inicia · clique também funciona. Tudo placeholder.
extends Control

const BOSSES := [
	# RAID 1 — Silvanna
	{"short": "EIRA",     "full": "Raid 1, Gate 1 — Eira",         "scene": "res://Arenas/arena_eira.tscn",     "tint": Color(0.55, 0.85, 1.0), "col": 0, "row": 0},
	{"short": "VEX",      "full": "Raid 1, Gate 2 — Vex",          "scene": "res://Arenas/arena_vex.tscn",      "tint": Color(0.60, 0.70, 0.95), "col": 1, "row": 0},
	{"short": "SILVANNA", "full": "Raid 1, BOSS — Silvanna",       "scene": "res://Arenas/arena_silvanna.tscn", "tint": Color(0.70, 0.75, 0.92), "col": 2, "row": 0},
	# RAID 2 — Kael
	{"short": "RENJI",    "full": "Raid 2, Gate 1 — Renji",        "scene": "res://Arenas/arena_renji.tscn",    "tint": Color(0.70, 0.80, 1.00), "col": 0, "row": 1},
	{"short": "HANA",     "full": "Raid 2, Gate 2 — Hana",         "scene": "res://Arenas/arena_hana.tscn",     "tint": Color(0.95, 0.70, 0.50), "col": 1, "row": 1},
	{"short": "KAEL",     "full": "Raid 2, BOSS — Kael",           "scene": "res://Arenas/arena_duelista.tscn", "tint": Color(0.62, 0.62, 0.82), "col": 2, "row": 1},
	# RAID 3 — Gorm
	{"short": "BRUTA",    "full": "Raid 3, Gate 1 — Bruta",        "scene": "res://Arenas/arena_bruta.tscn",    "tint": Color(0.60, 0.55, 0.45), "col": 0, "row": 2},
	{"short": "MYGUR",    "full": "Raid 3, Gate 2 — Mygur",        "scene": "res://Arenas/arena_mygur.tscn",    "tint": Color(0.55, 0.60, 0.35), "col": 1, "row": 2},
	{"short": "GORM",     "full": "Raid 3, BOSS — Gorm",           "scene": "res://Arenas/arena_colosso.tscn",  "tint": Color(0.58, 0.52, 0.42), "col": 2, "row": 2},
	# RAID 4 — Nyx
	{"short": "LIRA",     "full": "Raid 4, Gate 1 — Lira",         "scene": "res://Arenas/arena_lira.tscn",     "tint": Color(0.70, 0.50, 1.00), "col": 0, "row": 3},
	{"short": "MIRIO",    "full": "Raid 4, Gate 2 — Mirio",        "scene": "res://Arenas/arena_mirio.tscn",    "tint": Color(0.55, 0.45, 0.90), "col": 1, "row": 3},
	{"short": "NYX",      "full": "Raid 4, BOSS — Nyx",            "scene": "res://Arenas/arena_tecela.tscn",   "tint": Color(0.62, 0.35, 0.82), "col": 2, "row": 3},
	# RAID 5 — Vorth
	{"short": "ASHA",     "full": "Raid 5, Gate 1 — Asha",         "scene": "res://Arenas/arena_asha.tscn",     "tint": Color(1.00, 0.55, 0.20), "col": 0, "row": 4},
	{"short": "KARVA",    "full": "Raid 5, Gate 2 — Karva",        "scene": "res://Arenas/arena_karva.tscn",    "tint": Color(0.85, 0.30, 0.15), "col": 1, "row": 4},
	{"short": "VORTH",    "full": "Raid 5, BOSS — Vorth",          "scene": "res://Arenas/arena_devorador.tscn","tint": Color(0.82, 0.28, 0.32), "col": 2, "row": 4},
]

const GX := 110.0  # origem x da grade
const GY := 36.0   # origem y da grade
const CW := 84.0   # largura da célula
const CH := 36.0   # altura da célula
const GAPX := 6.0
const GAPY := 4.0

var _sel := 0
var _highlight : Panel
var _full_label : Label
var _blink := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.08)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_add_label("R A I D O", 0, 6, 480, 16, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("PRESS START — SELECIONE O CHEFE", 0, 22, 480, 12, HORIZONTAL_ALIGNMENT_CENTER)

	# Células dos chefes (grade 3 colunas × 5 linhas = 15 entradas).
	for i in BOSSES.size():
		_make_boss_cell(i)

	# Realce da seleção (cursor: borda branca que pisca, estilo Mega Man).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1)
	_highlight = Panel.new()
	_highlight.add_theme_stylebox_override("panel", sb)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight)

	# Nome completo do chefe selecionado.
	_full_label = _add_label("", 0, 234, 480, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("←→↑↓ mover · Enter iniciar · Esc lobby", 0, 250, 480, 12, HORIZONTAL_ALIGNMENT_CENTER)

	_update_selection()
	AudioManager.play_music(AudioManager.menu_music)


func _process(delta: float) -> void:
	_blink += delta
	if _highlight:
		_highlight.modulate.a = 0.4 + 0.6 * (sin(_blink * 8.0) * 0.5 + 0.5)


func _cell_pos(col: int, row: int) -> Vector2:
	return Vector2(GX + col * (CW + GAPX), GY + row * (CH + GAPY))


func _make_boss_cell(i: int) -> void:
	var b = BOSSES[i]
	var p := _cell_pos(b["col"], b["row"])

	# moldura
	var frame := ColorRect.new()
	frame.position = p
	frame.size = Vector2(CW, CH)
	frame.color = Color(0.15, 0.16, 0.22)
	add_child(frame)

	# retrato (placeholder = cor do chefe; troque por arte depois)
	var face := ColorRect.new()
	face.position = p + Vector2(3, 3)
	face.size = Vector2(CW - 6, CH - 18)
	face.color = b["tint"]
	add_child(face)

	var num := Label.new()
	num.text = str(i + 1)
	num.position = p + Vector2(3, 3)
	num.size = Vector2(CW - 6, CH - 18)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(num)

	# barra de nome
	var bar := ColorRect.new()
	bar.position = p + Vector2(3, CH - 14)
	bar.size = Vector2(CW - 6, 12)
	bar.color = Color(0.08, 0.08, 0.12)
	add_child(bar)

	var name_lbl := Label.new()
	name_lbl.text = b["short"]
	name_lbl.position = p + Vector2(3, CH - 15)
	name_lbl.size = Vector2(CW - 6, 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(name_lbl)

	# clique do mouse seleciona/inicia
	var btn := Button.new()
	btn.flat = true
	btn.position = p
	btn.size = Vector2(CW, CH)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_click.bind(i))
	add_child(btn)


func _add_label(text: String, x: float, y: float, w: float, h: float, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		RaidManager.return_to_lobby()
		return
	if event.is_action_pressed("ui_left"):
		_move(-1, 0)
	elif event.is_action_pressed("ui_right"):
		_move(1, 0)
	elif event.is_action_pressed("ui_up"):
		_move(0, -1)
	elif event.is_action_pressed("ui_down"):
		_move(0, 1)
	elif event.is_action_pressed("ui_accept"):
		_launch(_sel)


func _move(dx: int, dy: int) -> void:
	var cur = BOSSES[_sel]
	var best := -1
	var best_score := 9999
	for i in BOSSES.size():
		if i == _sel:
			continue
		var b = BOSSES[i]
		var ddx : int = b["col"] - cur["col"]
		var ddy : int = b["row"] - cur["row"]
		if dx != 0 and (signi(ddx) != dx or ddy != 0):
			continue
		if dy != 0 and (signi(ddy) != dy or ddx != 0):
			continue
		var score : int = abs(ddx) + abs(ddy)
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_sel = best
		_update_selection()


func _update_selection() -> void:
	var b = BOSSES[_sel]
	var p := _cell_pos(b["col"], b["row"])
	_highlight.position = p - Vector2(2, 2)
	_highlight.size = Vector2(CW + 4, CH + 4)
	_full_label.text = b["full"]


func _on_click(i: int) -> void:
	if i == _sel:
		_launch(i)
	else:
		_sel = i
		_update_selection()


func _launch(i: int) -> void:
	# Modo treino: 1 boss isolado (não entra na sequência da raid).
	RaidManager.play_single(BOSSES[i]["scene"])
