extends Node2D
## Steuerungs-Labor: ein Schlachtfeld mit Platzhalterfiguren, auf dem sich
## drei Gefechtssteuerungen und zwei Kanonen-Varianten ausprobieren und
## benoten lassen. Das Labor ist bewusst Wegwerf-Code: Die Siegervariante
## wandert später ins richtige Gefecht, der Rest fliegt raus.
##
## Ablauf einer Runde: Blau (du) gegen Grau (einfache KI), je eine Truppe
## Infanterie, Kavallerie und Artillerie. Wer alle Truppen verliert, verliert.

const UnitGroup := preload("res://scenes/lab/unit_group.gd")
const Cannonball := preload("res://scenes/lab/cannonball.gd")
const EnemyAI := preload("res://scenes/lab/enemy_ai.gd")
const LabHud := preload("res://scenes/lab/lab_hud.gd")
const SchemeDrag := preload("res://scenes/lab/controls/scheme_drag.gd")
const SchemeOrders := preload("res://scenes/lab/controls/scheme_orders.gd")
const SchemeJoystick := preload("res://scenes/lab/controls/scheme_joystick.gd")
const CannonSling := preload("res://scenes/lab/controls/cannon_sling.gd")
const CannonTiming := preload("res://scenes/lab/controls/cannon_timing.gd")
const BattleRules := preload("res://core/battle/battle_rules.gd")
const UnitStats := preload("res://core/unit_stats.gd")
const LabRatings := preload("res://core/lab/lab_ratings.gd")
const SaveSystemScript := preload("res://systems/save_system.gd")

const SLOT_SETTINGS := "labor_einstellungen"
const SLOT_RATINGS := "labor_noten"
const ROUND_LIMIT := 180.0
const SLOWMO_SCALE := 0.3
const SLOWMO_MS := 700
const BLAST_CHANCE := 0.75
const GROUP_ORDER := ["infanterie", "kavallerie", "artillerie"]

const SCHEME_NAMES := {
    "A": "A · Knöpfe + Wischen",
    "B": "B · Antippen + Ziel",
    "C": "C · Joystick + Feuer",
}
const CANNON_NAMES := {
    "schleuder": "Schleuder",
    "timing": "Timing",
}

var stats: Dictionary = {}
var groups: Array = []
var selected_group = null
var scheme = null
var cannon_ctrl = null
var hud: LabHud = null
var scheme_id := "A"
var cannon_id := "schleuder"
var slowmo_enabled := true
var field_rect := Rect2()
var ratings: LabRatings = LabRatings.new()
var rng := RandomNumberGenerator.new()
## Speichersystem (Autoload „SaveSystem“, notfalls eine eigene Instanz).
var save_system = null

var _ai: EnemyAI = EnemyAI.new()
var _effects: Node2D = null
var _fallen: Array[Vector2] = []
var _scenery: Array[Dictionary] = []
var _ui_fingers := {}
var _round_time := 0.0
var _round_over := false
var _slowmo_until := 0


func _ready() -> void:
    rng.randomize()
    save_system = get_node_or_null("/root/SaveSystem")
    if save_system == null:
        save_system = SaveSystemScript.new()
        add_child(save_system)
    stats = UnitStats.load_all()
    _load_saved()

    _effects = Node2D.new()
    _effects.name = "Effekte"
    _effects.z_index = 5
    add_child(_effects)

    hud = LabHud.new()
    hud.name = "Oberflaeche"
    add_child(hud)
    hud.build(SCHEME_NAMES, CANNON_NAMES)
    hud.set_state(scheme_id, cannon_id, slowmo_enabled)
    hud.scheme_selected.connect(_on_scheme_selected)
    hud.cannon_selected.connect(_on_cannon_selected)
    hud.slowmo_toggled.connect(_on_slowmo_toggled)
    hud.group_selected.connect(_on_group_button)
    hud.pause_toggled.connect(_on_pause_toggled)
    hud.restart_requested.connect(start_round)
    hud.rating_submitted.connect(_on_rating_submitted)
    hud.rating_skipped.connect(start_round)
    hud.ratings_requested.connect(_show_ratings)
    hud.ratings_closed.connect(_on_ratings_closed)

    save_system.autosave_requested.connect(_save_all)
    get_viewport().size_changed.connect(_on_viewport_resized)
    start_round()


# --- Runden ---------------------------------------------------------------------

func start_round() -> void:
    get_tree().paused = false
    Engine.time_scale = 1.0
    _slowmo_until = 0
    hud.hide_overlays()
    selected_group = null
    for group in groups:
        group.queue_free()
    groups.clear()
    for child in _effects.get_children():
        child.queue_free()
    _fallen.clear()
    _ui_fingers.clear()
    _round_time = 0.0
    _round_over = false
    _update_field_rect()
    _make_scenery()

    var left: float = field_rect.position.x + field_rect.size.x * 0.12
    var right: float = field_rect.end.x - field_rect.size.x * 0.12
    var mid: float = field_rect.get_center().y
    var spread: float = field_rect.size.y * 0.28
    _spawn("kavallerie", UnitGroup.SIDE_BLUE, Vector2(left + 40.0, mid - spread))
    _spawn("infanterie", UnitGroup.SIDE_BLUE, Vector2(left + 60.0, mid))
    _spawn("artillerie", UnitGroup.SIDE_BLUE, Vector2(left, mid + spread))
    _spawn("kavallerie", UnitGroup.SIDE_GREY, Vector2(right - 40.0, mid + spread))
    _spawn("infanterie", UnitGroup.SIDE_GREY, Vector2(right - 60.0, mid))
    _spawn("artillerie", UnitGroup.SIDE_GREY, Vector2(right, mid - spread))

    _ai.reset()
    _activate_controls()
    select_group(_first_player_group("infanterie"))
    queue_redraw()


func _spawn(kind: String, side: int, at: Vector2) -> void:
    var group: UnitGroup = UnitGroup.new()
    var kind_stats: Dictionary = stats.get(kind, {})
    group.setup(kind, side, kind_stats, at, field_rect)
    group.name = "%s_%s" % [kind, "blau" if side == UnitGroup.SIDE_BLUE else "grau"]
    add_child(group)
    groups.append(group)


func _activate_controls() -> void:
    if scheme != null:
        scheme.deactivate()
        scheme.queue_free()
    if scheme_id == "B":
        scheme = SchemeOrders.new()
    elif scheme_id == "C":
        scheme = SchemeJoystick.new()
    else:
        scheme = SchemeDrag.new()
    scheme.z_index = 10
    add_child(scheme)
    scheme.activate(self)

    if cannon_ctrl != null:
        cannon_ctrl.queue_free()
    if cannon_id == "timing":
        cannon_ctrl = CannonTiming.new()
    else:
        cannon_ctrl = CannonSling.new()
    cannon_ctrl.z_index = 9
    cannon_ctrl.lab = self
    add_child(cannon_ctrl)

    hud.set_group_bar_visible(scheme.uses_group_buttons())
    _update_manual_fire()
    refresh_hint()


func _check_round_end() -> void:
    var blue_alive: int = living_groups(UnitGroup.SIDE_BLUE).size()
    var grey_alive: int = living_groups(UnitGroup.SIDE_GREY).size()
    if blue_alive > 0 and grey_alive > 0 and _round_time < ROUND_LIMIT:
        return
    _round_over = true
    Engine.time_scale = 1.0
    _slowmo_until = 0
    var title := "Unentschieden"
    if grey_alive == 0 and blue_alive > 0:
        title = "Sieg!"
    elif blue_alive == 0 and grey_alive > 0:
        title = "Niederlage"
    var info := "Steuerung %s · Kanone: %s · %d Sekunden" % [
        SCHEME_NAMES[scheme_id], CANNON_NAMES[cannon_id], int(_round_time)
    ]
    hud.show_result(title, info)


# --- Abfragen für Steuerungen und KI ---------------------------------------------

func living_groups(side: int) -> Array:
    var result: Array = []
    for group in groups:
        if group.side == side and not group.is_destroyed():
            result.append(group)
    return result


## Truppe einer Seite unter einem Fingerdruck (mit großzügiger Trefferfläche).
func group_at(point: Vector2, side: int):
    var best = null
    var best_distance := INF
    for group in living_groups(side):
        var distance: float = group.position.distance_to(point)
        if distance <= group.radius() + 22.0 and distance < best_distance:
            best = group
            best_distance = distance
    return best


func nearest_enemy(group, max_distance: float = INF):
    var other: int = UnitGroup.SIDE_GREY if group.side == UnitGroup.SIDE_BLUE else UnitGroup.SIDE_BLUE
    var best = null
    var best_distance := max_distance
    for candidate in living_groups(other):
        var distance: float = candidate.position.distance_to(group.position)
        if distance <= best_distance:
            best = candidate
            best_distance = distance
    return best


## true, wenn die gewählte Truppe die Artillerie ist und die Kanonen-Variante gilt.
func cannon_active() -> bool:
    if selected_group == null or not is_instance_valid(selected_group):
        return false
    if selected_group.is_destroyed() or selected_group.kind != "artillerie":
        return false
    return scheme_id != "C"


func select_group(group) -> void:
    if selected_group != null and is_instance_valid(selected_group):
        selected_group.selected = false
        if scheme_id == "C":
            selected_group.move_dir = Vector2.ZERO
    selected_group = group
    if group != null:
        group.selected = true
        hud.set_group(group.kind)
        if slowmo_enabled and _round_time > 0.1 and not _round_over:
            _slowmo_until = Time.get_ticks_msec() + SLOWMO_MS
        _vibrate(15)
    if cannon_ctrl != null:
        cannon_ctrl.cancel()
    _update_manual_fire()
    refresh_hint()


func refresh_hint() -> void:
    if scheme == null:
        return
    var text: String = scheme.hint()
    if cannon_active() and cannon_ctrl != null:
        text = cannon_ctrl.hint()
    hud.set_hint(text)


# --- Kampf ----------------------------------------------------------------------

func fire_volley(group, target) -> void:
    var distance: float = group.position.distance_to(target.position)
    var accuracy: float = float(group.stats.get("accuracy", 0.3))
    var chance: float = BattleRules.hit_chance(distance, group.max_range(), accuracy)
    var hits: int = BattleRules.roll_hits(group.alive_count(), chance, rng)
    _add_fallen(target.take_casualties(hits))
    group.reload_left = float(group.stats.get("reload", 2.0))
    group.show_volley(target.position)


## Salve auf Knopfdruck (Steuerung C).
func manual_volley(group) -> bool:
    if group.reload_left > 0.0:
        hud.flash_hint("Lädt noch …")
        return false
    var target = nearest_enemy(group, group.max_range())
    if target == null:
        hud.flash_hint("Kein Gegner in Reichweite")
        return false
    fire_volley(group, target)
    _vibrate(25)
    return true


func fire_cannon(group, landing: Vector2) -> bool:
    if group == null or not is_instance_valid(group) or group.is_destroyed():
        return false
    if group.reload_left > 0.0:
        if group.side == UnitGroup.SIDE_BLUE:
            hud.flash_hint("Kanone lädt noch …")
        return false
    var muzzle: Vector2 = group.cannon_muzzle()
    var impact := _clamp_point(landing)
    var ball: Cannonball = Cannonball.new()
    ball.launch(muzzle, impact, float(group.stats.get("blast_radius", 45.0)))
    ball.landed.connect(_on_ball_landed)
    _effects.add_child(ball)
    group.reload_left = float(group.stats.get("reload", 3.0))
    if absf(impact.x - muzzle.x) > 1.0:
        group.facing = signf(impact.x - muzzle.x)
    if group.side == UnitGroup.SIDE_BLUE:
        _vibrate(35)
    return true


func _resolve_combat() -> void:
    for group in groups:
        if group.is_destroyed() or group.reload_left > 0.0:
            continue
        if group.kind == "infanterie" and not group.manual_fire:
            var target = _volley_target(group)
            if target != null:
                fire_volley(group, target)
        elif group.kind == "kavallerie":
            var foe = nearest_enemy(group, group.radius() * 2.0 + 10.0)
            if foe != null:
                _melee(group, foe)


func _volley_target(group):
    var target = group.attack_target
    if target != null and is_instance_valid(target) and not target.is_destroyed():
        if target.position.distance_to(group.position) <= group.max_range():
            return target
    return nearest_enemy(group, group.max_range())


func _melee(group, foe) -> void:
    var hits: int = BattleRules.roll_hits(group.alive_count(), float(group.stats.get("melee", 0.3)), rng)
    var back: int = BattleRules.roll_hits(foe.alive_count(), float(foe.stats.get("melee", 0.1)) * 0.5, rng)
    _add_fallen(foe.take_casualties(hits))
    _add_fallen(group.take_casualties(back))
    group.reload_left = float(group.stats.get("reload", 1.0))


func _on_ball_landed(ball) -> void:
    for group in groups:
        if not group.is_destroyed():
            _add_fallen(group.take_blast(ball.position, ball.blast_radius, BLAST_CHANCE))


func _add_fallen(points: Array) -> void:
    for p in points:
        _fallen.append(p)
    if not points.is_empty():
        queue_redraw()


# --- Ablauf pro Bild --------------------------------------------------------------

func _process(delta: float) -> void:
    Engine.time_scale = SLOWMO_SCALE if Time.get_ticks_msec() < _slowmo_until else 1.0
    if _round_over:
        return
    _round_time += delta
    _ensure_selection()
    _ai.update(self, delta)
    _resolve_combat()
    hud.set_status(_status_text())
    _check_round_end()


func _ensure_selection() -> void:
    if selected_group != null and is_instance_valid(selected_group) and not selected_group.is_destroyed():
        return
    var next = _any_player_group()
    if next != selected_group:
        select_group(next)


func _status_text() -> String:
    var blue: int = 0
    var grey: int = 0
    for group in groups:
        if group.side == UnitGroup.SIDE_BLUE:
            blue += group.alive_count()
        else:
            grey += group.alive_count()
    var cannon = _first_player_group("artillerie")
    var cannon_state := "Kanone verloren"
    if cannon != null:
        cannon_state = "Kanone bereit" if cannon.reload_left <= 0.0 else "Kanone lädt …"
    return "Blau %d · Grau %d · %s" % [blue, grey, cannon_state]


# --- Eingabe ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
    if _round_over or scheme == null:
        return
    var index: int = -1
    var point := Vector2.ZERO
    var is_touch := false
    var pressed := false
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        index = touch.index
        point = touch.position
        is_touch = true
        pressed = touch.pressed
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        index = drag.index
        point = drag.position
    else:
        return
    # Finger, die auf einem Knopf begonnen haben, gehören der Oberfläche.
    if is_touch and pressed and hud.blocks(point):
        _ui_fingers[index] = true
        return
    if _ui_fingers.has(index):
        if is_touch and not pressed:
            _ui_fingers.erase(index)
        return
    scheme.handle_input(event)


# --- Oberfläche ---------------------------------------------------------------------

func _on_scheme_selected(id: String) -> void:
    if id == scheme_id or not SCHEME_NAMES.has(id):
        return
    scheme_id = id
    _save_all()
    start_round()


func _on_cannon_selected(id: String) -> void:
    if id == cannon_id or not CANNON_NAMES.has(id):
        return
    cannon_id = id
    _save_all()
    start_round()


func _on_slowmo_toggled(enabled: bool) -> void:
    slowmo_enabled = enabled
    _save_all()


func _on_group_button(kind: String) -> void:
    var group = _first_player_group(kind)
    if group == null:
        hud.flash_hint("Diese Truppe ist aufgerieben.")
        if selected_group != null and is_instance_valid(selected_group):
            hud.set_group(selected_group.kind)
        return
    select_group(group)


func _on_pause_toggled(paused: bool) -> void:
    get_tree().paused = paused
    Engine.time_scale = 1.0
    _slowmo_until = 0


func _on_rating_submitted(fun: int, accuracy: int) -> void:
    ratings.add(scheme_id, cannon_id, fun, accuracy)
    _save_all()
    start_round()


func _show_ratings() -> void:
    get_tree().paused = true
    Engine.time_scale = 1.0
    _slowmo_until = 0
    var lines := PackedStringArray()
    for row in ratings.summary():
        var rounds: int = int(row["count"])
        lines.append("%s · Kanone %s:   Spaß %s · Treffsicherheit %s   (%d %s)" % [
            SCHEME_NAMES.get(row["scheme"], row["scheme"]),
            CANNON_NAMES.get(row["cannon"], row["cannon"]),
            _grade_text(row["fun"]),
            _grade_text(row["accuracy"]),
            rounds,
            "Runde" if rounds == 1 else "Runden",
        ])
    if lines.is_empty():
        lines.append("Noch keine Noten. Nach jeder Runde kannst du Spaß und Treffsicherheit benoten.")
    hud.show_ratings("\n".join(lines))


func _on_ratings_closed() -> void:
    if not hud.is_paused_by_player():
        get_tree().paused = false


func _grade_text(value) -> String:
    return String.num(float(value), 1).replace(".", ",")


func _on_viewport_resized() -> void:
    _update_field_rect()
    queue_redraw()


# --- Speichern ----------------------------------------------------------------------

func _load_saved() -> void:
    var settings: Dictionary = save_system.load_data(SLOT_SETTINGS)
    var saved_scheme := str(settings.get("scheme", scheme_id))
    if SCHEME_NAMES.has(saved_scheme):
        scheme_id = saved_scheme
    var saved_cannon := str(settings.get("cannon", cannon_id))
    if CANNON_NAMES.has(saved_cannon):
        cannon_id = saved_cannon
    slowmo_enabled = bool(settings.get("slowmo", slowmo_enabled))
    ratings.load_from_dict(save_system.load_data(SLOT_RATINGS))


func _save_all() -> void:
    save_system.save_data(SLOT_SETTINGS, {
        "scheme": scheme_id,
        "cannon": cannon_id,
        "slowmo": slowmo_enabled,
    })
    save_system.save_data(SLOT_RATINGS, ratings.to_dict())


# --- Hilfsfunktionen ------------------------------------------------------------------

func _first_player_group(kind: String):
    for group in groups:
        if group.side == UnitGroup.SIDE_BLUE and group.kind == kind and not group.is_destroyed():
            return group
    return null


func _any_player_group():
    for kind in GROUP_ORDER:
        var group = _first_player_group(kind)
        if group != null:
            return group
    return null


func _update_manual_fire() -> void:
    for group in groups:
        group.manual_fire = scheme_id == "C" and group == selected_group and group.kind == "infanterie"


func _update_field_rect() -> void:
    var safe: Rect2 = hud.safe_rect()
    var top: float = safe.position.y + hud.top_reserve() + 8.0
    var bottom: float = safe.end.y - hud.bottom_reserve()
    field_rect = Rect2(
        Vector2(safe.position.x + 8.0, top),
        Vector2(maxf(safe.size.x - 16.0, 100.0), maxf(bottom - top, 100.0))
    )
    for group in groups:
        group.field_rect = field_rect


func _clamp_point(point: Vector2) -> Vector2:
    return Vector2(
        clampf(point.x, field_rect.position.x, field_rect.end.x),
        clampf(point.y, field_rect.position.y, field_rect.end.y)
    )


func _make_scenery() -> void:
    _scenery.clear()
    for _i in 12:
        var x: float = rng.randf_range(field_rect.position.x, field_rect.end.x)
        var y: float
        if rng.randf() < 0.5:
            y = field_rect.position.y + rng.randf_range(0.0, 40.0)
        else:
            y = field_rect.end.y - rng.randf_range(0.0, 30.0)
        _scenery.append({"type": "baum", "pos": Vector2(x, y)})
    for _i in 10:
        var stone := Vector2(
            rng.randf_range(field_rect.position.x, field_rect.end.x),
            rng.randf_range(field_rect.position.y, field_rect.end.y)
        )
        _scenery.append({"type": "stein", "pos": stone})


func _vibrate(milliseconds: int) -> void:
    if OS.has_feature("mobile") or OS.has_feature("web"):
        Input.vibrate_handheld(milliseconds)


func _draw() -> void:
    draw_rect(get_viewport_rect(), Color(0.38, 0.52, 0.30))
    draw_rect(field_rect, Color(0.42, 0.57, 0.33))
    for item in _scenery:
        var p: Vector2 = item["pos"]
        if item["type"] == "baum":
            draw_circle(p + Vector2(0, 10), 6.0, Color(0.30, 0.20, 0.10))
            draw_circle(p, 16.0, Color(0.22, 0.40, 0.20))
        else:
            draw_circle(p, 7.0, Color(0.55, 0.52, 0.45))
    var mark := Color(0.25, 0.20, 0.15, 0.8)
    for p in _fallen:
        draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), mark, 2.0)
        draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), mark, 2.0)
