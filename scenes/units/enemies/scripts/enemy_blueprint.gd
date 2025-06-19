### res://enemies/scripts/enemy_blueprint.gd
extends Resource
class_name EnemyBlueprint

@export_category("Identification & Core Components")
@export var blueprint_id: String = "default_blueprint" # Identifiant unique (ex: "goblin_scout", "orc_brute")
@export var role: EnemyRole
@export var visual: SpriteFrames
@export var base_stats: UnitStats # Assurez-vous que c'est bien UnitStats ou EnemyStats selon votre structure
# Coût fixe du blueprint (utilisé par EncounterManager pour le budget)
@export var cost: int = 1

@export_category("Customization & Behavior")
@export var preferred_affixes: Array[EnemyAffix] = []
