extends Node2D
## Basis für eine Gefechtssteuerung im Labor. Das Labor leitet alle
## Berührungen auf dem Schlachtfeld an die aktive Steuerung weiter.

var lab = null


func activate(p_lab) -> void:
    lab = p_lab


func deactivate() -> void:
    pass


func handle_input(_event: InputEvent) -> void:
    pass


## Kurzer Bedienhinweis, der oben eingeblendet wird.
func hint() -> String:
    return ""


## true, wenn unten links die drei Truppenknöpfe gebraucht werden.
func uses_group_buttons() -> bool:
    return false
