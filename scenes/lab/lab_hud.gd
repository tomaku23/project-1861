extends CanvasLayer
## Bedienoberfläche des Labors: Umschalter für Steuerung und Kanone,
## Truppenknöpfe, Hinweiszeile, Statuszeile, Ergebnis mit Noten und eine
## Notenübersicht. Alles entsteht im Code, damit keine Szenendatei nötig ist.
## Knöpfe sind mindestens 52 Punkte hoch – gut mit dem Daumen zu treffen.

signal scheme_selected(id: String)
signal cannon_selected(id: String)
signal slowmo_toggled(enabled: bool)
signal group_selected(kind: String)
signal pause_toggled(paused: bool)
signal restart_requested
signal rating_submitted(fun: int, accuracy: int)
signal rating_skipped
signal ratings_requested
signal ratings_closed

const TOP_BAR_HEIGHT := 72.0
const BOTTOM_RESERVE := 92.0
const GROUP_KINDS := ["infanterie", "kavallerie", "artillerie"]
const GROUP_LABELS := {"infanterie": "Infanterie", "kavallerie": "Kavallerie", "artillerie": "Artillerie"}
const HINT_FLASH_TIME := 1.6

var _root: Control
var _top_bar: PanelContainer
var _group_bar: HBoxContainer
var _hint_label: Label
var _status_label: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_info: Label
var _ratings_panel: PanelContainer
var _ratings_text: Label
var _pause_panel: PanelContainer
var _pause_button: Button
var _slowmo_check: CheckButton
var _save_rating_button: Button
var _scheme_buttons := {}
var _cannon_buttons := {}
var _group_buttons := {}
var _fun_buttons: Array[Button] = []
var _accuracy_buttons: Array[Button] = []
var _fun_grade := 0
var _accuracy_grade := 0
var _hint_text := ""
var _flash_left := 0.0
var _safe := Rect2(0, 0, 1280, 720)


func build(scheme_names: Dictionary, cannon_names: Dictionary) -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.name = "Oberflaeche"
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.theme = _make_theme()
    add_child(_root)
    _build_top_bar(scheme_names, cannon_names)
    _build_hint_and_status()
    _build_group_bar()
    _build_result_panel()
    _build_ratings_panel()
    _build_pause_panel()
    hide_overlays()
    apply_safe_area()
    get_viewport().size_changed.connect(apply_safe_area)


# --- Öffentliche Schnittstelle für das Labor -------------------------------

func set_state(scheme_id: String, cannon_id: String, slowmo: bool) -> void:
    _press_exclusive(_scheme_buttons, scheme_id)
    _press_exclusive(_cannon_buttons, cannon_id)
    _slowmo_check.set_pressed_no_signal(slowmo)


func set_group(kind: String) -> void:
    _press_exclusive(_group_buttons, kind)


func set_group_bar_visible(show_bar: bool) -> void:
    _group_bar.visible = show_bar


func set_hint(text: String) -> void:
    _hint_text = text
    if _flash_left <= 0.0:
        _hint_label.text = text


## Zeigt kurz eine Meldung anstelle des Bedienhinweises.
func flash_hint(text: String) -> void:
    _flash_left = HINT_FLASH_TIME
    _hint_label.text = text


func set_status(text: String) -> void:
    _status_label.text = text


func show_result(title: String, info: String) -> void:
    _result_title.text = title
    _result_info.text = info
    _fun_grade = 0
    _accuracy_grade = 0
    for button in _fun_buttons:
        button.set_pressed_no_signal(false)
    for button in _accuracy_buttons:
        button.set_pressed_no_signal(false)
    _save_rating_button.disabled = true
    _result_panel.visible = true


func show_ratings(text: String) -> void:
    _ratings_text.text = text
    _ratings_panel.visible = true


func is_paused_by_player() -> bool:
    return _pause_panel.visible


func hide_overlays() -> void:
    _result_panel.visible = false
    _ratings_panel.visible = false
    _pause_panel.visible = false
    _pause_button.text = "Pause"


## true, wenn der Punkt auf einem sichtbaren Bedienelement liegt.
## Solche Berührungen gehen nicht an das Schlachtfeld.
func blocks(point: Vector2) -> bool:
    for control in [_top_bar, _group_bar, _result_panel, _ratings_panel, _pause_panel]:
        if control.visible and control.get_global_rect().has_point(point):
            return true
    return false


## Bildschirmbereich ohne Notch, Kamera-Loch und Gestenleiste.
func safe_rect() -> Rect2:
    return _safe


func top_reserve() -> float:
    return TOP_BAR_HEIGHT


func bottom_reserve() -> float:
    return BOTTOM_RESERVE


func apply_safe_area() -> void:
    var view: Rect2 = get_viewport().get_visible_rect()
    _safe = view
    if OS.has_feature("mobile"):
        var window_size := Vector2(DisplayServer.window_get_size())
        var safe_px := Rect2(DisplayServer.get_display_safe_area())
        if window_size.x > 0.0 and window_size.y > 0.0 and safe_px.size.x > 0.0 and safe_px.size.y > 0.0:
            var factor: Vector2 = view.size / window_size
            var left: float = safe_px.position.x * factor.x
            var top: float = safe_px.position.y * factor.y
            var right: float = maxf(window_size.x - safe_px.end.x, 0.0) * factor.x
            var bottom: float = maxf(window_size.y - safe_px.end.y, 0.0) * factor.y
            _safe = Rect2(view.position + Vector2(left, top), view.size - Vector2(left + right, top + bottom))
    _layout()


# --- Aufbau -----------------------------------------------------------------

func _build_top_bar(scheme_names: Dictionary, cannon_names: Dictionary) -> void:
    _top_bar = _panel()
    _root.add_child(_top_bar)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _top_bar.add_child(row)

    row.add_child(_label("Steuerung"))
    var scheme_group := ButtonGroup.new()
    for id in scheme_names:
        var button := _toggle(str(id), scheme_group)
        button.tooltip_text = str(scheme_names[id])
        button.custom_minimum_size = Vector2(60, 52)
        button.toggled.connect(_on_scheme_toggled.bind(str(id)))
        row.add_child(button)
        _scheme_buttons[str(id)] = button

    row.add_child(VSeparator.new())
    row.add_child(_label("Kanone"))
    var cannon_group := ButtonGroup.new()
    for id in cannon_names:
        var button := _toggle(str(cannon_names[id]), cannon_group)
        button.toggled.connect(_on_cannon_toggled.bind(str(id)))
        row.add_child(button)
        _cannon_buttons[str(id)] = button

    row.add_child(VSeparator.new())
    _slowmo_check = CheckButton.new()
    _slowmo_check.text = "Zeitlupe"
    _slowmo_check.focus_mode = Control.FOCUS_NONE
    _slowmo_check.toggled.connect(_on_slowmo_toggled)
    row.add_child(_slowmo_check)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)

    var ratings_button := _button("Noten")
    ratings_button.pressed.connect(_on_ratings_pressed)
    row.add_child(ratings_button)
    var restart_button := _button("Neu")
    restart_button.pressed.connect(_on_restart_pressed)
    row.add_child(restart_button)
    _pause_button = _button("Pause")
    _pause_button.custom_minimum_size = Vector2(110, 52)
    _pause_button.pressed.connect(_on_pause_pressed)
    row.add_child(_pause_button)


func _build_hint_and_status() -> void:
    _hint_label = _outlined_label(18)
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _root.add_child(_hint_label)
    _status_label = _outlined_label(18)
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _root.add_child(_status_label)


func _build_group_bar() -> void:
    _group_bar = HBoxContainer.new()
    _group_bar.add_theme_constant_override("separation", 10)
    _group_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var group := ButtonGroup.new()
    for kind in GROUP_KINDS:
        var button := _toggle(str(GROUP_LABELS[kind]), group)
        button.custom_minimum_size = Vector2(150, 72)
        button.toggled.connect(_on_group_toggled.bind(str(kind)))
        _group_bar.add_child(button)
        _group_buttons[str(kind)] = button
    _root.add_child(_group_bar)


func _build_result_panel() -> void:
    _result_panel = _panel()
    _center(_result_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _result_panel.add_child(box)
    _result_title = _label("")
    _result_title.add_theme_font_size_override("font_size", 34)
    _result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_result_title)
    _result_info = _label("")
    _result_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_result_info)
    var scale_note := _label("Schulnoten: 1 = sehr gut … 6 = ungenügend")
    scale_note.add_theme_font_size_override("font_size", 16)
    scale_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(scale_note)
    box.add_child(_grade_row("Spaß", true))
    box.add_child(_grade_row("Treffsicherheit", false))
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 12)
    actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _save_rating_button = _button("Speichern und neue Runde")
    _save_rating_button.pressed.connect(_on_save_rating_pressed)
    actions.add_child(_save_rating_button)
    var skip := _button("Ohne Note weiter")
    skip.pressed.connect(_on_skip_pressed)
    actions.add_child(skip)
    box.add_child(actions)
    _root.add_child(_result_panel)


func _build_ratings_panel() -> void:
    _ratings_panel = _panel()
    _center(_ratings_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ratings_panel.add_child(box)
    var title := _label("Deine Noten bisher – beste zuerst")
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    _ratings_text = _label("")
    _ratings_text.add_theme_font_size_override("font_size", 18)
    box.add_child(_ratings_text)
    var close := _button("Schließen")
    close.pressed.connect(_on_ratings_close_pressed)
    box.add_child(close)
    _root.add_child(_ratings_panel)


func _build_pause_panel() -> void:
    _pause_panel = _panel()
    _center(_pause_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _pause_panel.add_child(box)
    var title := _label("Pause")
    title.add_theme_font_size_override("font_size", 34)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var resume := _button("Weiter")
    resume.custom_minimum_size = Vector2(220, 60)
    resume.pressed.connect(_on_pause_pressed)
    box.add_child(resume)
    _root.add_child(_pause_panel)


func _grade_row(title: String, is_fun: bool) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var caption := _label(title)
    caption.custom_minimum_size = Vector2(190, 0)
    row.add_child(caption)
    var group := ButtonGroup.new()
    for grade in range(1, 7):
        var button := _toggle(str(grade), group)
        button.custom_minimum_size = Vector2(60, 60)
        button.toggled.connect(_on_grade_toggled.bind(is_fun, grade))
        row.add_child(button)
        if is_fun:
            _fun_buttons.append(button)
        else:
            _accuracy_buttons.append(button)
    return row


func _layout() -> void:
    if _top_bar == null:
        return
    _top_bar.position = _safe.position + Vector2(6, 4)
    _top_bar.size = Vector2(_safe.size.x - 12.0, 0.0)
    _hint_label.position = Vector2(_safe.position.x, _safe.position.y + TOP_BAR_HEIGHT + 4.0)
    _hint_label.size = Vector2(_safe.size.x, 30.0)
    _group_bar.position = Vector2(_safe.position.x + 12.0, _safe.end.y - 84.0)
    _status_label.position = Vector2(_safe.position.x + 500.0, _safe.end.y - 56.0)
    _status_label.size = Vector2(maxf(_safe.size.x - 740.0, 200.0), 40.0)


# --- Bausteine ----------------------------------------------------------------

func _make_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 20
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.16, 0.18, 0.22, 0.92)
    normal.set_corner_radius_all(10)
    normal.set_content_margin_all(10)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.24, 0.27, 0.33, 0.95)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.86, 0.72, 0.30, 0.97)
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color(0.16, 0.18, 0.22, 0.5)
    theme.set_stylebox("normal", "Button", normal)
    theme.set_stylebox("hover", "Button", hover)
    theme.set_stylebox("pressed", "Button", pressed)
    theme.set_stylebox("hover_pressed", "Button", pressed)
    theme.set_stylebox("disabled", "Button", disabled)
    theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    theme.set_color("font_color", "Button", Color(0.95, 0.95, 0.95))
    theme.set_color("font_pressed_color", "Button", Color(0.1, 0.1, 0.1))
    theme.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.1, 0.1))
    theme.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6))
    return theme


func _panel() -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.09, 0.11, 0.84)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel", style)
    return panel


func _center(panel: Control) -> void:
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _outlined_label(font_size: int) -> Label:
    var label := _label("")
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    label.add_theme_constant_override("outline_size", 6)
    return label


func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, 52)
    button.focus_mode = Control.FOCUS_NONE
    return button


func _toggle(text: String, group: ButtonGroup) -> Button:
    var button := _button(text)
    button.toggle_mode = true
    button.button_group = group
    return button


## Drückt genau einen Knopf einer Gruppe, ohne Signale auszulösen.
func _press_exclusive(buttons: Dictionary, key: String) -> void:
    for id in buttons:
        var button: Button = buttons[id]
        button.set_pressed_no_signal(str(id) == key)


# --- Reaktionen auf Knöpfe ----------------------------------------------------

func _process(delta: float) -> void:
    if _flash_left > 0.0:
        _flash_left -= delta
        if _flash_left <= 0.0:
            _hint_label.text = _hint_text


func _on_scheme_toggled(on: bool, id: String) -> void:
    if on:
        scheme_selected.emit(id)


func _on_cannon_toggled(on: bool, id: String) -> void:
    if on:
        cannon_selected.emit(id)


func _on_group_toggled(on: bool, kind: String) -> void:
    if on:
        group_selected.emit(kind)


func _on_slowmo_toggled(on: bool) -> void:
    slowmo_toggled.emit(on)


func _on_grade_toggled(on: bool, is_fun: bool, grade: int) -> void:
    if not on:
        return
    if is_fun:
        _fun_grade = grade
    else:
        _accuracy_grade = grade
    _save_rating_button.disabled = _fun_grade == 0 or _accuracy_grade == 0


func _on_save_rating_pressed() -> void:
    rating_submitted.emit(_fun_grade, _accuracy_grade)


func _on_skip_pressed() -> void:
    rating_skipped.emit()


func _on_ratings_pressed() -> void:
    ratings_requested.emit()


func _on_ratings_close_pressed() -> void:
    _ratings_panel.visible = false
    ratings_closed.emit()


func _on_restart_pressed() -> void:
    restart_requested.emit()


func _on_pause_pressed() -> void:
    var paused := not _pause_panel.visible
    _pause_panel.visible = paused
    _pause_button.text = "Weiter" if paused else "Pause"
    pause_toggled.emit(paused)
