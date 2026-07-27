@tool
class_name DecorKinds
extends RefCounted

# Registry of every DecorKind .tres in res://data/decor/kinds/, keyed by `id`.
# Same shape as EnemyTypes and the tower registry, and it goes through the same
# ResourceRegistry.load_dir — see there for the export-build details.
#
# Adding a prop is one step: drop a .tres in the folder, then place copies of
# it with the DecorSpawner and bake.

const DIR: String = "res://data/decor/kinds"

static var _by_id: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_by_id = ResourceRegistry.load_dir(DIR, "DecorKinds")


# The kind table, id -> DecorKind.
static func all() -> Dictionary:
	_load()
	return _by_id


static func known(id: String) -> bool:
	_load()
	return _by_id.has(id)


# Returns null for an unknown id. Unlike enemies there's no useful placeholder
# prop, and a missing tree should be silently absent rather than turned into a
# visible error in the middle of the map — the spawner logs the id instead.
static func entry(id: String) -> DecorKind:
	_load()
	if _by_id.has(id):
		return _by_id[id]
	return null


# Drops the cache so the next call rescans. The editor spawner calls this after
# a bake or a manual .tres edit; without it a running editor keeps serving the
# resources it loaded when the scene first opened.
static func reload() -> void:
	_loaded = false
	_by_id = {}
