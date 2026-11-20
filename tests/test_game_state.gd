extends "res://tests/test_case.gd"

const GameState := preload("res://core/game_state.gd")


func test_end_turn_alternates_and_counts_rounds() -> void:
    var state: GameState = GameState.new()
    check_eq(state.active_faction, "blau", "Start")
    state.end_turn()
    check_eq(state.active_faction, "grau", "Nach dem ersten Zug")
    check_eq(state.round_number, 1, "Noch Runde 1")
    state.end_turn()
    check_eq(state.active_faction, "blau", "Nach dem zweiten Zug")
    check_eq(state.round_number, 2, "Runde 2")


func test_unknown_faction_is_rejected() -> void:
    var state: GameState = GameState.new()
    state.set_owner("atlanta", "gruen")
    check(state.region_owner.is_empty(), "Unbekannte Fraktion wird nicht übernommen")


func test_roundtrip_via_dict() -> void:
    var state: GameState = GameState.new()
    state.set_owner("richmond", "grau")
    state.set_owner("washington", "blau")
    state.gold["blau"] = 120
    state.end_turn()
    var restored: GameState = GameState.new()
    var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
    restored.load_from_dict(data)
    check_eq(restored.active_faction, "grau", "Aktive Fraktion")
    check_eq(int(restored.gold["blau"]), 120, "Gold")
    var grey: Array[String] = restored.regions_of("grau")
    check_eq(grey.size(), 1, "Eine graue Region")
    if grey.size() == 1:
        check_eq(grey[0], "richmond", "Richtige Region")
