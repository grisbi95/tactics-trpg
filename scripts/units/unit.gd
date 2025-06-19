class_name Unit
extends Area2D

### SIGNALS ###
signal turn_started(unit: Unit)
signal turn_ended
signal defeated(unit: Unit)
signal stats_changed(new_stats: UnitStats)

### VARIABLES ###
@export var stats: UnitStats : set = set_unit_stats
@export var is_enemy: bool = false

# Indique si l'unité peut actuellement être contrôlée (par le joueur ou l'IA)
var _is_controllable: bool = false # Initialiser à false par défaut

# Composants enfants récupérés via @onready.
@onready var stats_ui: UnitUI = $UnitUI
@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var animation_component: AnimationComponent = $AnimationComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var status_manager: StatusManager = $StatusManager

# Propriété calculée pour obtenir la cellule actuelle de l'unité.
var cell: Vector2i:
	get:
		if NavigationService:
			return NavigationService.world_to_cell(global_position)
		else:
			# Retourne une position invalide si le service de navigation n'est pas prêt.
			push_warning("Unit (%s): NavigationService non disponible pour calculer la cellule." % name)
			return NavigationService.INVALID_POSITION # Utiliser la constante définie dans NavigationService

# Indique si l'unité est en train de se déplacer (géré par MovementComponent).
var is_moving: bool = false # Note: Devrait probablement être lu depuis movement_component ?

### INITIALISATION ###

# Appelé une fois que le nœud et ses enfants sont prêts.
func _ready() -> void:
	# S'assurer que les composants essentiels sont présents.
	if not is_instance_valid(animation_component):
		push_error("Unit (%s): @onready var animation_component est invalide!" % name)
	# (MovementComponent est vérifié par le script Player qui l'utilise)
	
	# Initialiser l'état basé sur les stats si elles existent déjà.
	# Sinon, attendre le signal stats_changed.
	if is_instance_valid(stats):
		_initialize_state_from_stats()
	else:
		# Se connecter au signal pour initialiser l'état une fois les stats définies.
		# Utiliser CONNECT_ONE_SHOT car _ready ne sera appelé qu'une fois.
		stats_changed.connect(_initialize_state_from_stats.bind(), CONNECT_ONE_SHOT)

# Setter pour la variable `stats`. Appelé lorsque les stats sont assignées.
func set_unit_stats(new_stats: UnitStats) -> void:
	# Si les nouvelles stats sont les mêmes que les anciennes, ne rien faire.
	if new_stats == stats: 
		return
		
	stats = new_stats
	if is_instance_valid(stats):
		# Initialiser les valeurs par défaut des stats.
		stats.current_health = stats.max_health
		stats.reset_action_points()
		stats.reset_movement_points()
		
		# Émettre le signal pour que les autres composants (UI, etc.) puissent réagir.
		stats_changed.emit(stats)
		
		# Si le nœud est déjà dans l'arbre, on peut initialiser l'état.
		# Sinon, _ready() s'en chargera via la connexion au signal stats_changed.
		if is_inside_tree():
			_initialize_state_from_stats()
	else:
		push_warning("Unit (%s): Assignation de stats nulles." % name)

# Initialise l'état de l'unité une fois que les stats sont disponibles ET que le noeud est prêt.
func _initialize_state_from_stats() -> void:
	# Vérifier si le noeud est prêt et si les stats sont valides.
	if not is_node_ready() or not is_instance_valid(stats):
		return
		
	# Mettre à jour la position dans le service de navigation.
	if NavigationService:
		NavigationService.update_unit_position(self, self.cell)
	else:
		push_warning("Unit (%s): NavigationService non prêt lors de l'initialisation de l'état." % name)

	# Jouer l'animation d'idle.
	if is_instance_valid(animation_component):
		animation_component.play_idle()
	# else: L'erreur est déjà signalée dans _ready si le composant manque.

# Appelée automatiquement lorsque le noeud est sur le point d'être retiré de l'arbre.
func _exit_tree() -> void:
	# Nettoyer la position de l'unité dans le service de navigation.
	if NavigationService:
		NavigationService.remove_unit(self)

### GESTION DES TOURS ###

# Logique COMMUNE exécutée au début du tour de TOUTES les unités.
func start_turn() -> void:
	if not is_instance_valid(stats):
		push_error("Unit (%s): Impossible de démarrer le tour sans stats." % name)
		return
	
	print("=== DÉBUT DU TOUR DE '%s' ===" % name)
	
	# Réinitialiser les points d'action et de mouvement.
	stats.reset_action_points()
	stats.reset_movement_points()
	
	# IMPORTANT : Réduire la durée de tous les effets AVANT de déclencher les effets
	status_manager.reduce_all_effect_durations()
	
	# Créer le contexte pour les effets de début de tour
	var context = EffectContext.new(self, "turn_start")
	status_manager.trigger_effects_by_type(StatusEffect.TriggerType.START_OF_TURN, context)

# Logique exécutée à la fin du tour de l'unité.
func end_turn() -> void:
	# S'assurer que l'unité ne peut plus être contrôlée
	set_controllable(false)
	
	# Créer le contexte pour les effets de fin de tour
	var context = EffectContext.new(self, "turn_end")
	status_manager.trigger_effects_by_type(StatusEffect.TriggerType.END_OF_TURN, context)
	turn_ended.emit()

### GESTION DES STATS ###

# Applique des dégâts à l'unité.
func take_damage(damage: int) -> void:
	# Ignorer si l'unité n'a pas de stats, est déjà vaincue ou si les dégâts sont nuls/négatifs.
	if not is_instance_valid(stats) or stats.current_health <= 0 or damage <= 0:
		return
	
	# --- MODIFICATION : Calcul des dégâts réduits ---
	# Assurer que la réduction est entre 0.0 et 1.0 (clamp possible dans UnitStats si besoin)
	var reduction_factor = clampf(stats.damage_reduction_percent, 0.0, 1.0)
	# Calculer les dégâts flottants après réduction
	var actual_damage_float = float(damage) * (1.0 - reduction_factor)
	# Arrondir au plus proche et s'assurer que c'est au moins 0
	var actual_damage_int = max(0, int(round(actual_damage_float)))
	# -------------------------------------------------
	
	# Appliquer les dégâts CALCULÉS à la vie courante.
	# Le setter 'set_health' dans UnitStats sera appelé automatiquement.
	stats.current_health -= actual_damage_int
	
	# Jouer l'animation de dégât si le composant existe.
	if is_instance_valid(animation_component):
		animation_component.play_hurt()
		# Si les PV tombent à 0 ou moins après les dégâts.
		if stats.current_health <= 0:
			_handle_defeat()
	else:
		# Si pas de composant d'animation, vérifier quand même la défaite.
		push_warning("Unit (%s): animation_component non trouvé pour jouer l'animation de dégât." % name)
		if stats.current_health <= 0:
			_handle_defeat()

# Gère la logique de défaite (animation, signal, suppression).
func _handle_defeat() -> void:
	# Jouer l'animation de mort si possible.
	if is_instance_valid(animation_component):
		animation_component.play_dead()
		# Attendre la fin de l'animation de mort avant d'émettre le signal et de supprimer.
		# TODO: Utiliser animation_component.animation_finished serait plus robuste que le timer.
		await get_tree().create_timer(0.8).timeout 
	
	# Émettre le signal de défaite.
	Events.unit_died.emit(self)
	defeated.emit(self)
	# Supprimer l'unité de la scène.
	# S'assurer que l'instance est toujours valide avant de la supprimer (au cas où elle aurait été supprimée entre temps)
	if is_instance_valid(self):
		queue_free()

# Applique du soin à l'unité.
func receive_healing(amount: int) -> void:
	# Ignorer si l'unité n'a pas de stats, est déjà full vie ou si le soin est nul/négatif.
	if not is_instance_valid(stats) or stats.current_health >= stats.max_health or amount <= 0:
		return

	# Appliquer le soin à la vie courante.
	# Le setter 'set_health' dans UnitStats gère le clamp et les signaux.
	stats.current_health += amount
	
	# TODO: Ajouter potentiellement une animation/effet visuel/sonore de soin ici
	# if is_instance_valid(animation_component):
	# 	animation_component.play_heal_effect()

### GESTION DU MOUVEMENT ###

# Demande au composant de mouvement de déplacer l'unité vers une cellule cible.
func move_to_cell(target_cell: Vector2i) -> void:
	if is_instance_valid(movement_component):
		movement_component.move_to_cell(target_cell)
	else:
		push_error("Unit (%s): movement_component non trouvé pour initier le déplacement." % name)

### CONTROLES ###

# Active ou désactive la capacité de l'unité à agir.
func set_controllable(can_control: bool) -> void:
	_is_controllable = can_control

### GESTION DE UNITUI ###
