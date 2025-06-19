class_name Board
extends TileMapLayer

#region SIGNAUX
signal board_generated
#endregion

#region VARIABLES EXPORTÉES
@export_group("Core Layer Config")
@export var core_width: int = 10
@export var core_height: int = 10

@export_group("Border Layer Config")
@export var max_border_size: int = 3
@export var probability_border_size: PackedFloat32Array = [1.0, 0.6, 0.3]

@export_group("Obstacle Layer Config")
@export var max_obstacles: int = 22
@export var obstacle_size_probabilities: PackedFloat32Array = [0.40, 0.30, 0.18, 0.10, 0.02]

@export_group("Spawn Layer Config")
@export var spawn_player_size: int = 6
@export var spawn_enemy_size: int = 6
@export var spawn_min_distance: int = 8

@export_group("Tiles Configuration")
@export var board_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
@export var obstacle_tile: Vector2i = Vector2i(0, 1)
@export var spawn_player_tile: Vector2i = Vector2i(1, 2)
@export var spawn_enemy_tile: Vector2i = Vector2i(0, 2)

@export_group("Generation Settings")
@export var seed_value: int = -1
#endregion

#region VARIABLES PRIVÉES
var _rng: RandomNumberGenerator
var _anchor: Vector2i
var _core_board_layer: TileMapLayer
var _border_board_layer: TileMapLayer
var _obstacle_layer: TileMapLayer
var _spawn_layer: TileMapLayer
#endregion

#region FONCTIONS VIRTUELLES
func _ready() -> void:
	_initialize_rng()
	_validate_configuration()
	_setup_layers()
	_calculate_centering()
	_generate_board()
#endregion

#region FONCTIONS PUBLIQUES
func generate_board() -> void:
	"""Génère le plateau complet selon l'ordre spécifié."""
	_generate_board()

func get_anchor() -> Vector2i:
	"""Retourne l'anchor utilisé pour le positionnement des layers."""
	return _anchor

func get_rng() -> RandomNumberGenerator:
	"""Retourne la RNG partagée."""
	return _rng
#endregion

#region FONCTIONS PRIVÉES
func _initialize_rng() -> void:
	"""Initialise la RNG avec la seed configurée."""
	_rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

func _validate_configuration() -> void:
	"""Valide les prérequis de configuration."""
	if board_tiles.size() < 3:
		push_error("Board: board_tiles doit contenir au moins 3 coordonnées de tuiles")
		return

	if not tile_set:
		push_error("Board: tile_set ne peut pas être null")
		return

	if core_width <= 0 or core_height <= 0:
		push_error("Board: core_width et core_height doivent être positifs")
		return

	# Validation des nouvelles variables BorderLayer
	if max_border_size < 1:
		push_error("Board: max_border_size doit être supérieur ou égal à 1")
		return

	if probability_border_size.size() != max_border_size:
		push_error("Board: probability_border_size.size() doit être égal à max_border_size")
		return

	for i in range(probability_border_size.size()):
		if probability_border_size[i] < 0.0 or probability_border_size[i] > 1.0:
			push_error("Board: probability_border_size[%d] doit être dans [0, 1]" % i)
			return

	# Validation des nouvelles variables ObstacleLayer
	if max_obstacles < 0:
		push_error("Board: max_obstacles doit être supérieur ou égal à 0")
		return

	if obstacle_size_probabilities.size() != 5:
		push_error("Board: obstacle_size_probabilities doit contenir exactement 5 valeurs")
		return

	for i in range(obstacle_size_probabilities.size()):
		if obstacle_size_probabilities[i] < 0.0 or obstacle_size_probabilities[i] > 1.0:
			push_error("Board: obstacle_size_probabilities[%d] doit être dans [0, 1]" % i)
			return

	# Validation des nouvelles variables SpawnLayer
	if spawn_player_size < 1:
		push_error("Board: spawn_player_size doit être supérieur ou égal à 1")
		return

	if spawn_enemy_size < 1:
		push_error("Board: spawn_enemy_size doit être supérieur ou égal à 1")
		return

	if spawn_min_distance < 1:
		spawn_min_distance = 1
		push_warning("Board: spawn_min_distance était inférieur à 1, réinitialisé à 1")

func _setup_layers() -> void:
	"""Configure les références vers les layers enfants."""
	_core_board_layer = $CoreLayer as TileMapLayer
	_border_board_layer = $BorderLayer as TileMapLayer
	_obstacle_layer = $ObstacleLayer as TileMapLayer
	_spawn_layer = $SpawnLayer as TileMapLayer

	_core_board_layer.tile_set = tile_set
	_border_board_layer.tile_set = tile_set
	_obstacle_layer.tile_set = tile_set
	_spawn_layer.tile_set = tile_set

func _calculate_centering() -> void:
	"""Calcule l'anchor et centre le plateau."""
	_anchor = Vector2i(-core_width / 2, -core_height / 2)

	var tile_size: Vector2i = tile_set.tile_size
	var half_width_pixels: float = (core_width * tile_size.x) / 2.0
	var half_height_pixels: float = (core_height * tile_size.y) / 2.0

	position = Vector2(-half_width_pixels, -half_height_pixels)

func _generate_board() -> void:
	"""Orchestre la génération séquentielle de toutes les couches."""
	# 1. Générer le Core (plateau jouable)
	_core_board_layer.generate(core_width, core_height, _anchor, board_tiles, _rng)

	# 2. Générer la bordure
	var core_size = Vector2i(core_width, core_height)
	_border_board_layer.generate(core_size, _anchor, board_tiles, max_border_size, probability_border_size, _rng)

	# 3. Générer les obstacles
	var reserved_cells: Array[Vector2i] = []
	var valid_cells: Array[Vector2i] = []

	# Récupérer les cellules valides du Core et Border
	valid_cells.append_array(_get_layer_cells(_core_board_layer))
	valid_cells.append_array(_get_layer_cells(_border_board_layer))

	_obstacle_layer.generate(core_size, _anchor, obstacle_tile, max_obstacles, obstacle_size_probabilities, reserved_cells, valid_cells, _rng)

	# 4. Générer les spawns
	var forbidden_cells: Array[Vector2i] = []
	# Ajouter les obstacles et leur anneau de sécurité
	var obstacle_cells = _get_layer_cells(_obstacle_layer)
	forbidden_cells.append_array(obstacle_cells)
	# Ajouter l'anneau de sécurité autour des obstacles
	for obstacle_cell in obstacle_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor = Vector2i(obstacle_cell.x + dx, obstacle_cell.y + dy)
				if not forbidden_cells.has(neighbor):
					forbidden_cells.append(neighbor)

	_spawn_layer.generate(core_size, _anchor, spawn_player_tile, spawn_enemy_tile, spawn_player_size, spawn_enemy_size, spawn_min_distance, forbidden_cells)

	# Émettre le signal de fin de génération
	board_generated.emit()

func _get_layer_cells(layer: TileMapLayer) -> Array[Vector2i]:
	"""Récupère toutes les cellules utilisées d'une couche TileMapLayer."""
	var cells: Array[Vector2i] = []
	var used_cells = layer.get_used_cells()  # Récupère toutes les cellules utilisées

	for cell in used_cells:
		cells.append(cell)

	return cells
#endregion
