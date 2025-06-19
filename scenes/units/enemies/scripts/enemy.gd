extends Unit
class_name Enemy

# Ce script sert de base pour tous les ennemis.
# Il hérite de toutes les fonctionnalités de Unit.gd.
# La logique spécifique (IA, passifs de famille) sera ajoutée ici
# ou dans des scripts/composants enfants dans les phases suivantes.

# --- Propriétés pour les Affixes ---
var affixes: Array[EnemyAffix] = []

# --- Initialisation ---
func _ready() -> void:
	super() # Appelle Unit._ready()
	
	# Log des affixes pour débogage
	if not affixes.is_empty():
		var affix_names = ", ".join(affixes.map(func(a): return a.affix_name))
		print("BaseEnemy (%s): Affixes appliqués: %s" % [name, affix_names])

pass 

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var mouse_cell = NavigationService.world_to_cell(mouse_pos)
		if mouse_cell == cell:
			# S'assurer que movement_component existe
			if movement_component:
				movement_component.show_range()
			else:
				push_warning("EnemyTestUnit: movement_component non trouvé pour show_range.")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# S'assurer que movement_component existe
		if movement_component:
			movement_component.clear()
		else:
			push_warning("EnemyTestUnit: movement_component non trouvé pour clear.")
