class_name RefreshHandAction
extends Action

## Opening hand: the whole hand goes back into the deck and as many cards are drawn again. It can be
## repeated; the player's redraw ends only with a RedrawAction ("keep"). The player's choice only: it is
## not offered by Match.get_legal_actions(), so the AI never uses it.


func _init(player_id: int = 0) -> void:
	super(player_id)
