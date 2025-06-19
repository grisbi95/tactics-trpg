class_name MovementComponent
extends Node2D

### CONSTANTES ###
const MOVE_SPEED: float = 300.0
const MOVE_DURATION: float = 0.3
const TILE_ANIMATION_DURATION: float = 0.15
const TILE_ANIMATION_DELAY: float = 0.001

### VARIABLES ###
@export var move_speed: float = 200
@export var highlight_texture: Texture2D

@onready var unit: Unit = get_parent() as Unit
@onready var animation_component: AnimationComponent = $"../AnimationComponent"
@onready var root_node: Node = get_tree().root

var is_moving: bool = false
var movement_tiles: Array[Node2D] = []
var hover_path: Array[Node2D] = []
var accessible_cells: Array[Vector2i] = []
var current_path: Array[Vector2] = []
var move_tween: Tween
var highlight_sprite: Sprite2D

### SIGNAUX ###
signal forced_move_finished # Signal pour indiquer la fin d'un mouvement forcé

### INITIALISATION ###
func _ready():
	var parent_name = get_parent().name if get_parent() else "null"
	if not unit: push_warning("MovementComponent [_READY]: unit (get_parent()) est null ou n'est pas de type Unit!")
	if not animation_component: push_warning("MovementComponent [_READY]: animation_component est null! Vérifier chemin '../AnimationComponent' dans la scène parente (", parent_name, ")")
	if not root_node: push_warning("MovementComponent [_READY]: root_node est null!")
	
	# Initialiser le sprite de surbrillance (utilisé pour le chemin du joueur)
	if highlight_texture:
		highlight_sprite = Sprite2D.new()
		highlight_sprite.texture = highlight_texture
		highlight_sprite.visible = false
		add_child(highlight_sprite)

### FONCTIONS PUBLIQUES ###

func move_to_cell(target_cell: Vector2i) -> bool:
	if is_moving:
		return false
	if not unit or not unit.stats:
		return false
		
	if not NavigationService.is_valid_path(unit.cell, target_cell):
		return false
		
	var path = NavigationService.get_move_path(unit.cell, target_cell)
	var movement_cost = path.size()
	
	if not unit.stats.can_move(movement_cost) or not unit.stats.consume_movement_points(movement_cost):
		return false
		
	_start_movement(path)
	return true

func show_range() -> void:
	if not unit or not unit.stats:
		push_error("MovementComponent [SHOW_RANGE]: Unité ou stats non valides")
		return
		
	clear()
	var range = unit.stats.current_movement_points
	
	# Algorithme BFS pour trouver les cellules accessibles
	accessible_cells.clear()
	var visited := {}
	var queue := [unit.cell]
	visited[unit.cell] = 0
	
	var directions := [
		Vector2i(0, -1),  # Haut
		Vector2i(0, 1),   # Bas
		Vector2i(-1, 0),  # Gauche
		Vector2i(1, 0)    # Droite
	]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_distance = visited[current]
		
		if current != unit.cell:
			accessible_cells.append(current)
		
		if current_distance >= range:
			continue
		
		for direction in directions:
			var neighbor = current + direction
			
			# LOG AJOUTÉ: Vérifier le résultat de is_valid_path pour le voisin
			var is_path_valid_to_neighbor = NavigationService.is_valid_path(unit.cell, neighbor)

			if is_path_valid_to_neighbor and not visited.has(neighbor):
				visited[neighbor] = current_distance + 1
				queue.append(neighbor)
	
	# Trier les cellules par distance à l'unité pour l'effet de vague
	if visited:
		accessible_cells.sort_custom(func(a, b):
			if not visited.has(a) or not visited.has(b):
				return false
			return visited[a] < visited[b]
		)
	
	# Afficher les cellules accessibles avec animation
	_animate_range_tiles()

# Fonction séparée pour l'animation pour utiliser await
func _animate_range_tiles():
	for cell in accessible_cells:
		var tile = _create_highlight_tile(cell)
		tile.visible = true
		if not unit is Player:
			tile.modulate = Color(1, 0, 0, 0.5)
		else:
			tile.modulate = Color(0, 1, 0, 0.5)
		movement_tiles.append(tile)
		if root_node:
			root_node.add_child(tile)
		else:
			continue
		
		# Animation d'apparition avec un effet de fade
		var tween = create_tween()
		tile.modulate.a = 0
		tile.scale = Vector2(0.8, 0.8)
		tween.tween_property(tile, "modulate:a", 0.5, TILE_ANIMATION_DURATION)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(tile, "scale", Vector2(1, 1), TILE_ANIMATION_DURATION)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		
		await get_tree().create_timer(TILE_ANIMATION_DELAY).timeout

func clear() -> void:
	for tile in movement_tiles:
		if is_instance_valid(tile):
			var tween = create_tween()
			tween.tween_property(tile, "modulate:a", 0, TILE_ANIMATION_DURATION)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_IN)
			tween.tween_callback(tile.queue_free)
	movement_tiles.clear()
	accessible_cells.clear()
	
	for tile in hover_path:
		if is_instance_valid(tile):
			tile.queue_free()
	hover_path.clear()

func update_hover_path(target_cell: Vector2i) -> void:
	# print("MovementComponent [UPDATE_HOVER]: Début pour ", target_cell) # Trop verbeux
	for tile in hover_path:
		if is_instance_valid(tile):
			tile.queue_free()
	hover_path.clear()
	
	if not accessible_cells.has(target_cell):
		# print("MovementComponent [UPDATE_HOVER]: Cellule cible non accessible")
		return
	
	if not unit:
		return
		
	if NavigationService.is_valid_path(unit.cell, target_cell):
		var path = NavigationService.get_move_path(unit.cell, target_cell)
		for point in path:
			var cell_coord = NavigationService.world_to_cell(point)
			# Éviter de redessiner sur la case de l'unité elle-même
			if cell_coord == unit.cell: continue
			
			var tile = _create_highlight_tile(cell_coord)
			if not unit is Player:
				tile.modulate = Color(1, 0, 0, 0.8)
			else:
				tile.modulate = Color(0, 1, 0, 0.8)
			tile.visible = true
			hover_path.append(tile)
			if root_node:
				root_node.add_child(tile)
			else:
				push_error("MovementComponent [update_hover_path]: root_node est null!")

### FONCTIONS DE MOUVEMENT FORCÉ ###

# Nouvelle méthode pour les déplacements forcés (poussée/attraction)
# look_at_point_world est le point dans le monde que l'unité devrait regarder (ou fuir)
func apply_forced_movement(destination_cell: Vector2i, look_from_origin_cell: Vector2i = NavigationService.INVALID_POSITION) -> Tween:
	if not is_instance_valid(unit):
		push_error("MovementComponent: Unité parente invalide.")
		return null

	var start_world_pos = unit.global_position
	var target_world_pos = NavigationService.cell_to_world(destination_cell)

	if is_instance_valid(unit.animation_component):
		if look_from_origin_cell != NavigationService.INVALID_POSITION:
			var look_at_world_pos = NavigationService.cell_to_world(look_from_origin_cell)
			unit.animation_component.update_direction(start_world_pos, look_at_world_pos)
		unit.animation_component.play_hurt()

	# Tuer le tween précédent s'il existe et est valide pour éviter les conflits
	if move_tween and move_tween.is_valid():
		move_tween.kill()

	var new_move_tween = create_tween() # Créer un nouveau tween pour ce mouvement spécifique
	var distance_vector = target_world_pos - start_world_pos
	var duration = 0.2 
	if move_speed > 0 and distance_vector.length() > 0:
		duration = distance_vector.length() / (move_speed * 32.0) 
	duration = max(0.1, duration) 

	new_move_tween.tween_property(unit, "global_position", target_world_pos, duration).set_trans(Tween.TRANS_LINEAR)
	
	new_move_tween.finished.connect(func():
		if is_instance_valid(unit):
			unit.global_position = target_world_pos 
			NavigationService.update_unit_position(unit, destination_cell)
			# Optionnel: Retour à idle si l'anim hurt ne le fait pas
			# if is_instance_valid(unit.animation_component) and unit.animation_component.current_state == AnimationComponent.AnimState.HURT:
			#    unit.animation_component.play_idle()
	)
	return new_move_tween # Retourner le tween pour que l'appelant puisse l'attendre

### FONCTIONS PRIVÉES ###

func _start_movement(path: Array[Vector2]) -> void:
	is_moving = true
	var tween = create_tween()
	tween.set_parallel(false)
	# Assurer que l'unité est valide au début
	if not is_instance_valid(unit):
		push_error("MovementComponent [_start_movement]: Unit invalide au début.")
		return
	
	# Point de départ pour le premier segment
	var start_point = unit.global_position

	for i in range(path.size()):
		var target_point = path[i]
		
		# 1. Callback pour préparer le segment (MAJ direction + play_walk)
		# Capturer les variables nécessaires pour la callback
		var current_start = start_point
		tween.tween_callback(func():
			# Vérifier si unit et animation_component sont toujours valides
			if not is_instance_valid(unit) or not is_instance_valid(animation_component):
				push_warning("MovementComponent [_start_movement]: Unit ou AnimationComponent invalide dans callback de segment.")
				# On pourrait arrêter le tween ici, mais laissons-le finir pour l'instant
				return
				
			# Mettre à jour la direction basée sur le segment actuel
			animation_component.update_direction(current_start, target_point)
			# Jouer l'animation de marche
			animation_component.play_walk()
		).set_delay(0.01) # Petit délai pour s'assurer que le tween précédent est fini
		
		# 2. Déplacer l'unité vers le point cible
		tween.tween_property(unit, "global_position", target_point, MOVE_DURATION)
		
		# Mettre à jour le point de départ pour le prochain segment
		start_point = target_point
	
	# Callback final une fois tout le chemin parcouru
	tween.tween_callback(func():
		if not is_instance_valid(unit):
			return
			
		if NavigationService:
			NavigationService.update_unit_position(unit, unit.cell)
		is_moving = false
		if animation_component:
			animation_component.play_idle()
		else:
			push_warning("MovementComponent [_start_movement]: animation_component null dans callback final")
		clear()
	)

func _create_highlight_tile(cell: Vector2i) -> Sprite2D:
	# print("MovementComponent [_CREATE_TILE]: Cellule: ", cell) # Trop verbeux
	if not highlight_texture:
		push_error("MovementComponent [_CREATE_TILE]: highlight_texture non définie dans l'inspecteur!")
		return null # Retourner null si pas de texture
		
	var tile = Sprite2D.new()
	tile.texture = highlight_texture
	if NavigationService:
		tile.position = NavigationService.cell_to_world(cell)
	else:
		push_warning("MovementComponent [_CREATE_TILE]: NavigationService non prêt pour positionner la tuile")
		tile.position = Vector2.ZERO # Position par défaut
	tile.z_index = 20 # Assurer que c'est au-dessus du sol mais potentiellement sous certaines unités
	tile.visible = true # Sera rendu visible par l'animation ou directement
	return tile
