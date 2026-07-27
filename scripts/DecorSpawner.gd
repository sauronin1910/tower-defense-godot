@tool
class_name DecorSpawner
extends Node2D

# Builds the map's decor from data instead of from 204 hand-placed nodes.
#
# Main.tscn used to carry every tree and rock as its own [node] block — 3326
# lines, 241 nodes, ~2000 of those lines being the same nine properties copied
# by Ctrl+D. The scene was slow to open and impossible to merge. Now the Decor
# node is this script plus a JSON file.
#
# Editing still happens by eye in the viewport, which is why this is a @tool
# script. The catch is Godot's selection rule: the 2D editor ignores clicks on
# any node whose `owner` isn't the edited scene, and a node WITH an owner gets
# serialised back into the scene file. Ownership decides both, so the spawner
# switches it deliberately:
#
#   edit_mode OFF (default) — props spawn unowned. Visible, not clickable, and
#     Main.tscn stays 610 lines however many props there are.
#   edit_mode ON — props spawn owned. Selectable and draggable, and while it is
#     on the scene file WOULD take all of them if you saved it.
#
# So the loop is: tick `edit_mode`, drag things, tick `bake_now`. Baking writes
# the JSON and drops back out of edit mode, stripping ownership again.
#
# Saving the scene mid-edit is survivable but messy: the props land in
# Main.tscn, and the next _ready() clears them out again, so re-save after.
#
# Moves live only in the tree until baked — `reload_now`, closing the scene or a
# script reload all rebuild from the file and discard unbaked drags.

const DEFAULT_PLACEMENTS: String = "res://data/decor/placements.json"

@export_file("*.json") var placements_path: String = DEFAULT_PLACEMENTS

## Off gives you an empty Decor node in the editor — faster to open when you're
## working on something else. Runtime spawning always happens regardless.
@export var spawn_in_editor: bool = true

@export_group("Tools")
## Makes the props selectable and draggable in the 2D viewport by giving them an
## owner. Turn it on to rearrange, then bake — which turns it back off.
## WARNING: while this is on, saving the scene writes every prop into it.
@export var edit_mode: bool = false:
	set(value):
		edit_mode = value
		if Engine.is_editor_hint() and is_node_ready():
			respawn()

## Writes the current children back to placements_path, then leaves edit mode so
## the props stop being part of the scene file. Editor only.
@export var bake_now: bool = false:
	set(value):
		bake_now = false
		if value and Engine.is_editor_hint():
			bake()
			# Assigning edit_mode runs its own setter, which respawns unowned.
			if edit_mode:
				edit_mode = false

## Discards the current children and rebuilds them from the file. Anything not
## baked is lost — that is the point, it's how you undo a bad drag.
@export var reload_now: bool = false:
	set(value):
		reload_now = false
		if value and Engine.is_editor_hint():
			DecorKinds.reload()
			respawn()


func _ready() -> void:
	if Engine.is_editor_hint() and not spawn_in_editor:
		return
	respawn()


# ════════════════════════════════════════════
#  SPAWN
# ════════════════════════════════════════════

# True only while editing in the editor: at runtime ownership is irrelevant and
# edited_scene_root does not exist.
func _owning() -> bool:
	if not (edit_mode and Engine.is_editor_hint()):
		return false
	return get_tree() != null and get_tree().edited_scene_root != null


func respawn() -> void:
	_clear()
	_name_counts.clear()
	var owning: bool = _owning()
	var rows: Array = _read_rows()
	var missing: Dictionary = {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var id: String = str(row.get("kind", ""))
		var kind: DecorKind = DecorKinds.entry(id)
		if kind == null:
			missing[id] = int(missing.get(id, 0)) + 1
			continue
		var sprite: Sprite2D = _make_sprite(kind, row)
		add_child(sprite)
		# Owner must be set after the node is in the tree. This one line is the
		# difference between "draggable" and "not in the scene file".
		if owning:
			sprite.owner = get_tree().edited_scene_root
	for id in missing:
		push_warning("DecorSpawner: unknown decor kind '%s' (%d placements skipped)" % [id, missing[id]])


func _make_sprite(kind: DecorKind, row: Dictionary) -> Sprite2D:
	var sprite := DecorSprite.new()
	kind.apply_to(sprite)
	# Position before the node enters the tree: DecorSprite._ready() reads
	# global_position to work out its z_index and its build-blocking centre.
	sprite.position = _to_vec2(row.get("pos"), Vector2.ZERO)
	sprite.scale = _to_vec2(row.get("scale"), kind.default_scale)
	sprite.rotation = float(row.get("rot", 0.0))
	sprite.flip_h = bool(row.get("flip_h", false))
	sprite.name = _unique_name(kind.id)
	# Read back by bake(); a hand-added sprite without it is matched by texture.
	sprite.set_meta("decor_kind", kind.id)
	return sprite


func _clear() -> void:
	# Every child, owned or not. Duplicating a node in the editor gives the copy
	# an owner, which would otherwise let it leak back into Main.tscn.
	for child in get_children():
		remove_child(child)
		child.queue_free()


var _name_counts: Dictionary = {}

func _unique_name(id: String) -> String:
	var n: int = int(_name_counts.get(id, 0)) + 1
	_name_counts[id] = n
	return "%s_%03d" % [id, n]


# ════════════════════════════════════════════
#  BAKE
# ════════════════════════════════════════════

# Writes the current children back to placements_path, one placement per line so
# the file diffs and merges like source rather than like a scene.
func bake() -> void:
	var by_texture: Dictionary = {}
	for kind in DecorKinds.all().values():
		by_texture[kind.texture_path] = kind

	var rows: Array[String] = []
	var skipped: Array[String] = []
	for child in get_children():
		if not (child is Sprite2D):
			continue
		var sprite: Sprite2D = child
		var kind: DecorKind = _kind_of(sprite, by_texture)
		if kind == null:
			skipped.append(str(sprite.name))
			continue
		rows.append(_row_text(sprite, kind))

	var text: String = "{\n"
	text += "\t\"_comment\": \"Generated by DecorSpawner.bake(). Hand-edits are fine; keep one placement per line.\",\n"
	text += "\t\"placements\": [\n"
	text += ",\n".join(rows)
	text += "\n\t]\n}\n"

	var f := FileAccess.open(placements_path, FileAccess.WRITE)
	if f == null:
		push_error("DecorSpawner: cannot write %s" % placements_path)
		return
	f.store_string(text)
	f.close()
	print("DecorSpawner: baked %d placements to %s" % [rows.size(), placements_path])
	if not skipped.is_empty():
		push_warning("DecorSpawner: %d node(s) had no matching kind and were dropped: %s"
			% [skipped.size(), ", ".join(skipped)])


func _kind_of(sprite: Sprite2D, by_texture: Dictionary) -> DecorKind:
	if sprite.has_meta("decor_kind"):
		var kind: DecorKind = DecorKinds.entry(str(sprite.get_meta("decor_kind")))
		if kind != null:
			return kind
	# Hand-added node: fall back to whichever kind uses this texture.
	if sprite.texture != null:
		var path: String = sprite.texture.resource_path
		if by_texture.has(path):
			return by_texture[path]
	return null


func _row_text(sprite: Sprite2D, kind: DecorKind) -> String:
	var parts: Array[String] = []
	parts.append("\"kind\": \"%s\"" % kind.id)
	parts.append("\"pos\": [%s, %s]" % [_num(sprite.position.x), _num(sprite.position.y)])
	# Only write what actually differs from the kind, so the common case stays
	# a two-field row and a scale tweak is visible in the diff.
	if not sprite.scale.is_equal_approx(kind.default_scale):
		parts.append("\"scale\": [%s, %s]" % [_num(sprite.scale.x), _num(sprite.scale.y)])
	if not is_zero_approx(sprite.rotation):
		parts.append("\"rot\": %s" % _num(sprite.rotation))
	if sprite.flip_h:
		parts.append("\"flip_h\": true")
	return "\t\t{%s}" % ", ".join(parts)


# Trims float noise: editor drags produce values like 1675.9999 that would
# otherwise churn the diff on every bake. String.num always emits the decimal
# point at 3 places, so stripping trailing zeros can't eat an integer's own.
func _num(v: float) -> String:
	var s: String = String.num(snappedf(v, 0.001), 3)
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	return s.trim_suffix(".")


# ════════════════════════════════════════════
#  FILE
# ════════════════════════════════════════════

func _read_rows() -> Array:
	if not FileAccess.file_exists(placements_path):
		push_error("DecorSpawner: %s not found" % placements_path)
		return []
	var text: String = FileAccess.get_file_as_string(placements_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DecorSpawner: %s is not a JSON object" % placements_path)
		return []
	var rows: Variant = parsed.get("placements")
	if typeof(rows) != TYPE_ARRAY:
		push_error("DecorSpawner: %s has no 'placements' array" % placements_path)
		return []
	return rows


func _to_vec2(v: Variant, fallback: Vector2) -> Vector2:
	if typeof(v) == TYPE_ARRAY and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return Vector2(float(v), float(v))
	return fallback
