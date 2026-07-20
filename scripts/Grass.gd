extends ColorRect

# Attach this to the grass ColorRect. It keeps the shader's world-placement
# uniforms in sync with the node's actual position/size, so the mask lines up
# with the map. Wind runs on TIME inside the shader, so no per-frame cost here
# beyond setting a couple of uniforms once.

# Must match the MaskGen output for your map:
#   world origin = (-1248, -384), world size = (4512, 2592)
@export var mask_world_origin: Vector2 = Vector2(-1248, -384)
@export var mask_world_size: Vector2 = Vector2(4512, 2592)


func _ready() -> void:
	# Place and size the ColorRect to exactly cover the mask's world area
	global_position = mask_world_origin
	size = mask_world_size
	_push_uniforms()


func _push_uniforms() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		push_error("Grass: ColorRect has no ShaderMaterial")
		return
	mat.set_shader_parameter("mask_world_origin", mask_world_origin)
	mat.set_shader_parameter("mask_world_size", mask_world_size)
	mat.set_shader_parameter("rect_world_origin", global_position)
	mat.set_shader_parameter("rect_world_size", size)
