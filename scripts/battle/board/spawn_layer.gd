class_name SpawnLayer
extends TileMapLayer

#region SIGNAUX
signal spawns_generated
#endregion

#region CONSTANTES
const MAX_ATTEMPTS_MULTIPLIER: int = 20
const SHAPE_ORIENTATIONS: int = 4  # 0°, 90°, 180°, 270°
#endregion

#region VARIABLES PRIVÉES
var _core_cells: Array[Vector2i] = []
var _border_cells: Array[Vector2i] = []
var _forbidden_cells: Dictionary = {}
var _player_spawn_cells: Array[Vector2i] = []
var _enemy_spawn_cells: Array[Vector2i] = []
#endregion

#region FONCTIONS PUBLIQUES
func generate(core_size: Vector2i, anchor: Vector2i, player_tile_id: Vector2i, enemy_tile_id: Vector2i, player_size: int, enemy_size: int, min_distance: int, forbidden_cells: Array[Vector2i] = []) -> void:
	"""Génère les zones de déploiement en forme de blocs rectangulaires.

	Args:
		core_size: Taille du rectangle Core
		anchor: Position du coin haut-gauche du Core
		player_tile_id: Coordonnées atlas de la tuile pour la zone joueur
		enemy_tile_id: Coordonnées atlas de la tuile pour la zone ennemie
		player_size: Nombre de cases pour la zone joueur
		enemy_size: Nombre de cases pour la zone ennemie
		min_distance: Distance Manhattan minimale entre les zones
		forbidden_cells: Cellules déjà occupées ou interdites
	"""
	_clear_layer()
	_build_valid_cells(core_size, anchor)
	_initialize_forbidden_grid(forbidden_cells)

	# Variables de travail pour la génération
	var current_min_distance = min_distance
	var max_attempts = (player_size + enemy_size) * MAX_ATTEMPTS_MULTIPLIER
	var attempts = 0

	# Boucle principale avec réduction progressive de la distance minimale
	while current_min_distance >= 1 and attempts < max_attempts:
		attempts += 1

		# Tenter de placer les deux zones
		if _attempt_spawn_placement(player_size, enemy_size, current_min_distance):
			# Placement réussi, dessiner les zones
			_draw_spawn_zones(player_tile_id, enemy_tile_id)
			spawns_generated.emit()
			return

		# Si échec après plusieurs tentatives, réduire la distance minimale
		if attempts % MAX_ATTEMPTS_MULTIPLIER == 0:
			current_min_distance -= 1
			if current_min_distance >= 1:
				print_debug("SpawnLayer: Réduction de la distance minimale à %d" % current_min_distance)

	# Placement de dernier recours - accepter n'importe quelle position valide
	_fallback_placement(player_size, enemy_size, player_tile_id, enemy_tile_id)
	spawns_generated.emit()

func clear_layer() -> void:
	"""Efface complètement cette couche."""
	_clear_layer()

func get_player_spawn_cells() -> Array[Vector2i]:
	"""Retourne les cellules de la zone de spawn joueur."""
	return _player_spawn_cells.duplicate()

func get_enemy_spawn_cells() -> Array[Vector2i]:
	"""Retourne les cellules de la zone de spawn ennemie."""
	return _enemy_spawn_cells.duplicate()
#endregion

#region FONCTIONS PRIVÉES
func _clear_layer() -> void:
	"""Efface toutes les cellules de cette couche."""
	clear()
	_forbidden_cells.clear()
	_core_cells.clear()
	_border_cells.clear()
	_player_spawn_cells.clear()
	_enemy_spawn_cells.clear()

func _build_valid_cells(core_size: Vector2i, anchor: Vector2i) -> void:
	"""Construit les listes des cellules valides du Core et Border."""
	_core_cells.clear()
	_border_cells.clear()

	# Récupérer les cellules du Core et Border depuis les layers parents
	var parent_board = get_parent() as Board
	if parent_board:
		var core_layer = parent_board.get_node("CoreLayer") as TileMapLayer
		var border_layer = parent_board.get_node("BorderLayer") as TileMapLayer

		if core_layer:
			_core_cells = _get_layer_cells(core_layer)
		if border_layer:
			_border_cells = _get_layer_cells(border_layer)

	# Fallback : construire les cellules manuellement si les layers sont vides
	if _core_cells.is_empty():
		for x in range(core_size.x):
			for y in range(core_size.y):
				_core_cells.append(Vector2i(anchor.x + x, anchor.y + y))

func _get_layer_cells(layer: TileMapLayer) -> Array[Vector2i]:
	"""Récupère toutes les cellules utilisées d'une couche."""
	var cells: Array[Vector2i] = []
	var used_cells = layer.get_used_cells()
	for cell in used_cells:
		cells.append(cell)
	return cells

func _initialize_forbidden_grid(forbidden_cells: Array[Vector2i]) -> void:
	"""Initialise la grille des cellules interdites."""
	_forbidden_cells.clear()
	for cell in forbidden_cells:
		_forbidden_cells[cell] = true

func _attempt_spawn_placement(player_size: int, enemy_size: int, min_distance: int) -> bool:
	"""Tente de placer les deux zones de spawn avec la distance minimale."""
	# 1. Placement de la zone joueur (bande inférieure)
	var player_cells = _try_place_block_spawn(player_size, "bottom")
	if player_cells.size() != player_size:
		return false

	# Marquer temporairement les cellules joueur et leur anneau comme interdites
	var temp_forbidden = {}
	for cell in player_cells:
		temp_forbidden[cell] = true
		# Anneau de sécurité
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor = Vector2i(cell.x + dx, cell.y + dy)
				temp_forbidden[neighbor] = true

	# 2. Placement de la zone ennemie (bande supérieure)
	var enemy_cells = _try_place_block_spawn(enemy_size, "top", temp_forbidden)
	if enemy_cells.size() != enemy_size:
		return false

	# 3. Vérifier la distance Manhattan minimale
	var actual_distance = _calculate_min_manhattan_distance(player_cells, enemy_cells)

	if actual_distance >= min_distance:
		_player_spawn_cells = player_cells
		_enemy_spawn_cells = enemy_cells
		return true

	return false

func _try_place_block_spawn(size: int, band: String, additional_forbidden: Dictionary = {}) -> Array[Vector2i]:
	"""Tente de placer une zone de spawn en forme de bloc dans une bande donnée."""
	var all_cells = _core_cells + _border_cells

	if all_cells.is_empty():
		return []

	# Calculer le centre réel du plateau
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	for cell in all_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	var center_x = (min_x + max_x) / 2
	var center_y = (min_y + max_y) / 2

	# 1. Essayer d'abord la bande préférée (haut/bas)
	var search_cells = _get_band_cells(all_cells, band, center_x, center_y, "primary")

	if search_cells.size() >= size:
		var result = _test_patterns_in_cells(search_cells, size, all_cells, additional_forbidden)
		if not result.is_empty():
			return result

	# 2. Fallback : Essayer les bandes perpendiculaires (gauche/droite)
	var perpendicular_band = _get_perpendicular_band(band)
	search_cells = _get_band_cells(all_cells, perpendicular_band, center_x, center_y, "secondary")

	if search_cells.size() >= size:
		var result = _test_patterns_in_cells(search_cells, size, all_cells, additional_forbidden)
		if not result.is_empty():
			return result

	# 3. Dernier recours : Élargir à tout le plateau
	search_cells = all_cells.duplicate()
	return _test_patterns_in_cells(search_cells, size, all_cells, additional_forbidden)

func _get_band_cells(all_cells: Array[Vector2i], band: String, center_x: float, center_y: float, mode: String) -> Array[Vector2i]:
	"""Récupère les cellules d'une bande selon l'orientation demandée."""
	var search_cells: Array[Vector2i] = []

	match band:
		"bottom":
			if mode == "primary":
				# Moitié inférieure du plateau (bande horizontale)
				search_cells = all_cells.filter(func(cell): return cell.y >= center_y)
			elif mode == "secondary":
				# Moitié droite du plateau (bande verticale)
				search_cells = all_cells.filter(func(cell): return cell.x >= center_x)

		"top":
			if mode == "primary":
				# Moitié supérieure du plateau (bande horizontale)
				search_cells = all_cells.filter(func(cell): return cell.y <= center_y)
			elif mode == "secondary":
				# Moitié gauche du plateau (bande verticale)
				search_cells = all_cells.filter(func(cell): return cell.x <= center_x)

		"left":
			if mode == "primary":
				# Moitié gauche du plateau (bande verticale)
				search_cells = all_cells.filter(func(cell): return cell.x <= center_x)
			elif mode == "secondary":
				# Moitié supérieure du plateau (bande horizontale)
				search_cells = all_cells.filter(func(cell): return cell.y <= center_y)

		"right":
			if mode == "primary":
				# Moitié droite du plateau (bande verticale)
				search_cells = all_cells.filter(func(cell): return cell.x >= center_x)
			elif mode == "secondary":
				# Moitié inférieure du plateau (bande horizontale)
				search_cells = all_cells.filter(func(cell): return cell.y >= center_y)

	return search_cells

func _get_perpendicular_band(band: String) -> String:
	"""Retourne la bande perpendiculaire pour le fallback spatial."""
	match band:
		"bottom":
			return "right"  # Joueur passe de bas à droite
		"top":
			return "left"   # Ennemi passe de haut à gauche
		"left":
			return "top"
		"right":
			return "bottom"
		_:
			return "bottom"

func _test_patterns_in_cells(search_cells: Array[Vector2i], size: int, all_cells: Array[Vector2i], additional_forbidden: Dictionary) -> Array[Vector2i]:
	"""Teste tous les patterns dans les cellules de recherche données."""
	if search_cells.is_empty():
		return []

		search_cells.shuffle()

	# Générer les patterns de bloc adaptatifs pour cette taille
	var block_patterns = _generate_adaptive_patterns(size, all_cells)

	# Essayer chaque pattern de bloc
	for base_pattern in block_patterns:
		# Essayer les 4 orientations
		for orientation in range(SHAPE_ORIENTATIONS):
			var rotated_pattern = _rotate_pattern(base_pattern, orientation)

			# Essayer chaque position de référence (limiter pour éviter trop de tentatives)
			var max_positions_to_try = min(search_cells.size(), 100)
			for pos_idx in range(max_positions_to_try):
				var reference_cell = search_cells[pos_idx]
				var spawn_cells = _calculate_spawn_cells(reference_cell, rotated_pattern)

				if spawn_cells.size() == size and _is_spawn_placement_valid(spawn_cells, additional_forbidden):
					return spawn_cells

	return []

func _generate_adaptive_patterns(size: int, available_cells: Array[Vector2i]) -> Array[Array]:
	"""Génère des patterns adaptatifs qui s'ajustent aux contraintes spatiales."""
	var patterns: Array[Array] = []

	# Calculer les dimensions du plateau disponible
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for cell in available_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)

	var board_width = int(max_x - min_x + 1)
	var board_height = int(max_y - min_y + 1)

	# Pattern 1 : Rectangle compact adaptatif
	var compact_patterns = _generate_compact_rectangles(size, board_width, board_height)
	patterns.append_array(compact_patterns)

	# Pattern 2 : Lignes adaptatives
	var line_patterns = _generate_adaptive_lines(size, board_width, board_height)
	patterns.append_array(line_patterns)

	# Pattern 3 : Patterns en escalier pour les tailles difficiles
	var stair_patterns = _generate_stair_patterns(size, board_width, board_height)
	patterns.append_array(stair_patterns)

	return patterns

func _generate_compact_rectangles(size: int, max_width: int, max_height: int) -> Array[Array]:
	"""Génère des rectangles compacts qui respectent les contraintes."""
	var patterns: Array[Array] = []

	# Essayer différentes combinaisons de largeur/hauteur
	for width in range(1, min(size + 1, max_width + 1)):
		var height = int(ceil(float(size) / float(width)))

		if height <= max_height and width * height >= size:
			var pattern: Array[Vector2i] = []
			var cells_placed = 0

			# Remplir le rectangle
			for y in range(height):
				for x in range(width):
					if cells_placed < size:
						pattern.append(Vector2i(x, y))
						cells_placed += 1
					else:
						break
				if cells_placed >= size:
					break

			if pattern.size() == size:
				patterns.append(pattern)

	return patterns

func _generate_adaptive_lines(size: int, max_width: int, max_height: int) -> Array[Array]:
	"""Génère des lignes qui s'adaptent aux contraintes spatiales."""
	var patterns: Array[Array] = []

	# Ligne horizontale si elle rentre
	if size <= max_width:
		var h_line: Array[Vector2i] = []
		for x in range(size):
			h_line.append(Vector2i(x, 0))
		patterns.append(h_line)

	# Ligne verticale si elle rentre
	if size <= max_height:
		var v_line: Array[Vector2i] = []
		for y in range(size):
			v_line.append(Vector2i(0, y))
		patterns.append(v_line)

	# Lignes brisées pour les tailles importantes
	if size > max_width and size > max_height:
		var broken_patterns = _generate_broken_lines(size, max_width, max_height)
		patterns.append_array(broken_patterns)

	return patterns

func _generate_broken_lines(size: int, max_width: int, max_height: int) -> Array[Array]:
	"""Génère des lignes brisées pour les grandes tailles."""
	var patterns: Array[Array] = []

	# Ligne en L
	if max_width >= 2 and max_height >= 2:
		var segments_needed = int(ceil(float(size) / float(max_width)))
		if segments_needed <= max_height:
			var l_pattern: Array[Vector2i] = []
			var cells_placed = 0

			for segment in range(segments_needed):
				var segment_length = min(max_width, size - cells_placed)
				for x in range(segment_length):
					l_pattern.append(Vector2i(x, segment))
					cells_placed += 1
				if cells_placed >= size:
					break

			if l_pattern.size() == size:
				patterns.append(l_pattern)

	return patterns

func _generate_stair_patterns(size: int, max_width: int, max_height: int) -> Array[Array]:
	"""Génère des patterns en escalier pour optimiser l'espace."""
	var patterns: Array[Array] = []

	if size >= 3 and max_width >= 2 and max_height >= 2:
		# Pattern escalier croissant
		var stair: Array[Vector2i] = []
		var cells_placed = 0
		var current_width = 1
		var y = 0

		while cells_placed < size and y < max_height:
			var width_to_use = min(current_width, max_width, size - cells_placed)

			for x in range(width_to_use):
				stair.append(Vector2i(x, y))
				cells_placed += 1
				if cells_placed >= size:
					break

			if cells_placed >= size:
				break

			current_width += 1
			y += 1

		if stair.size() == size:
			patterns.append(stair)

	return patterns

func _calculate_spawn_cells(reference_cell: Vector2i, pattern: Array[Vector2i]) -> Array[Vector2i]:
	"""Calcule les positions absolues des cellules d'une zone de spawn."""
	var cells: Array[Vector2i] = []
	for offset in pattern:
		cells.append(Vector2i(reference_cell.x + offset.x, reference_cell.y + offset.y))
	return cells

func _is_spawn_placement_valid(spawn_cells: Array[Vector2i], additional_forbidden: Dictionary = {}) -> bool:
	"""Vérifie si le placement d'une zone de spawn est valide."""
	if spawn_cells.is_empty():
		return false

	var all_valid_cells = _core_cells + _border_cells

	for cell in spawn_cells:
		# Vérifier que la cellule est dans la zone autorisée
		if not all_valid_cells.has(cell):
			return false

		# Vérifier que la cellule n'est pas interdite
		if _forbidden_cells.has(cell):
			return false

		# Vérifier les interdictions supplémentaires
		if additional_forbidden.has(cell):
			return false

	return true

func _calculate_min_manhattan_distance(cells1: Array[Vector2i], cells2: Array[Vector2i]) -> int:
	"""Calcule la distance Manhattan minimale entre deux ensembles de cellules."""
	var min_distance = INF

	for cell1 in cells1:
		for cell2 in cells2:
			var distance = abs(cell1.x - cell2.x) + abs(cell1.y - cell2.y)
			min_distance = min(min_distance, distance)

	return int(min_distance)

func _fallback_placement(player_size: int, enemy_size: int, player_tile_id: Vector2i, enemy_tile_id: Vector2i) -> void:
	"""Placement de dernier recours - accepter n'importe quelle position valide."""
	var all_cells = _core_cells + _border_cells
	if all_cells.is_empty():
		return

	# Placement joueur - essayer toutes les cellules disponibles
	_player_spawn_cells = _try_place_anywhere(player_size, all_cells)

	if _player_spawn_cells.size() != player_size:
		# Placement d'urgence - prendre les premières cellules disponibles
		_player_spawn_cells.clear()
		var available = all_cells.filter(func(cell): return not _forbidden_cells.has(cell))
		for i in range(min(player_size, available.size())):
			_player_spawn_cells.append(available[i])

	# Placement ennemi
	var temp_forbidden = {}
	for cell in _player_spawn_cells:
		temp_forbidden[cell] = true

	var available_for_enemy = all_cells.filter(func(cell): return not temp_forbidden.has(cell) and not _forbidden_cells.has(cell))
	_enemy_spawn_cells = _try_place_anywhere(enemy_size, available_for_enemy)

	if _enemy_spawn_cells.size() != enemy_size:
		# Placement d'urgence ennemi
		_enemy_spawn_cells.clear()
		for i in range(min(enemy_size, available_for_enemy.size())):
			_enemy_spawn_cells.append(available_for_enemy[i])

	_draw_spawn_zones(player_tile_id, enemy_tile_id)

func _try_place_anywhere(size: int, available_cells: Array[Vector2i]) -> Array[Vector2i]:
	"""Essaie de placer un spawn n'importe où dans les cellules disponibles."""
	if available_cells.size() < size:
		return []

	available_cells.shuffle()
	var patterns = _generate_adaptive_patterns(size, available_cells)

	for pattern in patterns:
		for orientation in range(SHAPE_ORIENTATIONS):
			var rotated_pattern = _rotate_pattern(pattern, orientation)

			for reference_cell in available_cells:
				var spawn_cells = _calculate_spawn_cells(reference_cell, rotated_pattern)

				# Vérifier que toutes les cellules sont disponibles
				var all_available = true
				for cell in spawn_cells:
					if not available_cells.has(cell):
						all_available = false
						break

				if all_available and spawn_cells.size() == size:
					return spawn_cells

	# Si aucun pattern ne fonctionne, prendre les premières cellules disponibles
	return available_cells.slice(0, size)

func _draw_spawn_zones(player_tile_id: Vector2i, enemy_tile_id: Vector2i) -> void:
	"""Dessine les zones de spawn sur la couche."""
	# Dessiner la zone joueur
	for cell in _player_spawn_cells:
		set_cell(cell, 0, player_tile_id)

	# Dessiner la zone ennemie
	for cell in _enemy_spawn_cells:
		set_cell(cell, 0, enemy_tile_id)

func _rotate_pattern(pattern: Array[Vector2i], orientation: int) -> Array[Vector2i]:
	"""Effectue une rotation de 90° × orientation sur un pattern."""
	var rotated: Array[Vector2i] = []

	for cell in pattern:
		var rotated_cell = cell

		# Appliquer la rotation selon l'orientation
		for i in range(orientation):
			rotated_cell = Vector2i(-rotated_cell.y, rotated_cell.x)

		rotated.append(rotated_cell)

	return rotated
#endregion
