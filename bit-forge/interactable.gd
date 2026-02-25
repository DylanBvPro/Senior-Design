extends Node3D
class_name Interactable

@export var mesh: MeshInstance3D

var meshMaterial: StandardMaterial3D

func _ready():
	if mesh == null:
		mesh = _find_mesh_instance(self)

	if mesh == null:
		push_warning("Interactable: No MeshInstance3D found, outline disabled for %s" % name)
		return

	var mat: Material = mesh.get_active_material(0)
	if mat == null:
		mat = mesh.get_surface_override_material(0)

	if mat == null:
		var fallback := StandardMaterial3D.new()
		mesh.set_surface_override_material(0, fallback)
		meshMaterial = fallback
		return

	# Duplicate so each interactable has its own material instance
	var unique_mat = mat.duplicate()
	mesh.set_surface_override_material(0, unique_mat)

	if unique_mat is StandardMaterial3D:
		meshMaterial = unique_mat as StandardMaterial3D
	else:
		var converted := StandardMaterial3D.new()
		mesh.set_surface_override_material(0, converted)
		meshMaterial = converted


func _find_mesh_instance(root: Node) -> MeshInstance3D:
	for child in root.get_children():
		if child is MeshInstance3D:
			return child

	for child in root.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found

	return null


func getInteractMessage(_player: Player) -> String:
	return "Press [E] to interact"


func interact(_player: Player):
	print("Interactable.interact(%s)" % name)


func toggleOutline():
	if meshMaterial == null:
		return

	if meshMaterial.stencil_mode == BaseMaterial3D.StencilMode.STENCIL_MODE_DISABLED:
		meshMaterial.stencil_mode = BaseMaterial3D.StencilMode.STENCIL_MODE_OUTLINE
	else:
		meshMaterial.stencil_mode = BaseMaterial3D.StencilMode.STENCIL_MODE_DISABLED
