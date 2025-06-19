class_name CoreBoardLayer
extends TileMapLayer

#region SIGNAUX
signal core_generated
#endregion

#region FONCTIONS PUBLIQUES
func generate(width: int, height: int, anchor: Vector2i, tile_coords: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	"""Génère le rectangle jouable du Core.

	Args:
		width: Largeur du rectangle en cases
		height: Hauteur du rectangle en cases
		anchor: Position du coin haut-gauche (-width/2, -height/2)
		tile_coords: Liste des coordonnées atlas des tuiles à utiliser aléatoirement
		rng: Générateur de nombres aléatoires partagé
	"""
	_clear_layer()
	_fill_rectangle(width, height, anchor, tile_coords, rng)

	# Filtre de couleur rouge temporaire pour les tests
	modulate = Color.RED

	core_generated.emit()

func clear_layer() -> void:
	"""Efface complètement cette couche."""
	_clear_layer()
#endregion

#region FONCTIONS PRIVÉES
func _clear_layer() -> void:
	"""Efface toutes les cellules de cette couche."""
	clear()

func _fill_rectangle(width: int, height: int, anchor: Vector2i, tile_coords: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	"""Remplit un rectangle plein avec des tuiles aléatoires.

	Parcourt chaque case du rectangle et y place une tuile choisie
	aléatoirement parmi tile_coords pour créer un sol varié.
	"""
	for x in range(width):
		for y in range(height):
			# Position absolue de la cellule
			var cell_position: Vector2i = Vector2i(anchor.x + x, anchor.y + y)

			# Choisir une tuile aléatoire parmi les coordonnées disponibles
			var tile_coord: Vector2i = tile_coords[rng.randi() % tile_coords.size()]

			# Placer la tuile (source_id = 0 par défaut, atlas_coords correspond aux coordonnées)
			set_cell(cell_position, 0, tile_coord)
#endregion
