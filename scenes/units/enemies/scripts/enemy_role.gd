extends Resource
class_name EnemyRole

@export_category("Identification")
@export var role_name: String = "Default Role" # Pour identification facile

@export_category("Base Role Stats & Affixes")

# --- Points d'Action et Mouvement définis par le rôle --- 
@export var base_action_points: int = 2 # Valeurs d'exemple
@export var base_movement_points: int = 2 # Valeurs d'exemple

@export_category("Level Scaling Rates")
# Taux pour la formule: Stat = Base * pow(Rate, Level-1) 
@export var hp_rate: float = 1.06 # Exemple
@export var dmg_rate: float = 1.05 # Exemple
@export var dr_rate: float = 1.02 # Exemple

@export_category("Affixes")
# Liste des affixes autorisés pour ce rôle
@export var allowed_affixes: Array[EnemyAffix] = []
