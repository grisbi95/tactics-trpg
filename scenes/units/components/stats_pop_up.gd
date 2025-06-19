class_name UnitStatsDisplay # Nom de classe standardisé
extends Node2D

### PARAMÈTRES EXPORTABLES ###
# Apparence des labels flottants
@export_group("Apparence")
@export var font: FontFile
@export var font_size: int = 16
@export var outline_size: int = 2 
@export var outline_color: Color = Color(0, 0, 0, 1)

# Couleurs des différents types de changements de statistiques
@export_group("Couleurs")
@export var damage_color: Color = Color(0.7, 0.1, 0.1, 1)  # Rouge pour les dégâts
@export var heal_color: Color = Color(0.1, 0.7, 0.1, 1)    # Vert pour les soins
@export var action_color: Color = Color(0.1, 0.1, 0.7, 1)  # Bleu pour les points d'action
@export var movement_color: Color = Color(0.7, 0.7, 0.1, 1) # Jaune pour les points de mouvement
@export var critical_color: Color = Color(0.9, 0.1, 0.1, 1) # Rouge vif pour les coups critiques

# Paramètres d'animation des labels flottants
@export_group("Animation")
@export var float_distance: float = 40.0 # Distance verticale parcourue
@export var float_duration: float = 0.5 # Durée de la montée
@export var fade_delay: float = 0.7   # Délai avant le début du fondu
@export var fade_duration: float = 0.3 # Durée du fondu

### VARIABLES INTERNES ###
var unit: Unit = null

### INITIALISATION ###
func _ready() -> void:
	unit = get_parent() as Unit
	if not is_instance_valid(unit):
		push_error("UnitStatsDisplay: Noeud parent n'est pas une Unit valide.")
		set_process(false)
		return
	
	# Tenter de connecter les signaux si les stats sont déjà disponibles.
	# Si les stats sont définies plus tard, Unit devrait émettre un signal
	# (comme stats_changed) auquel on pourrait se connecter pour appeler _connect_signals.
	if is_instance_valid(unit.stats):
		_connect_signals()
	else:
		# Attendre que les stats soient potentiellement définies.
		# Une meilleure approche serait un signal explicite depuis Unit.
		unit.stats_changed.connect(_on_unit_stats_set.bind(), CONNECT_ONE_SHOT)
		push_warning("UnitStatsDisplay: unit.stats non défini dans _ready. Connexion différée via unit.stats_changed.")

# Appelée une fois lorsque les stats de l'unité sont (potentiellement) définies après _ready.
func _on_unit_stats_set() -> void:
	if is_instance_valid(unit) and is_instance_valid(unit.stats):
		_connect_signals()
	else:
		push_error("UnitStatsDisplay: Impossible de connecter les signaux après stats_changed, unit ou stats invalides.")

# Connecte ce composant aux signaux émis par la ressource UnitStats.
func _connect_signals() -> void:
	if not is_instance_valid(unit) or not is_instance_valid(unit.stats):
		push_error("UnitStatsDisplay: Tentative de connexion des signaux avec unit ou stats invalides.")
		return
	
	# Se connecter seulement si pas déjà connecté pour éviter les doublons.
	if not unit.stats.health_changed.is_connected(_on_health_changed):
		unit.stats.health_changed.connect(_on_health_changed)
	
	if not unit.stats.movement_points_changed.is_connected(_on_movement_points_changed):
		unit.stats.movement_points_changed.connect(_on_movement_points_changed)
	
	if not unit.stats.action_points_changed.is_connected(_on_action_points_changed):
		unit.stats.action_points_changed.connect(_on_action_points_changed)
	
	# NOTE: La connexion à unit.stats.stats_changed est retirée pour éviter
	# la redondance avec les signaux spécifiques et les vérifications manuelles.

### GESTIONNAIRES DE SIGNAUX ###

# Affiche un nombre flottant pour les changements de PV.
func _on_health_changed(current: int, previous: int) -> void:
	var health_diff: int = current - previous
	# Ne rien afficher si pas de changement.
	if health_diff == 0: return
		
	var color: Color = heal_color 
	var value: int = abs(health_diff)
	var prefix: String = "+" if health_diff > 0 else "-"
	
	create_floating_number(value, color, prefix)

# Affiche un nombre flottant pour les changements de PM.
func _on_movement_points_changed(current: int, previous: int) -> void:
	var movement_diff: int = current - previous
	if movement_diff == 0: return
		
	var prefix: String = "+" if movement_diff > 0 else "-"
	# Afficher avec un léger décalage vertical pour ne pas superposer avec les PV.
	create_floating_number(abs(movement_diff), movement_color, prefix, -16) # Décalage Y ajusté

# Affiche un nombre flottant pour les changements de PA.
func _on_action_points_changed(current: int, previous: int) -> void:
	var action_diff: int = current - previous
	if action_diff == 0: return
		
	var prefix: String = "+" if action_diff > 0 else "-"
	# Afficher avec un autre décalage vertical.
	create_floating_number(abs(action_diff), action_color, prefix, -32) # Décalage Y ajusté

### CRÉATION DU NOMBRE FLOTTANT ###

# Crée, configure et anime un label pour afficher un changement de stat.
func create_floating_number(value: int, color: Color, prefix: String = "", y_offset: float = 0) -> void:
	# Vérifier si la police est définie (essentiel pour l'affichage).
	if not font:
		push_error("UnitStatsDisplay: Police (font) non définie dans l'inspecteur!")
		return
		
	# Créer un conteneur Node2D pour gérer la position et la modulation globales du label.
	var container := Node2D.new()
	add_child(container)
	container.position = Vector2(0, y_offset) # Position initiale avec décalage vertical
	container.z_index = 1000 # S'assurer qu'il s'affiche au-dessus des autres éléments
	
	# Créer et configurer le Label.
	var label := Label.new()
	container.add_child(label)
	label.text = prefix + str(value)
	
	# Appliquer les paramètres de texte (police, taille, couleur, contour).
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = outline_size
	settings.outline_color = outline_color
	label.label_settings = settings
	
	# Centrer le label horizontalement (basé sur sa taille minimale).
	label.position.x = -label.get_minimum_size().x / 2.0
	
	# Animer le conteneur (montée et fondu).
	var tween = create_tween()
	tween.set_parallel(true) # Permettre aux animations de position et de modulation de se dérouler en même temps
	
	# Animation de montée (interpolation de la position Y).
	tween.tween_property(container, "position:y", container.position.y - float_distance, float_duration)\
		 .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # Transition plus douce
	
	# Animation de disparition (interpolation de la modulation alpha).
	tween.tween_property(container, "modulate:a", 0.0, fade_duration)\
		 .set_delay(fade_delay) # Démarrer le fondu après un délai
	
	# Connecter la suppression du conteneur à la fin du tween.
	tween.finished.connect(container.queue_free.bind(), CONNECT_ONE_SHOT)
