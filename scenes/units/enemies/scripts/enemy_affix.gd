extends Resource
class_name EnemyAffix

# Énumération pour distinguer les types d'affixes
enum AffixType { STAT, EFFECT }

@export_category("Identification & Type")
@export var affix_name: String = "Default Affix"
@export var type: AffixType = AffixType.STAT

@export_category("STAT Modifications")
# Modificateurs appliqués aux stats (après scaling, avant clamp final)
@export var hp_multiplier: float = 1.0          # Multiplicateur % PV (ex: 1.1 pour +10%)
@export var damage_multiplier: float = 1.0      # Multiplicateur % Dégâts
@export var damage_reduction_add: float = 0.0 # Ajout à la % Réduction
@export var ap_delta: int = 0                   # Modificateur PA
@export var mp_delta: int = 0                   # Modificateur PM
@export var range_delta: int = 0                # Modificateur Portée
@export var heal_multiplier: float = 1.0        # Multiplicateur % Soin reçu/émis ? (à clarifier)
# TODO: S'assurer que ces 7 champs couvrent bien les 8 affixes STAT prévus.

@export_category("EFFECT Application")
# Statut appliqué par l'affixe (si type == EFFECT)
# Exemples: "Poison", "Gel", "Choc", "Suppression"
# FIXME: Utiliser un enum global StatusEffect.Type si défini, sinon String
@export var applies_status: String = "" 
 
