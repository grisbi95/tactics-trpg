class_name AnimationComponent
extends Node2D

# Énumérations pour gérer les états et directions de l'animation.
enum Direction { UP, DOWN, LEFT, RIGHT }
enum AnimState { IDLE, WALK, HURT, ATTACK, DEAD }

# Référence au nœud AnimatedSprite2D qui affiche les animations.
@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D

# Variables pour suivre l'état actuel.
var current_direction: Direction = Direction.DOWN
var current_state: AnimState = AnimState.IDLE

func _ready() -> void:
	# Vérifier si le sprite est valide et connecter le signal.
	if is_instance_valid(sprite):
		sprite.animation_finished.connect(_on_animation_finished)
	else:
		push_error("AnimationComponent: AnimatedSprite2D ('../AnimatedSprite2D') non trouvé ou invalide.")
		set_process(false) # Désactiver si le sprite manque
		return # Quitter si le sprite est invalide

	# Utiliser call_deferred pour calculer la direction initiale après 
	# que la position globale du parent soit probablement définie.
	call_deferred("_calculate_initial_direction")
	
	# Jouer l'animation IDLE par défaut immédiatement (sera corrigée par call_deferred si nécessaire)
	# Cela évite que l'unité soit invisible pendant un court instant.
	if current_state == AnimState.IDLE:
		_play_current_animation()

# Fonction différée pour calculer la direction initiale
func _calculate_initial_direction() -> void:
	# Définir la direction initiale basée sur la position par rapport au centre de la grille
	if not is_inside_tree(): # Vérification supplémentaire, même si peu probable en différé
		push_warning("AnimationComponent: _calculate_initial_direction appelée hors de l'arbre ?")
		return
		
	var parent_node = get_parent()
	# Vérifier que le parent est valide et a une position globale
	if is_instance_valid(parent_node) and parent_node.has_method("get_global_position"):
		var parent_global_pos: Vector2 = parent_node.get_global_position()
		
		# Vérifier si NavigationService est prêt
		if not NavigationService:
			push_warning("AnimationComponent (%s): NavigationService non prêt (différé)." % parent_node.name)
			return
			
		# Récupérer le centre de la grille (en coordonnées de cellule)
		var center_cell: Vector2i = NavigationService.get_grid_center_cell()
		
		# Vérifier si le centre a été correctement initialisé
		if center_cell == NavigationService.INVALID_POSITION:
			push_warning("AnimationComponent (%s): Centre de grille invalide (différé)." % parent_node.name)
			return

		# Convertir le centre de la grille (cellule) en position globale
		var grid_center_world: Vector2 = NavigationService.cell_to_world(center_cell)

		# Calculer le vecteur de l'unité VERS le centre de la grille
		var diff: Vector2 = grid_center_world - parent_global_pos

		# Sauvegarder l'ancienne direction pour vérifier si elle change
		var old_direction = current_direction
		
		# --- NOUVELLE LOGIQUE : Basée sur l'angle (similaire à update_direction) --- 
		var angle: float = NAN # Initialiser angle
		# Ne rien faire si le vecteur est nul (unité pile au centre?)
		if not diff.is_zero_approx(): 
			angle = diff.angle()
			# Logique angulaire pour 4 directions (copiée/adaptée de update_direction)
			# HAUT:   entre -90° et 0°   (-PI/2 à 0)
			# DROITE: entre 0° et 90°    (0 à PI/2)
			# BAS:    entre 90° et 180°  (PI/2 à PI)
			# GAUCHE: entre -180° et -90° (-PI à -PI/2)
			if angle > -PI / 2.0 and angle <= 0: 
				current_direction = Direction.UP
			elif angle > 0 and angle <= PI / 2.0:
				current_direction = Direction.RIGHT
			elif angle > PI / 2.0 and angle <= PI:
				current_direction = Direction.DOWN
			else: # angle <= -PI / 2.0 (et angle > -PI par définition de angle())
				current_direction = Direction.LEFT
		# else: Si diff est nulle, on garde la direction par défaut (DOWN) et angle reste NAN
		
		# --- FIN NOUVELLE LOGIQUE --- 

		# Re-jouer l'animation idle SEULEMENT si la direction a effectivement changé
		if current_state == AnimState.IDLE and old_direction != current_direction:
			_play_current_animation()
	else:
		push_warning("AnimationComponent: Parent node non trouvé (différé)." % parent_node.name)

# --- Fonctions publiques pour changer l'état de l'animation --- 

func play_idle() -> void:
	current_state = AnimState.IDLE
	_play_current_animation()

func play_walk() -> void:
	current_state = AnimState.WALK
	_play_current_animation()

func play_hurt() -> void:
	current_state = AnimState.HURT
	_play_current_animation()

func play_attack() -> void:
	current_state = AnimState.ATTACK
	_play_current_animation()

func play_dead() -> void:
	current_state = AnimState.DEAD
	_play_current_animation()

# --- Logique interne --- 

# Construit le nom de l'animation basé sur l'état et la direction, puis la joue.
func _play_current_animation() -> void:
	if not is_instance_valid(sprite):
		return
		
	# Construire le nom (ex: "WalkDown", "IdleUp", "HurtLeft")
	var state_str := ""
	var dir_str := ""
	
	match current_state:
		AnimState.IDLE: state_str = "Idle"
		AnimState.WALK: state_str = "Walk"
		AnimState.HURT: state_str = "Hurt"
		AnimState.ATTACK: state_str = "Attack"
		AnimState.DEAD: state_str = "Dead"
	
	match current_direction:
		Direction.UP: dir_str = "Up"
		Direction.DOWN: dir_str = "Down"
		Direction.LEFT: dir_str = "Left"
		Direction.RIGHT: dir_str = "Right"
	
	var anim_name: String = state_str + dir_str
	
	# Jouer l'animation seulement si elle existe et est différente de l'actuelle.
	if sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)
	# else: # Optionnel: Gérer le cas où l'animation n'existe pas
	# 	 push_warning("AnimationComponent: Animation '%s' non trouvée." % anim_name)

# Met à jour la direction basée sur le vecteur de déplacement.
func update_direction(from: Vector2, to: Vector2) -> void:
	var diff: Vector2 = to - from
	# Ne rien faire si le vecteur est nul (évite erreurs et changements inutiles)
	if diff.is_zero_approx(): 
		# print("AnimationComponent: diff nul, pas de changement de direction") # Debug
		return 
	
	var old_direction: Direction = current_direction
	
	# Logique basée sur les angles pour 4 directions ISOMÉTRIQUES
	var angle: float = diff.angle()
	
	# --- Logique angulaire pour isométrique (Corrigée selon logs) --- 
	# Division basée sur les quadrants et les angles observés:
	# HAUT (Q4):   entre -90° et 0°   (-PI/2 à 0)
	# DROITE (Q1): entre 0° et 90°    (0 à PI/2)
	# BAS (Q2):    entre 90° et 180°  (PI/2 à PI)
	# GAUCHE (Q3): entre -180° et -90° (-PI à -PI/2)
	
	# Note: angle() retourne une valeur dans [-PI, PI]
	
	if angle > -PI / 2.0 and angle <= 0: 
		current_direction = Direction.UP
	elif angle > 0 and angle <= PI / 2.0:
		current_direction = Direction.RIGHT
	elif angle > PI / 2.0 and angle <= PI:
		current_direction = Direction.DOWN
	else: # angle <= -PI / 2.0 (et angle > -PI par définition de angle())
		current_direction = Direction.LEFT
		
	# --- LOGGING --- 
	# Commenter ou supprimer ces logs une fois la fonctionnalité validée
	# print("--- Animation Update ---")
	# print("  From: %s, To: %s" % [from, to])
	# print("  Diff: %s" % diff)
	# print("  Angle (rad): %s" % angle)
	# print("  Angle (deg): %s" % rad_to_deg(angle))
	# print("  Old Direction: %s" % Direction.keys()[old_direction])
	# print("  New Direction: %s" % Direction.keys()[current_direction])
	# print("------------------------")
	# ------------- 

	# Si la direction a changé pendant une animation, la mettre à jour immédiatement.
	if old_direction != current_direction and is_instance_valid(sprite) and sprite.is_playing():
		_play_current_animation()
	# else: # Debug
		# if is_instance_valid(sprite) and not sprite.is_playing():
		# 	print("  Sprite not playing, will call _play_current_animation via tween callback.")
		# elif old_direction == current_direction:
		# 	print("  Direction hasn't changed.")

# Appelée lorsque l'animation actuelle du sprite se termine.
func _on_animation_finished() -> void:
	# Certaines animations (Hurt, Attack) doivent revenir à l'état Idle.
	match current_state:
		AnimState.HURT, AnimState.ATTACK:
			play_idle()
		# L'animation DEAD reste sur la dernière frame.
		# L'animation WALK est gérée par les appels continus à play_walk ou play_idle.
		# L'animation IDLE boucle ou reste sur la dernière frame selon sa configuration.
