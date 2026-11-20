extends "res://scenes/lab/controls/control_scheme.gd"
## Steuerung B: eigene Truppe antippen, dann Ziel antippen.
## Gegner antippen = Angriff. Die gewählte Truppe noch einmal antippen = Halt.
## Ist die Artillerie gewählt, gilt die eingestellte Kanonen-Variante.

const UnitGroup := preload("res://scenes/lab/unit_group.gd")
const TAP_DISTANCE := 28.0
const MARKER_TIME := 0.6
## Markiert eine Berührung, die schon zum Auswählen verbraucht wurde.
const CONSUMED := -2

var _finger := -1
var _start := Vector2.ZERO
var _marker := Vector2.ZERO
var _marker_left := 0.0


func hint() -> String:
    return "Eigene Truppe antippen, dann Ziel antippen. Gegner antippen = Angriff."


func deactivate() -> void:
    _finger = -1


func handle_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _on_press(touch, event)
        else:
            _on_release(touch, event)
    elif event is InputEventScreenDrag:
        if lab.cannon_active() and _finger != CONSUMED:
            lab.cannon_ctrl.handle_input(event)


func _on_press(touch: InputEventScreenTouch, event: InputEvent) -> void:
    var own = lab.group_at(touch.position, UnitGroup.SIDE_BLUE)
    if own != null and own != lab.selected_group:
        lab.select_group(own)
        _finger = CONSUMED
        return
    if lab.cannon_active():
        lab.cannon_ctrl.handle_input(event)
        return
    if _finger == -1:
        _finger = touch.index
        _start = touch.position


func _on_release(touch: InputEventScreenTouch, event: InputEvent) -> void:
    if _finger == CONSUMED:
        _finger = -1
        return
    if lab.cannon_active():
        lab.cannon_ctrl.handle_input(event)
        return
    if touch.index != _finger:
        return
    _finger = -1
    if touch.position.distance_to(_start) <= TAP_DISTANCE:
        _order(touch.position)


func _order(point: Vector2) -> void:
    var group = lab.selected_group
    if group == null:
        return
    var foe = lab.group_at(point, UnitGroup.SIDE_GREY)
    if foe != null:
        group.order_attack(foe)
    elif group.position.distance_to(point) <= group.radius():
        group.order_halt()
    else:
        group.order_move(point)
    _marker = point
    _marker_left = MARKER_TIME
    queue_redraw()


func _process(delta: float) -> void:
    if _marker_left > 0.0:
        _marker_left = maxf(_marker_left - delta, 0.0)
        queue_redraw()


func _draw() -> void:
    if _marker_left <= 0.0:
        return
    var grow: float = 1.0 - _marker_left / MARKER_TIME
    draw_arc(_marker, 10.0 + grow * 22.0, 0.0, TAU, 32, Color(1, 1, 1, _marker_left / MARKER_TIME), 3.0)
