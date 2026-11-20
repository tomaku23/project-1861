extends "res://scenes/lab/controls/control_scheme.gd"
## Steuerung A: Truppe über große Knöpfe wählen, dann über das Feld ziehen.
## Richtung und Länge des Wischens bestimmen Marschrichtung und -weite.
## Kurz tippen hält die Truppe an. Ist die Artillerie gewählt, gilt die
## eingestellte Kanonen-Variante.

const TAP_DISTANCE := 24.0
const DISTANCE_FACTOR := 2.5
const ARROW_COLOR := Color(1, 1, 1, 0.8)

var _finger := -1
var _start := Vector2.ZERO
var _now := Vector2.ZERO


func hint() -> String:
    return "Truppe unten wählen, dann über das Feld wischen: Richtung und Weite. Kurz tippen = Halt."


func uses_group_buttons() -> bool:
    return true


func deactivate() -> void:
    _finger = -1


func handle_input(event: InputEvent) -> void:
    if lab.cannon_active():
        lab.cannon_ctrl.handle_input(event)
        return
    var group = lab.selected_group
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _finger == -1:
            _finger = touch.index
            _start = touch.position
            _now = touch.position
        elif not touch.pressed and touch.index == _finger:
            _finger = -1
            if group != null:
                var swipe := _now - _start
                if swipe.length() < TAP_DISTANCE:
                    group.order_halt()
                else:
                    group.order_move(group.position + swipe * DISTANCE_FACTOR)
        queue_redraw()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _finger:
            _now = drag.position
            queue_redraw()


func _draw() -> void:
    if _finger == -1 or lab == null or lab.selected_group == null:
        return
    var swipe := _now - _start
    if swipe.length() < TAP_DISTANCE:
        return
    draw_line(_start, _now, Color(1, 1, 1, 0.25), 2.0)
    var from_pos: Vector2 = lab.selected_group.position
    var to_pos: Vector2 = lab.selected_group._clamp_to_field(from_pos + swipe * DISTANCE_FACTOR)
    draw_line(from_pos, to_pos, ARROW_COLOR, 4.0)
    var head := (to_pos - from_pos).normalized() * 18.0
    draw_line(to_pos, to_pos - head.rotated(0.5), ARROW_COLOR, 4.0)
    draw_line(to_pos, to_pos - head.rotated(-0.5), ARROW_COLOR, 4.0)
