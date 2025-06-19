class_name UnitUI
extends Node2D

# Cible l'AnimatedSprite2D dont le shader doit être modifié
@export var sprite_to_outline: AnimatedSprite2D 
@export var outline_color: Color = Color.WHITE # Couleur par défaut
@export_range(0.0, 0.006, 0.001) var outline_width: float = 0.001

# Chemins restaurés pour pointer directement sous UnitUI
@onready var unit_label: Label = $VboxContainer/UnitName
@onready var health_icon: TextureRect = $VboxContainer/HealthContainer/HealthIcon
@onready var health_label: Label = %HealthLabel # %UniqueName reste valide
@onready var health_container: HBoxContainer = $VboxContainer/HealthContainer

# Référence aux stats de l'unité parente
var _unit_stats: UnitStats

# États pour gérer les différents types de mise en évidence
var _is_mouse_hovering: bool = false
var _is_card_selection_active: bool = false
var _is_portrait_hovering: bool = false # AJOUT : État pour le survol du portrait

func _ready() -> void:
	# Tentative de récupération de l'unité parente
	var parent_unit = get_parent()
	if not parent_unit is Unit:
		push_error("[%s] UnitUI: Le parent n'est pas une Unit!" % name)
		return
	
	# Tentative de récupération des stats de l'unité parente
	# Accède directement à la propriété 'stats' puisque le parent est vérifié comme étant une Unit (ou dérivé)
	# La vérification is_instance_valid ci-dessous gère le cas où 'stats' ne serait pas assigné.
	_unit_stats = parent_unit.stats

	if not is_instance_valid(_unit_stats):
		push_error("[%s] UnitUI: Impossible de récupérer les UnitStats (stats invalides ou non assignées) du parent %s." % [name, parent_unit.name])
		return
	

	# Vérifie si le sprite est bien assigné
	if not is_instance_valid(sprite_to_outline):
		push_warning("[%s] UnitUI: sprite_to_outline N'EST PAS ASSIGNÉ DANS L'INSPECTEUR !" % parent_unit.name)
	# Ne pas retourner ici, l'UI peut fonctionner sans l'outline
		
	# Vérifie si le sprite a un material et le rend unique
	if is_instance_valid(sprite_to_outline) and sprite_to_outline.material:
		sprite_to_outline.material = sprite_to_outline.material.duplicate()
	else:
		if is_instance_valid(sprite_to_outline):
			push_warning("[%s] UnitUI: Le sprite_to_outline n'a pas de material assigné !" % parent_unit.name)
	
	# Connexion aux signaux globaux pour la sélection de carte
	if Events:
		Events.card_selected.connect(_on_Events_card_selected)
		Events.card_unselected.connect(_on_Events_card_unselected)
		Events.card_played.connect(_on_Events_card_played)
		# --- AJOUT : Connexion aux signaux de survol du portrait --- 
		Events.portrait_hover_started.connect(_on_Events_portrait_hover_started)
		Events.portrait_hover_ended.connect(_on_Events_portrait_hover_ended)
	else:
		push_warning("[%s] UnitUI: Autoload 'Events' non trouvé." % parent_unit.name)

	# Connexion aux signaux des stats de l'unité
	_unit_stats.health_changed.connect(_update_health_label)

	# Mise à jour initiale des labels avec les stats actuelles
	_update_name_and_level()
	_update_health_label(_unit_stats.current_health, _unit_stats.current_health) # Appel initial

	# Mise à jour initiale de l'état visuel (tout caché, sauf si survol/sélection déjà actifs)
	_update_visuals()
	
# --- Mise à jour des Labels --- 

func _update_name_and_level() -> void:
	if not is_instance_valid(_unit_stats):
		push_warning("[%s] UnitUI: Tentative de mise à jour du nom/level sans stats valides." % get_parent().name)
		return
	unit_label.text = "%s NIV.%d" % [_unit_stats.unit_name, _unit_stats.level]

func _update_health_label(current_health: int, _previous_health: int) -> void:
	if not is_instance_valid(_unit_stats):
		push_warning("[%s] UnitUI: Tentative de mise à jour du label de vie sans stats valides." % get_parent().name)
		return
	health_label.text = str(current_health) # Met simplement à jour le texte avec la vie actuelle

# --- Gestion des mises à jour visuelles --- 

func _update_visuals() -> void:
	# Vérifie si les noeuds UI sont prêts (ils pourraient ne pas l'être si _ready échoue tôt)
	if not is_node_ready() or not is_instance_valid(unit_label) or not is_instance_valid(health_container):
		# print("[UnitUI %s] _update_visuals SKIPPED (node not ready or elements invalid)" % (get_parent().name if is_instance_valid(get_parent()) else "Unknown")) # DEBUG
		return 

	# Détermine si l'outline doit être affiché (survol OU sélection de carte OU survol portrait)
	var should_show_outline: bool = _is_mouse_hovering or _is_card_selection_active or _is_portrait_hovering
	_apply_outline(should_show_outline)
	
	# Détermine si le nom doit être affiché (survol direct OU survol portrait)
	var should_show_name: bool = _is_mouse_hovering or _is_portrait_hovering
	unit_label.visible = should_show_name
	
	# Détermine si la vie doit être affichée (survol OU sélection de carte OU survol portrait)
	var should_show_health: bool = _is_mouse_hovering or _is_card_selection_active or _is_portrait_hovering
	health_container.visible = should_show_health

func _apply_outline(enable: bool) -> void:
	# Vérifie si le sprite et son material sont valides
	if not is_instance_valid(sprite_to_outline) or not sprite_to_outline.material:
		return
	
	var target_progress: float = 1.0 if enable else 0.0
	# Applique les paramètres uniquement si l'état change pour éviter appels inutiles
	if sprite_to_outline.material.get_shader_parameter("progress") != target_progress:
		var parent_name = get_parent().name if is_instance_valid(get_parent()) else "Unknown"
		if enable:
			# Afficher la raison de l'activation de l'outline
			sprite_to_outline.material.set_shader_parameter("outline_color", outline_color)
			sprite_to_outline.material.set_shader_parameter("width", outline_width)
			sprite_to_outline.material.set_shader_parameter("progress", 1.0)
		else:
			# print("  [%s] Disabling outline" % parent_name) # DEBUG
			sprite_to_outline.material.set_shader_parameter("progress", 0.0)

# --- Gestionnaires de signaux --- 

func _on_unit_mouse_entered() -> void:
	var parent_name = get_parent().name if is_instance_valid(get_parent()) else "Unknown"
	_is_mouse_hovering = true
	_update_visuals()

func _on_unit_mouse_exited() -> void:
	var parent_name = get_parent().name if is_instance_valid(get_parent()) else "Unknown"
	_is_mouse_hovering = false
	_update_visuals()

# Gère la réception du signal global quand une carte est sélectionnée
func _on_Events_card_selected(_card: Card) -> void: # Le paramètre _card n'est pas utilisé ici mais est requis par le signal
	var parent_name = get_parent().name if is_instance_valid(get_parent()) else "Unknown"
	_is_card_selection_active = true
	_update_visuals()

# Gère la réception du signal global quand une carte est désélectionnée
func _on_Events_card_unselected(_card: Card) -> void:
	var parent_name = get_parent().name if is_instance_valid(get_parent()) else "Unknown"
	_is_card_selection_active = false
	_update_visuals()

# Gère la réception du signal global quand une carte est jouée
func _on_Events_card_played(_card: Card, _target_cell: Vector2i) -> void:
	var parent_name = get_parent().name if is_instance_valid(get_parent()) else "Unknown"
	_is_card_selection_active = false # Jouer une carte termine la sélection
	_update_visuals()

# --- AJOUT : Gestionnaires pour le survol du portrait --- 

# Gère la réception du signal global quand un portrait est survolé
func _on_Events_portrait_hover_started(unit: Unit) -> void:
	var parent_unit = get_parent()
	# Vérifier si le signal concerne l'unité parente de CET UnitUI
	if unit == parent_unit:
		_is_portrait_hovering = true
		_update_visuals()

# Gère la réception du signal global quand le survol d'un portrait se termine
func _on_Events_portrait_hover_ended(unit: Unit) -> void:
	var parent_unit = get_parent()

	# Vérifier si le signal concerne l'unité parente de CET UnitUI
	if unit == parent_unit:
		_is_portrait_hovering = false
		_update_visuals()
