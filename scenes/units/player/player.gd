class_name Player
extends Unit

### VARIABLES ###
var is_dragging: bool = false
var drag_start_pos: Vector2
var is_valid_target: bool = false

### FONCTIONS ###

func _ready() -> void:
	# Les prints de débogage seront retirés si nécessaire.
	# print("Player [_READY]: >>> Début spécific Player")
	# print("Player [_READY]: Appel super()._ready()")
	super() # Appelle Unit._ready()
	# print("Player [_READY]: <<< Fin spécific Player")

# Pas besoin de _exit_tree() ici si Player n'a pas de nettoyage spécifique à faire.
# Unit._exit_tree() sera appelé automatiquement.
# func _exit_tree() -> void:
# 	print("Player [_EXIT_TREE]: Début")
# 	# Ajouter ici toute logique de nettoyage spécifique à Player
# 	super._exit_tree() # Appeler la logique de nettoyage de Unit
# 	print("Player [_EXIT_TREE]: Fin")

func _input(event: InputEvent) -> void:
	# NE PAS traiter l'input si l'unité n'est pas contrôlable !
	if not _is_controllable:
		# print("Player: Input ignoré (non contrôlable)") # Décommenter pour debug
		return
		
	# Filtrer les événements pour ne traiter que ceux pertinents.
	if event is InputEventMouseButton or (event is InputEventMouseMotion and is_dragging):
		# print("Player [_INPUT]: Event reçu: ", event.as_text()) # Garder commenté sauf pour débogage
		if event is InputEventMouseButton:
			_handle_mouse_button(event)
		elif event is InputEventMouseMotion and is_dragging:
			_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# print("Player [HANDLE_MOUSE_BUTTON]: Event: ", event.as_text())
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			var mouse_cell = NavigationService.world_to_cell(mouse_pos)
			# print("Player [HANDLE_MOUSE_BUTTON]: Clic Gauche Pressé. Mouse cell: ", mouse_cell, " Unit cell: ", cell)
			# Si le clic est sur la cellule du joueur, démarrer le glisser-déposer.
			if mouse_cell == cell:
				# print("Player [HANDLE_MOUSE_BUTTON]: Clic sur joueur, démarrage drag")
				_start_drag(mouse_pos)
				if movement_component: # Vérifier si le composant existe
					movement_component.show_range()
		else: # Bouton gauche relâché
			# print("Player [HANDLE_MOUSE_BUTTON]: Clic Gauche Relâché")
			_end_drag()
			if movement_component: # Vérifier si le composant existe
				movement_component.clear()

func _handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	var mouse_pos = get_global_mouse_position()
	var target_cell = NavigationService.world_to_cell(mouse_pos)
	
	# Vérifier si la cellule cible est une destination valide pour un déplacement.
	var new_valid_target = NavigationService.is_valid_path(cell, target_cell)
	
	# Mettre à jour l'état et l'aperçu du chemin seulement si la validité change.
	if new_valid_target != is_valid_target:
		is_valid_target = new_valid_target
		# print("Player [HANDLE_MOUSE_MOTION]: Validité cible changée: ", is_valid_target)
	
	if movement_component: # Vérifier si le composant existe
		movement_component.update_hover_path(target_cell)

func _start_drag(start_pos: Vector2) -> void:
	# print("Player [START_DRAG]: Début")
	is_dragging = true
	drag_start_pos = start_pos

func _end_drag() -> void:
	# print("Player [END_DRAG]: Début")
	if is_dragging:
		is_dragging = false
		var mouse_pos = get_global_mouse_position()
		var target_cell = NavigationService.world_to_cell(mouse_pos)
		# print("Player [END_DRAG]: Target cell: ", target_cell, " Valide: ", is_valid_target)
		
		# Si la cellule cible est valide, initier le mouvement.
		if is_valid_target and movement_component:
			movement_component.move_to_cell(target_cell)
		# Sinon, réinitialiser l'aperçu du chemin (visuellement).
		elif movement_component:
			movement_component.update_hover_path(cell) # Afficher le chemin vers la cellule actuelle (aucun chemin)
	# print("Player [END_DRAG]: Fin")

# Fonction _cleanup_unit supprimée car remplacée par _exit_tree dans la classe Unit.
