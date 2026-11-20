extends "res://tests/test_case.gd"

const SaveSystemScript := preload("res://systems/save_system.gd")
const TEST_DIR := "user://test_saves"


func _make_system() -> SaveSystemScript:
    var system: SaveSystemScript = SaveSystemScript.new()
    system.base_dir = TEST_DIR
    return system


func test_roundtrip_keeps_data() -> void:
    var system := _make_system()
    var data := {"name": "Labor", "werte": [1, 2, 3], "verschachtelt": {"a": true}}
    check_eq(system.save_data("roundtrip", data), OK, "Speichern")
    var loaded: Dictionary = system.load_data("roundtrip")
    check_eq(str(loaded.get("name", "")), "Labor", "Text")
    var nested: Dictionary = loaded.get("verschachtelt", {})
    check_eq(nested.get("a", false), true, "Verschachtelter Wert")
    var values: Array = loaded.get("werte", [])
    check_eq(values.size(), 3, "Liste vollständig")
    if values.size() == 3:
        check_eq(int(values[2]), 3, "Zahl in der Liste")
    system.delete_save("roundtrip")
    system.free()


func test_overwrite_replaces_old_data() -> void:
    var system := _make_system()
    system.save_data("ueberschreiben", {"stand": 1})
    system.save_data("ueberschreiben", {"stand": 2})
    check_eq(int(system.load_data("ueberschreiben").get("stand", 0)), 2, "Neuer Stand")
    check(not FileAccess.file_exists(TEST_DIR.path_join("ueberschreiben.json.tmp")), "Keine Zwischendatei übrig")
    system.delete_save("ueberschreiben")
    system.free()


func test_missing_slot_returns_empty() -> void:
    var system := _make_system()
    check(system.load_data("gibt_es_nicht").is_empty(), "Leeres Ergebnis erwartet")
    check(not system.has_save("gibt_es_nicht"), "Kein Spielstand vorhanden")
    system.free()


func test_corrupt_file_is_ignored() -> void:
    var system := _make_system()
    DirAccess.make_dir_recursive_absolute(TEST_DIR)
    var file := FileAccess.open(TEST_DIR.path_join("kaputt.json"), FileAccess.WRITE)
    file.store_string("{ das ist kein json")
    file.close()
    check(system.load_data("kaputt").is_empty(), "Kaputte Datei liefert leeres Ergebnis")
    system.delete_save("kaputt")
    system.free()


func test_file_carries_version() -> void:
    var system := _make_system()
    system.save_data("version", {"x": 1})
    var file := FileAccess.open(TEST_DIR.path_join("version.json"), FileAccess.READ)
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    var version: int = -1
    if parsed is Dictionary:
        version = int(parsed.get("version", -1))
    check_eq(version, SaveSystemScript.SAVE_VERSION, "Versionsnummer in der Datei")
    system.delete_save("version")
    system.free()
