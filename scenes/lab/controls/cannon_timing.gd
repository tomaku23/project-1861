extends Node2D
## Kanonen-Variante „Timing“: Ziel antippen, dann im richtigen Moment ein
## zweites Mal tippen. Ein Kreis pulsiert um das Ziel – je kleiner er beim
## zweiten Tippen ist, desto genauer der Schuss.

const BattleRules := preload("res://core/battle/battle_rules.gd")
const PERIOD := 1.2
const MIN_SPREAD := 6.0
const MAX_SPREAD := 85.0
const TAP_DISTANCE := 28.0
## Markiert die Berührung, die gerade geschossen hat (ihr Loslassen zählt nicht).
const CONSUMED := -3

var lab = null
var _has_target := false
var _target := Vector2.ZERO
var _elapsed := 0.0
var _finger := -1
var _press_pos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.randomize()


func hint() -> String:
    if _has_target:
        return "Jetzt tippen, wenn der Kreis am kleinsten ist!"
    return "Kanone: Ziel antippen, dann im richtigen Moment noch einmal tippen."


func cancel() -> void:
    _has_target = false
    _finger = -1
    queue_redraw()


func handle_input(event: InputEvent) -> void:
    if not (event is InputEventScreenTouch):
        return
    var touch := event as InputEventScreenTouch
    if touch.pressed:
        if _has_target:
            _shoot()
            _finger = CONSUMED
        elif _finger == -1:
            _finger = touch.index
            _press_pos = touch.position
        return
    if _finger == CONSUMED:
        _finger = -1
        return
    if touch.index != _finger:
        return
    _finger = -1
    if touch.position.distance_to(_press_pos) <= TAP_DISTANCE:
        _set_target(touch.position)


func _set_target(point: Vector2) -> void:
    var group = lab.selected_group
    var origin: Vector2 = group.cannon_muzzle()
    var offset := point - origin
    var reach: float = group.max_range()
    if offset.length() > reach:
        offset = offset.normalized() * reach
    _target = origin + offset
    _has_target = true
    _elapsed = 0.0
    lab.refresh_hint()
    queue_redraw()


func _current_spread() -> float:
    return BattleRules.timing_spread(_elapsed, PERIOD, MIN_SPREAD, MAX_SPREAD)


func _shoot() -> void:
    var spread := _current_spread()
    var angle: float = _rng.randf() * TAU
    var distance: float = sqrt(_rng.randf()) * spread
    var landing := _target + Vector2.RIGHT.rotated(angle) * distance
    if lab.fire_cannon(lab.selected_group, landing):
        _has_target = false
        lab.refresh_hint()
    queue_redraw()


func _process(delta: float) -> void:
    if _has_target:
        _elapsed += delta
        queue_redraw()


func _draw() -> void:
    if not _has_target or lab == null or not lab.cannon_active():
        return
    var group = lab.selected_group
    var origin: Vector2 = group.cannon_muzzle()
    draw_line(origin, _target, Color(1, 1, 1, 0.3), 2.0)
    draw_line(_target + Vector2(-10, 0), _target + Vector2(10, 0), Color.WHITE, 2.0)
    draw_line(_target + Vector2(0, -10), _target + Vector2(0, 10), Color.WHITE, 2.0)
    var spread := _current_spread()
    var sweet_spot: bool = spread < MIN_SPREAD + (MAX_SPREAD - MIN_SPREAD) * 0.2
    var ring := Color(0.5, 1.0, 0.5, 0.95) if sweet_spot else Color(1.0, 0.9, 0.5, 0.9)
    draw_arc(_target, spread, 0.0, TAU, 48, ring, 3.0)
