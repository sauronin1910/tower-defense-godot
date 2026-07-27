@tool
class_name ResourceRegistry
extends RefCounted

# Shared folder-scanning helper behind EnemyTypes and TowerTypes.
#
# Scanning a folder — rather than listing every file in a const — is what makes
# "drop a .tres in the folder" the whole procedure for adding a type.
#
# Two export-build details this has to handle, both invisible in the editor:
#
#   * project.godot's convert_text_resources_to_binary (on by default) rewrites
#     each res://…/foo.tres to foo.res and leaves a foo.tres.remap pointing at
#     it. DirAccess then lists "foo.tres.remap". load() wants the ORIGINAL
#     .tres path — Godot follows the remap itself — so the suffix is stripped.
#   * DirAccess also lists .import sidecars in some configurations; anything
#     that isn't a .tres after stripping is skipped.

# Returns id -> Resource for every .tres in `dir_path`. Resources need an `id`
# property; `owner_name` only labels the warnings.
static func load_dir(dir_path: String, owner_name: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("%s: cannot open %s" % [owner_name, dir_path])
		return out

	for file in dir.get_files():
		var name: String = file
		if name.ends_with(".remap"):
			name = name.get_basename()
		if not name.ends_with(".tres"):
			continue

		var res: Resource = load(dir_path.path_join(name))
		if res == null:
			push_error("%s: failed to load %s" % [owner_name, name])
			continue
		if not ("id" in res):
			push_error("%s: %s has no id property" % [owner_name, name])
			continue

		var id: String = str(res.id)
		if id == "":
			push_error("%s: %s has an empty id" % [owner_name, name])
			continue
		if out.has(id):
			push_error("%s: duplicate id '%s' in %s" % [owner_name, id, name])
			continue
		out[id] = res

	if out.is_empty():
		push_error("%s: no types found in %s" % [owner_name, dir_path])
	return out
