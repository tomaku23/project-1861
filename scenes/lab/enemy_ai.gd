extends RefCounted
## Sehr einfache Gegner-KI für das Labor: Die Infanterie rückt bis auf
## Schussweite vor, die Kavallerie greift nach einer Weile an, die Kanone
## schießt mit Streuung auf die nächste blaue Truppe.

const UnitGroup := preload("res://scenes/lab/unit_group.gd")
const THINK_INTERVAL := 0.5
const CAVALRY_DELAY := 8.0
const CANNON_SPREAD := Vector2(70.0, 50.0)

var _think_left := 0.0
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()


func reset() -> void:
    _think_left = 1.0
    _elapsed = 0.0
    _rng.randomize()


func update(lab, delta: float) -> void:
    _elapsed += delta
    _think_left -= delta
    for group in lab.living_groups(UnitGroup.SIDE_GREY):
        if group.kind == "artillerie":
            _fire_cannon(lab, group)
    if _think_left > 0.0:
        return
    _think_left = THINK_INTERVAL
    for group in lab.living_groups(UnitGroup.SIDE_GREY):
        var target = lab.nearest_enemy(group)
        if target == null:
            group.order_halt()
            continue
        if group.kind == "infanterie":
            var distance: float = group.position.distance_to(target.position)
            if distance > group.max_range() * 0.75:
                group.order_move(target.position)
            else:
                group.has_move_target = false
            group.attack_target = target
        elif group.kind == "kavallerie" and _elapsed >= CAVALRY_DELAY:
            group.order_attack(target)


func _fire_cannon(lab, group) -> void:
    if group.reload_left > 0.0:
        return
    var target = lab.nearest_enemy(group, group.max_range())
    if target == null:
        return
    var miss := Vector2(
        _rng.randf_range(-CANNON_SPREAD.x, CANNON_SPREAD.x),
        _rng.randf_range(-CANNON_SPREAD.y, CANNON_SPREAD.y)
    )
    lab.fire_cannon(group, target.position + miss)
