extends "res://scenes/lab/controls/control_scheme.gd"
## Steuerung C: Joystick links bewegt die aktive Truppe direkt,
## Feuerknopf rechts löst Salve, Angriff oder Kanonenschuss aus.
## Bei der Artillerie richtet der Joystick die Kanone aus:
## Richtung = Schussrichtung, Ausschlag = Weite.
## Beide Daumen gleichzeitig funktionieren (Mehrfingerbedienung).

const BattleRules := preload("res://core/battle/battle_rules.gd")
const STICK_RADIUS := 70.0
const KNOB_RADIUS := 30.0
const DEAD_ZONE := 0.15
const FIRE_RADIUS := 66.0
const STICK_ZONE_SHARE := 0.45

var _stick_finger := -1
var _stick_base := Vector2.ZERO
var _stick_vector := Vector2.ZERO
var _aim := Vector2(0.6, 0.0)
var _fire_flash := 0.0


func hint() -> String:
    return "Links: Joystick bewegt die Truppe. Rechts: Feuer. Artillerie: Joystick zielt, Feuer schießt."


func uses_group_buttons() -> bool:
    return true


func deactivate() -> void:
    _release_stick()


func handle_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if touch.position.distance_to(_fire_center()) <= FIRE_RADIUS:
                _fire()
            elif _stick_finger == -1 and touch.position.x < _stick_zone_right():
                _stick_finger = touch.index
                _stick_base = touch.position
                _stick_vector = Vector2.ZERO
        elif touch.index == _stick_finger:
            _release_stick()
        queue_redraw()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _stick_finger:
            _stick_vector = ((drag.position - _stick_base) / STICK_RADIUS).limit_length(1.0)
            queue_redraw()


func _process(delta: float) -> void:
    if lab == null:
        return
    _fire_flash = maxf(_fire_flash - delta, 0.0)
    var group = lab.selected_group
    if group != null and is_instance_valid(group) and not group.is_destroyed():
        var steer := _stick_vector if _stick_vector.length() > DEAD_ZONE else Vector2.ZERO
        if group.kind == "artillerie":
            group.move_dir = Vector2.ZERO
            if steer != Vector2.ZERO:
                _aim = steer
        else:
            group.move_dir = steer
            if steer != Vector2.ZERO:
                group.has_move_target = false
                group.attack_target = null
    queue_redraw()


func _fire() -> void:
    var group = lab.selected_group
    if group == null or not is_instance_valid(group) or group.is_destroyed():
        return
    _fire_flash = 0.15
    if group.kind == "infanterie":
        lab.manual_volley(group)
    elif group.kind == "kavallerie":
        var foe = lab.nearest_enemy(group)
        if foe != null:
            group.order_attack(foe)
    elif group.kind == "artillerie":
        lab.fire_cannon(group, _landing(group))


func _landing(group) -> Vector2:
    return BattleRules.cannon_landing(group.cannon_muzzle(), _aim, _aim.length(), group.max_range())


func _release_stick() -> void:
    _stick_finger = -1
    _stick_vector = Vector2.ZERO


func _fire_center() -> Vector2:
    var rect: Rect2 = lab.hud.safe_rect()
    return Vector2(rect.end.x - 100.0, rect.end.y - 150.0)


func _stick_home() -> Vector2:
    var rect: Rect2 = lab.hud.safe_rect()
    return Vector2(rect.position.x + 150.0, rect.end.y - 200.0)


func _stick_zone_right() -> float:
    var rect: Rect2 = lab.hud.safe_rect()
    return rect.position.x + rect.size.x * STICK_ZONE_SHARE


func _fire_label() -> String:
    var group = lab.selected_group
    if group == null or not is_instance_valid(group):
        return "–"
    if group.kind == "kavallerie":
        return "Angriff"
    if group.kind == "artillerie":
        return "Kanone"
    return "Feuer"


func _draw() -> void:
    if lab == null:
        return
    var active := _stick_finger != -1
    var base := _stick_base if active else _stick_home()
    var alpha: float = 0.55 if active else 0.25
    draw_circle(base, STICK_RADIUS, Color(1, 1, 1, alpha * 0.4))
    draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, alpha), 3.0)
    draw_circle(base + _stick_vector * STICK_RADIUS, KNOB_RADIUS, Color(1, 1, 1, alpha + 0.2))

    var fire := _fire_center()
    var fire_color := Color(1.0, 0.8, 0.3, 0.95) if _fire_flash > 0.0 else Color(0.85, 0.25, 0.2, 0.85)
    draw_circle(fire, FIRE_RADIUS, fire_color)
    draw_arc(fire, FIRE_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 3.0)
    var label := _fire_label()
    var font: Font = ThemeDB.fallback_font
    var font_size: int = 24
    var text_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    draw_string(font, fire + Vector2(-text_width / 2.0, 9.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

    var group = lab.selected_group
    if group != null and is_instance_valid(group) and group.kind == "artillerie" and not group.is_destroyed():
        var muzzle: Vector2 = group.cannon_muzzle()
        var landing := _landing(group)
        draw_line(muzzle, landing, Color(1, 1, 1, 0.35), 2.0)
        var ready_color := Color(1.0, 0.9, 0.5, 0.9) if group.reload_left <= 0.0 else Color(1, 1, 1, 0.4)
        draw_arc(landing, float(group.stats.get("blast_radius", 45.0)), 0.0, TAU, 40, ready_color, 2.0)
