class_name TowerShadow
extends Node2D

# A simple blob shadow: a flattened, semi-transparent dark ellipse drawn at the
# tower's base (the node origin). Created via TowerVisuals.make_shadow(type) so
# every tower/ghost gets a consistent shadow without an art asset.

var radius: float = 48.0                       # horizontal radius (map px)
var vertical_ratio: float = 0.7                # squash on Y (matches footprint)
var color: Color = Color(0.0, 0.0, 0.0, 0.28)  # dark, translucent
var y_offset: float = 0.0                      # nudge down from the base
var x_offset: float = 20.0                      # nudge left(-)/right(+)
var width_mult: float = 1.3                  # stretch horizontally
var height_mult: float = 1.2                   # stretch vertically                    # nudge down from the base if needed


func setup(r: float, v_ratio: float) -> void:
	radius = r
	vertical_ratio = v_ratio
	queue_redraw()


func _draw() -> void:
	# Build an ellipse as a fan of points, then fill it. Squashed on Y so it reads
	# as ground seen at an angle. Offsets and stretch multipliers let you shape it.
	var segments: int = 24
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		points.append(Vector2(
			cos(a) * radius * width_mult + x_offset,
			sin(a) * radius * vertical_ratio * height_mult + y_offset
		))
	draw_colored_polygon(points, color)
