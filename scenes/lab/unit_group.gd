extends Node2D
## Eine Truppe aus mehreren Soldaten – Platzhaltergrafik aus einfachen Formen.
## Bewegt sich entweder zu einem Zielpunkt, in eine feste Richtung
## (Joystick) oder hinter einer gegnerischen Truppe her.

const SIDE_BLUE := 0
const SIDE_GREY := 1

const COLOR_BLUE := Color(0.18, 0.30, 0.72)
const COLOR_GREY := Color(0.50, 0.50, 0.54)
const COLOR_SKIN := Color(0.93, 0.78, 0.62)
const COLOR_HORSE := Color(0.45, 0.30, 0.18)
const COLOR_WOOD := Color(0.40, 0.26, 0.12)
const COLOR_IRON := Color(0.15, 0.15, 0.17)

var side := SIDE_BLUE
var kind := "infanterie"
var stats: Dictionary = {}
var field_rect := Rect2()

var alive: Array[bool] = []
var offsets: Array[Vector2] = []

var has_move_target := false
var move_target := Vector2.ZERO
## Direkte Steuerung (Joystick): Richtung und Stärke, Länge 0 bis 1.
var move_dir := Vector2.ZERO
## Gegnerische Truppe, der diese Truppe folgt (oder null).
var attack_target = null

var reload_left := 0.0
## Gewählte Truppe: Die Markierung muss auch bei aufgeriebenen Truppen
## verschwinden, deshalb zeichnet der Setter neu.
var selected := false:
    set(value):
        selected = value
        queue_redraw()
## true: Die Truppe feuert nur auf Befehl (Steuerung C).
var manual_fire := false
var facing := 1.0

var _walk_phase := 0.0
var _flash_left := 0.0
var _flash_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup(p_kind: String, p_side: int, p_stats: Dictionary, start: Vector2, p_field: Rect2) -> void:
    kind = p_kind
    side = p_side
    stats = p_stats
    field_rect = p_field
    position = start
    facing = 1.0 if side == SIDE_BLUE else -1.0
    reload_left = 1.5
    _rng.randomize()
    var count: int = maxi(int(stats.get("count", 1)), 1)
    var columns: int = 4 if kind == "infanterie" else 3
    var spacing := Vector2(26, 22) if kind == "kavallerie" else Vector2(18, 20)
    var rows: int = ceili(float(count) / float(columns))
    offsets.clear()
    alive.clear()
    for i in count:
        if kind == "artillerie":
            offsets.append(Vector2(-28.0 - (i % 2) * 6.0, -14.0 + i * 15.0))
        else:
            var col: int = i % columns
            var row: int = floori(float(i) / float(columns))
            var x: float = (col - (columns - 1) * 0.5) * spacing.x
            var y: float = (row - (rows - 1) * 0.5) * spacing.y
            offsets.append(Vector2(x, y))
        alive.append(true)


func speed() -> float:
    return float(stats.get("speed", 40.0))


func max_range() -> float:
    return float(stats.get("range", 100.0))


func radius() -> float:
    return 30.0 if kind == "artillerie" else 34.0


func alive_count() -> int:
    var n: int = 0
    for is_alive in alive:
        if is_alive:
            n += 1
    return n


func is_destroyed() -> bool:
    return alive_count() == 0


func soldier_world_position(i: int) -> Vector2:
    var o: Vector2 = offsets[i]
    return position + Vector2(o.x * facing, o.y)


func cannon_muzzle() -> Vector2:
    return position + Vector2(26.0 * facing, -4.0)


## Abstand, auf den sich die Truppe einem verfolgten Gegner nähert.
func engage_distance() -> float:
    if kind == "kavallerie":
        return 18.0
    return max_range() * 0.8


func order_move(point: Vector2) -> void:
    has_move_target = true
    move_target = _clamp_to_field(point)
    move_dir = Vector2.ZERO
    attack_target = null


func order_attack(target) -> void:
    attack_target = target
    has_move_target = false
    move_dir = Vector2.ZERO


func order_halt() -> void:
    has_move_target = false
    move_dir = Vector2.ZERO
    attack_target = null


func is_moving() -> bool:
    return _current_velocity().length_squared() > 0.01


func show_volley(target_position: Vector2) -> void:
    _flash_left = 0.18
    _flash_target = target_position


## Entfernt bis zu n zufällige lebende Soldaten und liefert ihre Positionen.
func take_casualties(n: int) -> Array:
    var fallen: Array = []
    var living: Array[int] = []
    for i in alive.size():
        if alive[i]:
            living.append(i)
    for _k in mini(n, living.size()):
        var pick: int = _rng.randi_range(0, living.size() - 1)
        var index: int = living[pick]
        living.remove_at(pick)
        fallen.append(soldier_world_position(index))
        alive[index] = false
    if not fallen.is_empty():
        queue_redraw()
    return fallen


## Trifft jeden Soldaten im Explosionsradius mit der angegebenen Chance.
func take_blast(center: Vector2, blast_radius: float, chance: float) -> Array:
    var fallen: Array = []
    for i in alive.size():
        if not alive[i]:
            continue
        var p := soldier_world_position(i)
        if p.distance_to(center) <= blast_radius and _rng.randf() < chance:
            alive[i] = false
            fallen.append(p)
    if not fallen.is_empty():
        queue_redraw()
    return fallen


func _process(delta: float) -> void:
    reload_left = maxf(reload_left - delta, 0.0)
    _flash_left = maxf(_flash_left - delta, 0.0)
    if is_destroyed():
        return
    if attack_target != null and (not is_instance_valid(attack_target) or attack_target.is_destroyed()):
        attack_target = null
    if has_move_target and position.distance_to(move_target) <= 3.0:
        has_move_target = false
    var velocity := _current_velocity()
    if velocity.length_squared() > 0.01:
        position = _clamp_to_field(position + velocity * delta)
        if absf(velocity.x) > 1.0:
            facing = signf(velocity.x)
        _walk_phase += delta * 10.0
    elif attack_target != null:
        var dx: float = attack_target.position.x - position.x
        if absf(dx) > 1.0:
            facing = signf(dx)
    queue_redraw()


func _current_velocity() -> Vector2:
    if move_dir.length_squared() > 0.0001:
        return move_dir.limit_length(1.0) * speed()
    if has_move_target:
        var to_target := move_target - position
        if to_target.length() > 3.0:
            return to_target.normalized() * speed()
        return Vector2.ZERO
    if attack_target != null and is_instance_valid(attack_target):
        var gap: Vector2 = attack_target.position - position
        if gap.length() > engage_distance():
            return gap.normalized() * speed()
    return Vector2.ZERO


func _clamp_to_field(point: Vector2) -> Vector2:
    if field_rect.size == Vector2.ZERO:
        return point
    var margin: float = minf(radius(), minf(field_rect.size.x, field_rect.size.y) * 0.5)
    var inner := field_rect.grow(-margin)
    return Vector2(
        clampf(point.x, inner.position.x, inner.end.x),
        clampf(point.y, inner.position.y, inner.end.y)
    )


func _draw() -> void:
    var body := COLOR_BLUE if side == SIDE_BLUE else COLOR_GREY
    if selected:
        draw_arc(Vector2.ZERO, radius() + 8.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.55, 0.95), 3.0)
        if has_move_target:
            var local_target := move_target - position
            draw_line(Vector2.ZERO, local_target, Color(1, 1, 1, 0.45), 2.0)
            draw_circle(local_target, 5.0, Color(1, 1, 1, 0.6))
    if kind == "artillerie":
        _draw_cannon(body)
    var moving := is_moving()
    for i in offsets.size():
        if not alive[i]:
            continue
        var p := Vector2(offsets[i].x * facing, offsets[i].y)
        if kind == "kavallerie":
            _draw_rider(p, body, i, moving)
        else:
            _draw_soldier(p, body, i, moving)
    if _flash_left > 0.0 and kind == "infanterie":
        var dir := (_flash_target - position).normalized()
        for i in offsets.size():
            if not alive[i]:
                continue
            var p := Vector2(offsets[i].x * facing, offsets[i].y)
            draw_line(p + dir * 6.0, p + dir * 14.0, Color(1.0, 0.85, 0.3), 2.0)
            draw_circle(p + dir * 12.0, 4.0, Color(1, 1, 1, 0.35))


func _draw_soldier(p: Vector2, body: Color, i: int, moving: bool) -> void:
    var step: float = sin(_walk_phase + i) * 3.0 if moving else 0.0
    draw_line(p + Vector2(-2, 4), p + Vector2(-2 + step, 11), COLOR_IRON, 2.0)
    draw_line(p + Vector2(2, 4), p + Vector2(2 - step, 11), COLOR_IRON, 2.0)
    draw_rect(Rect2(p + Vector2(-4, -5), Vector2(8, 10)), body)
    draw_circle(p + Vector2(0, -9), 3.5, COLOR_SKIN)
    draw_rect(Rect2(p + Vector2(-4, -14), Vector2(8, 3)), body.darkened(0.35))
    draw_line(p + Vector2(2.0 * facing, -2.0), p + Vector2(11.0 * facing, -10.0), COLOR_WOOD, 2.0)


func _draw_rider(p: Vector2, body: Color, i: int, moving: bool) -> void:
    var gallop: float = sin(_walk_phase * 1.5 + i) * 3.0 if moving else 0.0
    draw_rect(Rect2(p + Vector2(-10, -2), Vector2(20, 8)), COLOR_HORSE)
    draw_rect(Rect2(p + Vector2(8.0 * facing - 3.0, -8.0), Vector2(6, 8)), COLOR_HORSE)
    draw_line(p + Vector2(-7, 6), p + Vector2(-7 + gallop, 13), COLOR_HORSE.darkened(0.3), 2.0)
    draw_line(p + Vector2(7, 6), p + Vector2(7 - gallop, 13), COLOR_HORSE.darkened(0.3), 2.0)
    draw_rect(Rect2(p + Vector2(-3, -11), Vector2(7, 10)), body)
    draw_circle(p + Vector2(0, -14), 3.5, COLOR_SKIN)
    draw_rect(Rect2(p + Vector2(-4, -19), Vector2(8, 3)), body.darkened(0.35))
    draw_line(p + Vector2(3.0 * facing, -8.0), p + Vector2(12.0 * facing, -16.0), Color(0.85, 0.85, 0.9), 2.0)


func _draw_cannon(body: Color) -> void:
    draw_line(Vector2(-6.0 * facing, 2.0), Vector2(26.0 * facing, -4.0), COLOR_IRON, 7.0)
    draw_line(Vector2(-6.0 * facing, 6.0), Vector2(-20.0 * facing, 10.0), COLOR_WOOD, 3.0)
    draw_circle(Vector2(0, 6), 8.0, COLOR_WOOD)
    draw_circle(Vector2(0, 6), 3.0, COLOR_IRON)
    if reload_left > 0.0 and not is_destroyed():
        var total: float = maxf(float(stats.get("reload", 1.0)), 0.01)
        var share: float = clampf(1.0 - reload_left / total, 0.0, 1.0)
        draw_arc(Vector2(0, 26), 6.0, -PI / 2.0, -PI / 2.0 + TAU * share, 24, body.lightened(0.5), 2.0)
