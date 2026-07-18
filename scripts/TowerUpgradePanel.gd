extends PanelContainer

signal upgrade_requested
signal sell_requested
signal close_requested

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var upgrade_button: Button = $VBoxContainer/UpgradeButton
@onready var sell_button: Button = $VBoxContainer/SellButton

var tracked_tower: Node2D = null
var corner_close: Button = null

# Gap in screen pixels between the tower's top and the panel's bottom edge
const PANEL_GAP: float = 16.0


func _ready() -> void:
	upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	sell_button.pressed.connect(func(): sell_requested.emit())
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	style.set_corner_radius_all(6)
	# Inner padding so text/buttons don't touch the border
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	# The panel must swallow clicks so they never reach Main's map handler
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Breathing room between rows (scene edits weren't sticking on the instance)
	if has_node("VBoxContainer"):
		var vb := $VBoxContainer
		vb.add_theme_constant_override("separation", 7)
		# Hug the content: don't stretch to fill leftover vertical space
		vb.custom_minimum_size = Vector2.ZERO
		vb.size = Vector2.ZERO
		vb.alignment = BoxContainer.ALIGNMENT_BEGIN
		vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The panel hugs content vertically but keeps a min width so the close
	# button has room and the layout stays symmetric
	custom_minimum_size = Vector2(150, 0)
	size = Vector2.ZERO

	# Close button, centered at the top of the panel as its own row.
	var x_btn := Button.new()
	x_btn.name = "CornerClose"
	x_btn.text = "✕"  # multiplication X (caption-style glyph)
	x_btn.focus_mode = Control.FOCUS_NONE
	x_btn.flat = true
	x_btn.add_theme_font_size_override("font_size", 12)
	var d: float = 22.0                          # circle diameter
	x_btn.custom_minimum_size = Vector2(d, d)
	x_btn.size = Vector2(d, d)
	x_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Round chip: square button + corner radius = d/2 makes a circle,
	# with a thin ring border like the reference.
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0.20, 0.20, 0.24, 1.0)   # solid dark chip
	rest.set_corner_radius_all(4)                  # square with soft corners
	rest.set_border_width_all(2)
	rest.border_color = Color(0.85, 0.85, 0.90, 1.0)
	x_btn.add_theme_stylebox_override("normal", rest)
	x_btn.add_theme_stylebox_override("focus", rest)

	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.90, 0.16, 0.22, 1.0)
	red.set_corner_radius_all(4)
	red.set_border_width_all(2)
	red.border_color = Color(1.0, 0.6, 0.6, 1.0)
	x_btn.add_theme_stylebox_override("hover", red)
	var red_pressed := StyleBoxFlat.new()
	red_pressed.bg_color = Color(0.75, 0.13, 0.18, 1.0)
	red_pressed.set_corner_radius_all(4)
	x_btn.add_theme_stylebox_override("pressed", red_pressed)

	x_btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))
	x_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	x_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	x_btn.pressed.connect(func(): close_requested.emit())
	corner_close = x_btn
	if has_node("VBoxContainer"):
		# Own row at the top; a spacer shoves the X to the right edge
		var top_row := HBoxContainer.new()
		top_row.name = "TopRow"
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(spacer)
		top_row.add_child(x_btn)
		$VBoxContainer.add_child(top_row)
		$VBoxContainer.move_child(top_row, 0)

	visible = false


func show_for_tower(tower) -> void:
	title_label.text = tower.tower_type.capitalize() + " Tower"
	level_label.text = "Level %d/%d" % [tower.level, tower.MAX_LEVEL]
	stats_label.text = "Damage: %d\nRange: %.0f\nRate: %.2f" % [tower.tower_damage, tower.attack_range, tower.fire_rate]
	if tower.level >= tower.MAX_LEVEL:
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
	else:
		upgrade_button.text = "Upgrade (%dg)" % tower.get_upgrade_cost()
		upgrade_button.disabled = false
	sell_button.text = "Sell (%dg)" % tower.get_sell_value()

	tracked_tower = tower
	visible = true
	_reposition()


func contains_point(screen_point: Vector2) -> bool:
	# Ask the panel itself instead of guessing a rect elsewhere.
	# get_global_rect() reflects the real, laid-out bounds.
	if not visible:
		return false
	return get_global_rect().has_point(screen_point)


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(tracked_tower):
		return
	_reposition()


# Anchor the panel near the tower, following camera zoom/pan, and keep it fully
# on screen. The origin sits at the tower's base, so we work out its top first,
# then pick whichever side (above / below / beside) actually has room.
func _reposition() -> void:
	var canvas_xform: Transform2D = tracked_tower.get_global_transform_with_canvas()
	var base_screen: Vector2 = canvas_xform.origin

	# canvas_xform already bakes in camera zoom, so these are in screen pixels
	var zoom_scale: float = canvas_xform.get_scale().y
	var tower_height: float = TowerVisuals.TARGET_HEIGHT * zoom_scale
	var top_screen: Vector2 = base_screen - Vector2(0.0, tower_height)

	var screen: Vector2 = get_viewport_rect().size
	var box: Vector2 = size
	var pos: Vector2

	# Preferred: upper-right of the tower, so it barely covers it
	if base_screen.x + PANEL_GAP + box.x <= screen.x:
		pos = Vector2(base_screen.x + PANEL_GAP, top_screen.y)
	# Fallback 1: upper-left of the tower
	elif base_screen.x - PANEL_GAP - box.x >= 0.0:
		pos = Vector2(base_screen.x - PANEL_GAP - box.x, top_screen.y)
	# Fallback 2: centered above the tower's top
	elif top_screen.y - box.y - PANEL_GAP >= 0.0:
		pos = Vector2(base_screen.x - box.x * 0.5, top_screen.y - box.y - PANEL_GAP)
	# Fallback 3: below the tower's base
	else:
		pos = Vector2(base_screen.x - box.x * 0.5, base_screen.y + PANEL_GAP)

	# Final clamp so the panel never spills off any edge
	pos.x = clamp(pos.x, PANEL_GAP, max(PANEL_GAP, screen.x - box.x - PANEL_GAP))
	pos.y = clamp(pos.y, PANEL_GAP, max(PANEL_GAP, screen.y - box.y - PANEL_GAP))
	global_position = pos
