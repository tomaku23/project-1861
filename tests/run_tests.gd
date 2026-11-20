extends SceneTree
## Startet alle automatischen Tests ohne Grafik:
##     godot --headless --path . --script res://tests/run_tests.gd
## Beendet sich mit Code 0, wenn alles grün ist, sonst mit Code 1.

const TEST_FILES := [
    "res://tests/test_scripts_compile.gd",
    "res://tests/test_battle_rules.gd",
    "res://tests/test_save_system.gd",
    "res://tests/test_game_state.gd",
    "res://tests/test_lab_ratings.gd",
]


func _initialize() -> void:
    var passed: int = 0
    var failed: int = 0
    for path in TEST_FILES:
        var script: GDScript = load(path)
        if script == null or not script.can_instantiate():
            print("FEHLER  Testdatei nicht ladbar: %s" % path)
            failed += 1
            continue
        for method in script.get_script_method_list():
            var method_name: String = method["name"]
            if not method_name.begins_with("test_"):
                continue
            var suite: RefCounted = script.new()
            suite.call(method_name)
            var errors: Array = suite.get("failures")
            if errors.is_empty():
                passed += 1
                print("OK      %s :: %s" % [path.get_file(), method_name])
            else:
                failed += 1
                for message in errors:
                    print("FEHLER  %s :: %s – %s" % [path.get_file(), method_name, message])
    print("")
    print("%d Tests bestanden, %d fehlgeschlagen." % [passed, failed])
    quit(1 if failed > 0 else 0)
