class_name BorderBoardLayer
extends TileMapLayer

#region SIGNAUX
signal border_generated
#endregion

#region FONCTIONS PUBLIQUES
func generate(core_size: Vector2i, anchor: Vector2i, tiles: Array[Vector2i], max_border_size: int, probas: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	"""Génère la bordure décorative/bloquante autour du Core.

	Args:
		core_size: (core_width, core_height) - Taille du rectangle Core
		anchor: Position du coin haut-gauche du Core (-width/2, -height/2)
		tiles: Array[Vector2i] des coordonnées atlas des tuiles à utiliser pour la bordure
		max_border_size: Nombre maximal de bandes de bordure par direction
		probas: Probabilités de création pour chaque niveau de bande
		rng: Générateur de nombres aléatoires partagé
	"""
	_clear_layer()

	# Générer les bandes de bordure pour chaque direction (commençant directement contre le core)
	_generate_borders_for_direction("top", core_size, anchor, tiles, max_border_size, probas, rng)
	_generate_borders_for_direction("bottom", core_size, anchor, tiles, max_border_size, probas, rng)
	_generate_borders_for_direction("left", core_size, anchor, tiles, max_border_size, probas, rng)
	_generate_borders_for_direction("right", core_size, anchor, tiles, max_border_size, probas, rng)

	border_generated.emit()

func clear_layer() -> void:
	"""Efface complètement cette couche."""
	_clear_layer()
#endregion

#region FONCTIONS PRIVÉES
func _clear_layer() -> void:
	"""Efface toutes les cellules de cette couche."""
	clear()

func _generate_borders_for_direction(direction: String, core_size: Vector2i, anchor: Vector2i, tiles: Array[Vector2i], max_border_size: int, probas: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	"""Génère les bandes de bordure pour une direction donnée."""
	# Longueur de référence L₀ = longueur entière du côté du Core
	var reference_length: int
	match direction:
		"top", "bottom":
			reference_length = core_size.x
		"left", "right":
			reference_length = core_size.y

	var current_length = reference_length
	var current_offset = 0  # Position de début de la bande actuelle

	# Boucle sur les niveaux n de 0 à max_border_size-1 (commencer directement contre le core)
	for level in range(0, max_border_size):
		# Tirage de création
		var p = rng.randf()
		if p > probas[level]:
			break # Arrêt du traitement pour ce côté

		# Calcul de la longueur admissible
		var l_max = current_length - 1
		if l_max <= 0:
			break # Impossible de continuer

		var l_min = ceili(float(current_length) / 2.0)

		var new_length: int
		if l_min > l_max:
			new_length = l_max
		else:
			new_length = rng.randi_range(l_min, l_max)

		# Choix du décalage latéral relatif à la bande précédente
		var max_relative_offset = current_length - new_length
		var relative_offset = 0
		if max_relative_offset > 0:
			relative_offset = rng.randi_range(0, max_relative_offset)

		# Calcul de l'offset absolu par rapport au core
		var absolute_offset = current_offset + relative_offset

		# Placement effectif
		_place_border_band(direction, core_size, anchor, level, new_length, absolute_offset, tiles, rng)

		# Mise à jour pour la prochaine itération
		current_length = new_length
		current_offset = absolute_offset

func _place_border_band(direction: String, core_size: Vector2i, anchor: Vector2i, level: int, length: int, offset: int, tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	"""Place une bande de bordure d'un niveau donné dans la direction spécifiée."""
	match direction:
		"top":
			for i in range(length):
				var pos = Vector2i(anchor.x + offset + i, anchor.y - 1 - level)
				_place_random_tile(pos, tiles, rng)

		"bottom":
			for i in range(length):
				var pos = Vector2i(anchor.x + offset + i, anchor.y + core_size.y + level)
				_place_random_tile(pos, tiles, rng)

		"left":
			for i in range(length):
				var pos = Vector2i(anchor.x - 1 - level, anchor.y + offset + i)
				_place_random_tile(pos, tiles, rng)

		"right":
			for i in range(length):
				var pos = Vector2i(anchor.x + core_size.x + level, anchor.y + offset + i)
				_place_random_tile(pos, tiles, rng)

func _place_random_tile(pos: Vector2i, tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	"""Place une tuile aléatoire à la position donnée."""
	if tiles.size() == 0:
		return

	var tile_index = rng.randi() % tiles.size()
	var tile_coord = tiles[tile_index]

	set_cell(pos, 0, tile_coord)
#endregion
