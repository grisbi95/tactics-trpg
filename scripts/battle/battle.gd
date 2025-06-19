class_name Battle
extends Node2D

#region SIGNAUX
signal board_regenerated
#endregion

#region VARIABLES PRIVÉES
var _board: Board
#endregion

#region FONCTIONS VIRTUELLES
func _ready() -> void:
	_setup_board_reference()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_regenerate_board()
#endregion

#region FONCTIONS PUBLIQUES
func regenerate_board() -> void:
	"""Régénère le plateau de jeu."""
	if _board:
		_board.generate_board()
		board_regenerated.emit()
	else:
		push_warning("Battle: Aucune référence vers le Board trouvée")
#endregion

#region FONCTIONS PRIVÉES
func _setup_board_reference() -> void:
	"""Configure la référence vers le nœud Board."""
	_board = $Board as Board
	if not _board:
		push_error("Battle: Impossible de trouver le nœud Board")
		return

	# Connecter le signal du board si nécessaire
	if not _board.board_generated.is_connected(_on_board_generated):
		_board.board_generated.connect(_on_board_generated)

func _regenerate_board() -> void:
	"""Régénère le plateau via l'interface publique."""
	regenerate_board()

func _on_board_generated() -> void:
	"""Callback appelé quand le board a fini d'être généré."""
	print_debug("Battle: Board généré avec succès")
#endregion
