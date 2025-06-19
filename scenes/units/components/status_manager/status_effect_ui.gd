class_name StatusEffectUI
extends Control

# UI pour afficher un StatusEffect individuel
# S'inspire de l'ancien StatusUI mais adapté aux nouveaux StatusEffect

@export var status_effect: StatusEffect : set = set_status_effect

@onready var icon: TextureRect = $Icon
@onready var duration_label: Label = $Duration
@onready var intensity_label: Label = $Intensity


func set_status_effect(new_effect: StatusEffect) -> void:
	if not is_node_ready():
		await ready
	
	if status_effect and status_effect.effect_expired.is_connected(_on_effect_expired):
		status_effect.effect_expired.disconnect(_on_effect_expired)
	
	status_effect = new_effect
	
	if is_instance_valid(status_effect):
		# Configurer l'icône
		if status_effect.icon:
			icon.texture = status_effect.icon
		
		# Connecter les signaux pour mises à jour
		if not status_effect.effect_expired.is_connected(_on_effect_expired):
			status_effect.effect_expired.connect(_on_effect_expired)
		
		_update_display()


func _update_display() -> void:
	if not is_instance_valid(status_effect):
		return
	
	# Afficher la durée si l'effet a une durée limitée
	if status_effect.base_duration > 0:
		duration_label.visible = true
		duration_label.text = str(status_effect.current_duration)
	else:
		duration_label.visible = false
	
	# Afficher l'intensité si différente de 1.0
	if status_effect.intensity != 1.0:
		intensity_label.visible = true
		intensity_label.text = str(int(status_effect.intensity))
	else:
		intensity_label.visible = false
	
	# Ajuster la taille du conteneur
	custom_minimum_size = icon.size
	if duration_label.visible:
		custom_minimum_size = duration_label.size + duration_label.position
	elif intensity_label.visible:
		custom_minimum_size = intensity_label.size + intensity_label.position
	
	# Tooltip avec description détaillée
	tooltip_text = status_effect.get_description_with_values()


func _on_effect_expired(effect: StatusEffect) -> void:
	# L'effet a expiré, retirer l'UI
	queue_free()


# Pour les clics (affichage d'informations détaillées)
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse") and is_instance_valid(status_effect):
		# Émettre un signal global pour afficher les détails
		if Events.has_signal("status_effect_tooltip_requested"):
			Events.status_effect_tooltip_requested.emit([status_effect])
		else:
			print("StatusEffect: %s" % status_effect.get_description_with_values()) 