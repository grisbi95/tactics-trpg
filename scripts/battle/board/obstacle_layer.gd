class_name ObstacleLayer
extends TileMapLayer

#region SIGNAUX
signal obstacles_generated
#endregion

#region CONSTANTES
const MAX_ATTEMPTS_MULTIPLIER: int = 10
#endregion

#region VARIABLES PRIVÉES
var _obstacle_patterns: Dictionary = {}
var _occupied_grid: Dictionary = {}
var _core_cells: Array[Vector2i] = []
var _border_cells: Array[Vector2i] = []
#endregion

#region FONCTIONS PUBLIQUES
func generate(core_size: Vector2i, anchor: Vector2i, obstacle_tile_coord: Vector2i, max_obstacles: int, size_probabilities: PackedFloat32Array, reserved_cells: Array[Vector2i] = [], valid_cells: Array[Vector2i] = [], rng: RandomNumberGenerator = null) -> void:
	"""Génère les obstacles dispersés sur le plateau.

	Args:
		core_size: (core_width, core_height) - Taille du rectangle Core
		anchor: Position du coin haut-gauche du Core (-width/2, -height/2)
		obstacle_tile_coord: Coordonnées de la tuile obstacle à utiliser
		max_obstacles: Nombre maximum d'obstacles à tenter de poser
		size_probabilities: Probabilités d'apparition de chaque gabarit (taille 1-5)
		reserved_cells: Cellules déjà interdites (spawns, etc.)
		valid_cells: Cellules valides où placer les obstacles (Core + Border)
		rng: Générateur de nombres aléatoires partagé
	"""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	_clear_layer()
	_initialize_patterns()

	# Si des cellules valides sont fournies, les utiliser, sinon calculer comme avant
	if valid_cells.size() > 0:
		_set_valid_cells(valid_cells)
	else:
		_build_available_cells(core_size, anchor)

	_initialize_occupied_grid(reserved_cells)

	var obstacles_placed = 0
	var attempts = 0
	var max_attempts = max_obstacles * MAX_ATTEMPTS_MULTIPLIER

	while obstacles_placed < max_obstacles and attempts < max_attempts:
		attempts += 1

		# Choix du gabarit d'obstacle
		var obstacle_size = _choose_obstacle_size(size_probabilities, rng)
		var patterns = _obstacle_patterns[obstacle_size]
		var pattern = patterns[rng.randi() % patterns.size()]

		# Génération d'une position candidate
		var reference_cell = _get_random_valid_cell(rng)
		if reference_cell == Vector2i.MAX:
			continue  # Aucune cellule valide disponible

		var obstacle_cells = _calculate_obstacle_cells(reference_cell, pattern)

		# Validation du placement
		if _is_placement_valid(obstacle_cells):
			_place_obstacle(obstacle_cells, obstacle_tile_coord)
			_mark_cells_as_occupied(obstacle_cells)
			obstacles_placed += 1

	obstacles_generated.emit()

func clear_layer() -> void:
	"""Efface complètement cette couche."""
	_clear_layer()
#endregion

#region FONCTIONS PRIVÉES
func _clear_layer() -> void:
	"""Efface toutes les cellules de cette couche."""
	clear()
	_occupied_grid.clear()
	_core_cells.clear()
	_border_cells.clear()

func _initialize_patterns() -> void:
	"""Initialise le catalogue des gabarits d'obstacle."""
	_obstacle_patterns = {
		1: [
			[Vector2i(0, 0)]  # Case isolée
		],
		2: [
			[Vector2i(0, 0), Vector2i(1, 0)],  # Horizontal
			[Vector2i(0, 0), Vector2i(0, 1)]   # Vertical
		],
		3: [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],  # L vers SE
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],  # L vers SW
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],  # L vers NW
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]   # L vers NE
		],
		4: [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],  # Carré 2x2
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],  # T vers S
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],  # T vers N
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],  # T vers E
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]   # T vers W
		],
		5: [
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]  # Croix
		]
	}

func _build_available_cells(core_size: Vector2i, anchor: Vector2i) -> void:
	"""Construit les listes des cellules du Core et de la Bordure."""
	# Cellules du Core
	for x in range(core_size.x):
		for y in range(core_size.y):
			_core_cells.append(Vector2i(anchor.x + x, anchor.y + y))

	# Cellules de la Bordure (approximation simple - dans un vrai cas, on pourrait interroger BorderLayer)
	var border_size = 3  # Estimation basée sur max_border_size
	for x in range(anchor.x - border_size, anchor.x + core_size.x + border_size):
		for y in range(anchor.y - border_size, anchor.y + core_size.y + border_size):
			var cell = Vector2i(x, y)
			if not _core_cells.has(cell):
				_border_cells.append(cell)

func _set_valid_cells(valid_cells: Array[Vector2i]) -> void:
	"""Définit les cellules valides fournies par Board."""
	_core_cells.clear()
	_border_cells.clear()

	# Toutes les cellules valides sont considérées comme disponibles
	# On pourrait distinguer Core/Border si nécessaire, mais pour l'instant on les mélange
	for cell in valid_cells:
		_core_cells.append(cell)

func _initialize_occupied_grid(reserved_cells: Array[Vector2i]) -> void:
	"""Initialise la grille d'occupation avec les cellules réservées."""
	for cell in reserved_cells:
		_occupied_grid[cell] = true
		# Marquer aussi l'anneau autour comme occupé
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor = Vector2i(cell.x + dx, cell.y + dy)
				_occupied_grid[neighbor] = true

func _choose_obstacle_size(probabilities: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	"""Choisit une taille d'obstacle selon les probabilités données."""
	var total_weight = 0.0
	for prob in probabilities:
		total_weight += prob

	if total_weight <= 0.0:
		return 1  # Taille par défaut

	var random_value = rng.randf() * total_weight
	var cumulative_weight = 0.0

	for i in range(probabilities.size()):
		cumulative_weight += probabilities[i]
		if random_value <= cumulative_weight:
			return i + 1  # Taille 1-5

	return 1  # Fallback

func _get_random_valid_cell(rng: RandomNumberGenerator) -> Vector2i:
	"""Récupère une cellule valide aléatoire du plateau."""
	var all_cells = _core_cells + _border_cells
	if all_cells.is_empty():
		return Vector2i.MAX

	var attempts = 0
	var max_attempts = all_cells.size() * 2

	while attempts < max_attempts:
		attempts += 1
		var cell = all_cells[rng.randi() % all_cells.size()]
		if not _occupied_grid.has(cell):
			return cell

	return Vector2i.MAX

func _calculate_obstacle_cells(reference_cell: Vector2i, pattern: Array) -> Array[Vector2i]:
	"""Calcule les positions absolues des cellules d'un obstacle."""
	var cells: Array[Vector2i] = []
	for offset in pattern:
		cells.append(Vector2i(reference_cell.x + offset.x, reference_cell.y + offset.y))
	return cells

func _is_placement_valid(obstacle_cells: Array[Vector2i]) -> bool:
	"""Vérifie si le placement d'un obstacle est valide."""
	var all_valid_cells = _core_cells + _border_cells

	for cell in obstacle_cells:
		# Vérifier que la cellule est dans la zone autorisée
		if not all_valid_cells.has(cell):
			return false

		# Vérifier que la cellule n'est pas occupée
		if _occupied_grid.has(cell):
			return false

		# Vérifier l'anneau autour de la cellule
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor = Vector2i(cell.x + dx, cell.y + dy)
				if _occupied_grid.has(neighbor):
					return false

	return true

func _place_obstacle(obstacle_cells: Array[Vector2i], tile_coord: Vector2i) -> void:
	"""Place un obstacle sur les cellules spécifiées."""
	for cell in obstacle_cells:
		set_cell(cell, 0, tile_coord)

func _mark_cells_as_occupied(obstacle_cells: Array[Vector2i]) -> void:
	"""Marque les cellules et leur anneau comme occupées."""
	for cell in obstacle_cells:
		_occupied_grid[cell] = true
		# Marquer l'anneau autour
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor = Vector2i(cell.x + dx, cell.y + dy)
				_occupied_grid[neighbor] = true
#endregion
