class_name StatusManager
extends GridContainer

# Gestionnaire des effets de statuts pour une unité
# Remplace l'ancien StatusHandler avec une logique beaucoup plus sophistiquée

signal effect_applied(effect: StatusEffect)
signal effect_removed(effect: StatusEffect)
signal stats_modified()

const STATUS_EFFECT_UI = preload("res://scenes/units/components/status_manager/status_effect_ui.tscn")

@export var owner_unit: Unit

# Collections d'effets organisées pour efficacité
var stat_modifier_effects: Dictionary = {}  # UnitStats.StatType -> Array[StatModifierEffect]
var behavioral_effects: Array[BehavioralEffect] = []
var effects_by_trigger: Dictionary = {}  # StatusEffect.TriggerType -> Array[StatusEffect]
var all_active_effects: Array[StatusEffect] = []

# Cache des modificateurs (pour optimisation future)
var cached_stat_totals: Dictionary = {}
var cache_dirty: bool = true

# Mapping effect -> UI pour gérer l'affichage
var effect_to_ui: Dictionary = {}  # StatusEffect -> Control

func _ready() -> void:
	if not is_instance_valid(owner_unit):
		push_error("StatusManager: owner_unit non défini!")
		return
	
	# Configuration du GridContainer pour l'affichage
	columns = 3  # Affichage en grille 3 colonnes
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	
	print("StatusManager: Initialisé pour l'unité '%s'" % owner_unit.name)

# Ajoute un nouvel effet de statut à l'unité
func add_status_effect(effect_resource: StatusEffect) -> bool:
	if not is_instance_valid(effect_resource):
		push_error("StatusManager: Tentative d'ajout d'un effet invalide")
		return false
	
	if not effect_resource.can_apply_to(owner_unit):
		print("StatusManager: Effet '%s' ne peut pas être appliqué à '%s'" % [effect_resource.effect_id, owner_unit.name])
		return false
	
	# Créer une instance unique de l'effet pour cette unité
	var effect_instance = effect_resource.duplicate(true) as StatusEffect
	
	# Gérer le stacking selon le comportement défini
	var handled_by_stacking = _handle_effect_stacking(effect_instance)
	if handled_by_stacking:
		return true
	
	# Ajouter le nouvel effet
	_register_new_effect(effect_instance)
	
	# Initialiser l'effet
	effect_instance.initialize_effect(owner_unit)
	
	# Connecter les signaux pour gérer l'expiration
	effect_instance.effect_expired.connect(_on_effect_expired)
	effect_instance.effect_triggered.connect(_on_effect_triggered)
	
	# Créer l'UI pour cet effet
	_create_effect_ui(effect_instance)
	
	effect_applied.emit(effect_instance)
	
	print("StatusManager: Effet '%s' ajouté à '%s'" % [effect_instance.effect_id, owner_unit.name])
	return true

# Créer l'UI pour un effet de statut
func _create_effect_ui(effect: StatusEffect) -> void:
	var effect_ui = STATUS_EFFECT_UI.instantiate() as Control
	add_child(effect_ui)
	effect_ui.set("status_effect", effect)  # Utiliser set() au lieu d'accès direct
	effect_to_ui[effect] = effect_ui
	print("StatusManager: UI créée pour l'effet '%s'" % effect.effect_id)

# Gère l'accumulation d'effets selon leur StackingBehavior
func _handle_effect_stacking(new_effect: StatusEffect) -> bool:
	var existing_effect = _find_effect_by_id(new_effect.effect_id)
	if not existing_effect:
		return false  # Pas de stacking nécessaire, c'est un nouvel effet
	
	match new_effect.stacking_behavior:
		StatusEffect.StackingBehavior.REPLACE:
			print("StatusManager: Remplacement de l'effet '%s'" % existing_effect.effect_id)
			remove_status_effect(existing_effect)
			return false  # Continuer avec l'ajout du nouvel effet
		
		StatusEffect.StackingBehavior.ADD_DURATION:
			existing_effect.current_duration += new_effect.base_duration
			_update_effect_ui(existing_effect)  # Mettre à jour l'UI
			print("StatusManager: Durée de '%s' étendue à %d tours" % [existing_effect.effect_id, existing_effect.current_duration])
			return true
		
		StatusEffect.StackingBehavior.ADD_INTENSITY:
			# Si c'est un StatModifierEffect, retirer l'ancien effet avant de modifier l'intensité
			if existing_effect is StatModifierEffect:
				var stat_effect = existing_effect as StatModifierEffect
				stat_effect.remove_stat_modification()  # Retire avec l'ancienne intensité
			
			existing_effect.intensity += new_effect.intensity  # Maintenant on peut changer l'intensité
			
			# Réappliquer avec la nouvelle intensité
			if existing_effect is StatModifierEffect:
				var stat_effect = existing_effect as StatModifierEffect
				stat_effect.apply_stat_modification()  # Applique avec la nouvelle intensité
			
			_update_effect_ui(existing_effect)  # Mettre à jour l'UI
			print("StatusManager: Intensité de '%s' augmentée à %.1f" % [existing_effect.effect_id, existing_effect.intensity])
			return true
		
		StatusEffect.StackingBehavior.INDEPENDENT:
			print("StatusManager: Effet '%s' coexiste indépendamment" % new_effect.effect_id)
			return false  # Laisser coexister
	
	return false

# Met à jour l'UI d'un effet existant
func _update_effect_ui(effect: StatusEffect) -> void:
	if effect in effect_to_ui:
		var ui = effect_to_ui[effect] as Control
		if is_instance_valid(ui) and ui.has_method("_update_display"):
			ui._update_display()

# Enregistre un nouvel effet dans toutes les collections appropriées
func _register_new_effect(effect: StatusEffect) -> void:
	# Ajouter à la liste générale
	all_active_effects.append(effect)
	
	# Organiser par type pour efficacité
	if effect is StatModifierEffect:
		var stat_effect = effect as StatModifierEffect
		if not stat_modifier_effects.has(stat_effect.stat_type):
			stat_modifier_effects[stat_effect.stat_type] = []
		stat_modifier_effects[stat_effect.stat_type].append(stat_effect)
	
	elif effect is BehavioralEffect:
		behavioral_effects.append(effect as BehavioralEffect)
	
	# Organiser par déclencheur
	if not effects_by_trigger.has(effect.trigger_type):
		effects_by_trigger[effect.trigger_type] = []
	effects_by_trigger[effect.trigger_type].append(effect)

# Déclenche tous les effets d'un type donné
func trigger_effects_by_type(trigger_type: StatusEffect.TriggerType, context: EffectContext = null) -> void:
	var effects = effects_by_trigger.get(trigger_type, [])
	if effects.is_empty():
		return
	
	# Créer un contexte par défaut si aucun n'est fourni
	if not context:
		context = EffectContext.new(owner_unit, StatusEffect.TriggerType.keys()[trigger_type].to_lower())
	
	# Trier par priorité (plus haute = première)
	effects.sort_custom(func(a, b): return a.priority > b.priority)
	
	print("StatusManager: Déclenchement de %d effets pour %s sur '%s'" % [effects.size(), StatusEffect.TriggerType.keys()[trigger_type], owner_unit.name])
	
	# Traiter chaque effet du type spécifié
	for effect in effects:
		if is_instance_valid(effect):
			effect.trigger_effect(owner_unit, context)

# Nouvelle méthode : Réduit la durée de TOUS les effets et retire ceux qui expirent
func reduce_all_effect_durations() -> void:
	print("StatusManager: Réduction de la durée de tous les effets sur '%s'" % owner_unit.name)
	
	var effects_to_remove: Array[StatusEffect] = []
	
	# Parcourir tous les effets actifs
	for effect in all_active_effects:
		if is_instance_valid(effect) and effect.base_duration > 0:
			print("  - Effet '%s': durée %d → %d" % [effect.effect_id, effect.current_duration, effect.current_duration - 1])
			
			# Mettre à jour l'UI avant la réduction
			_update_effect_ui(effect)
			
			# Réduire la durée
			if effect.reduce_duration():
				effects_to_remove.append(effect)
				print("    → Effet '%s' expiré !" % effect.effect_id)
			else:
				# Mettre à jour l'UI après la réduction
				_update_effect_ui(effect)
	
	# Retirer les effets expirés
	for expired_effect in effects_to_remove:
		remove_status_effect(expired_effect)

# Retire un effet de statut de l'unité
func remove_status_effect(effect: StatusEffect) -> bool:
	if not effect in all_active_effects:
		return false
	
	print("StatusManager: Retrait de l'effet '%s' de '%s'" % [effect.effect_id, owner_unit.name])
	
	# Retirer l'UI associée
	_remove_effect_ui(effect)
	
	# Retirer de toutes les collections
	all_active_effects.erase(effect)
	
	if effect is StatModifierEffect:
		var stat_effect = effect as StatModifierEffect
		if stat_modifier_effects.has(stat_effect.stat_type):
			stat_modifier_effects[stat_effect.stat_type].erase(stat_effect)
	
	elif effect is BehavioralEffect:
		behavioral_effects.erase(effect as BehavioralEffect)
	
	if effects_by_trigger.has(effect.trigger_type):
		effects_by_trigger[effect.trigger_type].erase(effect)
	
	# Nettoyer l'effet
	effect.expire_effect(owner_unit)
	
	# Déconnecter les signaux
	if effect.effect_expired.is_connected(_on_effect_expired):
		effect.effect_expired.disconnect(_on_effect_expired)
	if effect.effect_triggered.is_connected(_on_effect_triggered):
		effect.effect_triggered.disconnect(_on_effect_triggered)
	
	effect_removed.emit(effect)
	
	return true

# Retire l'UI associée à un effet
func _remove_effect_ui(effect: StatusEffect) -> void:
	if effect in effect_to_ui:
		var ui = effect_to_ui[effect]
		if is_instance_valid(ui):
			ui.queue_free()
		effect_to_ui.erase(effect)

# Trouve un effet par son ID
func _find_effect_by_id(effect_id: String) -> StatusEffect:
	for effect in all_active_effects:
		if effect.effect_id == effect_id:
			return effect
	return null

# Retourne une copie de tous les effets actifs
func get_all_effects() -> Array[StatusEffect]:
	return all_active_effects.duplicate()

# Callbacks pour les signaux des effets
func _on_effect_expired(effect: StatusEffect) -> void:
	remove_status_effect(effect)

func _on_effect_triggered(effect: StatusEffect) -> void:
	print("StatusManager: Effet '%s' déclenché sur '%s'" % [effect.effect_id, owner_unit.name])

# Pour les clics (compatibilité avec l'ancien système)
func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		if Events.has_signal("status_effect_tooltip_requested"):
			Events.status_effect_tooltip_requested.emit(get_all_effects())
		else:
			print("StatusManager: %d effets actifs sur '%s'" % [all_active_effects.size(), owner_unit.name]) 
