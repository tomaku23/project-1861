extends Node2D
## Kanonenkugel im Flug: zieht eine Parabel mit Schatten am Boden und
## explodiert beim Aufschlag. Den Schaden berechnet das Labor (Signal „landed“).

signal landed(ball)

const BattleRules := preload("res://core/battle/battle_rules.gd")
const EXPLOSION_TIME := 0.6

var start := Vector2.ZERO
var end := Vector2.ZERO
var blast_radius := 45.0

var _duration := 1.0
var _distance := 0.0
var _elapsed := 0.0
var _exploded := false
var _explode_time := 0.0


func launch(from_pos: Vector2, to_pos: Vector2, p_blast_radius: float) -> void:
    start = from_pos
    end = to_pos
    blast_radius = p_blast_radius
    _distance = from_pos.distance_to(to_pos)
    _duration = BattleRules.flight_time(_distance)
    position = from_pos


func _process(delta: float) -> void:
    if _exploded:
        _explode_time += delta
        if _explode_time >= EXPLOSION_TIME:
            queue_free()
        queue_redraw()
        return
    _elapsed += delta
    var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
    position = start.lerp(end, t)
    if t >= 1.0:
        _exploded = true
        landed.emit(self)
    queue_redraw()


func _draw() -> void:
    if _exploded:
        var grow: float = minf(_explode_time / 0.2, 1.0)
        var fade: float = clampf(1.0 - _explode_time / EXPLOSION_TIME, 0.0, 1.0)
        draw_circle(Vector2.ZERO, lerpf(8.0, blast_radius, grow), Color(1.0, 0.7, 0.25, 0.55 * fade))
        draw_circle(Vector2.ZERO, lerpf(4.0, blast_radius * 0.6, grow), Color(0.95, 0.95, 0.9, 0.65 * fade))
        return
    var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
    var height: float = BattleRules.arc_height(_distance, t)
    draw_circle(Vector2.ZERO, 4.0, Color(0.0, 0.0, 0.0, 0.3))
    draw_circle(Vector2(0.0, -height), 5.0, Color(0.08, 0.08, 0.08))
