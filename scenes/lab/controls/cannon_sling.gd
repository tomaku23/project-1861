extends Node2D
## Kanonen-Variante „Schleuder“: irgendwo aufs Feld drücken, nach hinten
## ziehen und loslassen. Zugrichtung und -länge bestimmen Ziel und Weite.
## Eine gepunktete Flugbahn zeigt vorher, wo die Kugel landet.

const BattleRules := preload("res://core/battle/battle_rules.gd")
const MAX_PULL := 220.0
const MIN_POWER := 0.08
const PREVIEW_DOTS := 16

var lab = null
var _finger := -1
var _start := Vector2.ZERO
var _now := Vector2.ZERO


func hint() -> String:
    return "Kanone: drücken, nach hinten ziehen wie eine Schleuder, loslassen = Schuss."


func cancel() -> void:
    _finger = -1
    queue_redraw()


func handle_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _finger == -1:
            _finger = touch.index
            _start = touch.position
            _now = touch.position
        elif not touch.pressed and touch.index == _finger:
            _finger = -1
            if _power() >= MIN_POWER:
                lab.fire_cannon(lab.selected_group, _landing())
        queue_redraw()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _finger:
            _now = drag.position
            queue_redraw()


func _pull() -> Vector2:
    return _start - _now


func _power() -> float:
    return clampf(_pull().length() / MAX_PULL, 0.0, 1.0)


func _landing() -> Vector2:
    var group = lab.selected_group
    return BattleRules.cannon_landing(group.cannon_muzzle(), _pull(), _power(), group.max_range())


func _draw() -> void:
    if _finger == -1 or lab == null or not lab.cannon_active():
        return
    var group = lab.selected_group
    draw_line(_start, _now, Color(1, 1, 1, 0.5), 3.0)
    draw_circle(_start, 8.0, Color(1, 1, 1, 0.5))
    if _power() < MIN_POWER:
        return
    var origin: Vector2 = group.cannon_muzzle()
    var landing := _landing()
    var distance := origin.distance_to(landing)
    for i in range(1, PREVIEW_DOTS):
        var t: float = float(i) / float(PREVIEW_DOTS)
        var ground := origin.lerp(landing, t)
        var height: float = BattleRules.arc_height(distance, t)
        draw_circle(ground - Vector2(0.0, height), 3.0, Color(1, 1, 1, 0.75))
    var ring := Color(1.0, 0.9, 0.5, 0.95) if group.reload_left <= 0.0 else Color(1, 1, 1, 0.4)
    draw_arc(landing, float(group.stats.get("blast_radius", 45.0)), 0.0, TAU, 40, ring, 2.0)
