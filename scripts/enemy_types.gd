class_name EnemyTypes
extends RefCounted

# Registry of every EnemyType .tres in res://data/enemies/, keyed by `id`.
#
# Adding an enemy is ONE step: drop a .tres in that folder. It used to mean
# editing five places — two if/elif chains in Enemy.gd, a key in every row of
# WAVE_CONFIG, the hand-unrolled cumulative chain in _on_spawn_timer_timeout,
# and the hand-written sum in start_wave. All five are gone.
#
# See ResourceRegistry for why the folder scan looks the way it does.

const DIR: String = "res://data/enemies"

static var _by_id: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_by_id = ResourceRegistry.load_dir(DIR, "EnemyTypes")


# The type table, id -> EnemyType.
static func all() -> Dictionary:
	_load()
	return _by_id


static func known(id: String) -> bool:
	_load()
	return _by_id.has(id)


# Never returns null: an unknown id yields a walking placeholder rather than an
# invisible enemy, so a typo in a wave is obvious on screen as well as in Output.
static func entry(id: String) -> EnemyType:
	_load()
	if _by_id.has(id):
		return _by_id[id]
	push_warning("EnemyTypes: unknown enemy id '%s', using fallback" % id)
	var fallback := EnemyType.new()
	fallback.id = id
	fallback.texture_path = "res://assets/sprites/Peasant.png"
	fallback.scale = 0.1125
	return fallback
