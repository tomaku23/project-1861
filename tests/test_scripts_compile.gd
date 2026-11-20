extends "res://tests/test_case.gd"
## Lädt jedes Skript des Projekts und prüft, ob es fehlerfrei übersetzt.
## Fängt Tippfehler im Code ab, auch in Teilen ohne eigene Tests.

const UnitStats := preload("res://core/unit_stats.gd")


func test_all_scripts_compile() -> void:
    var paths: Array = _collect("res://", [])
    check(paths.size() > 5, "Zu wenige Skripte gefunden (%d)" % paths.size())
    for path in paths:
        var script: Script = load(path)
        check(script != null and script.can_instantiate(), "Skript fehlerhaft: %s" % path)


func test_unit_data_is_complete() -> void:
    var stats: Dictionary = UnitStats.load_all()
    for kind in ["infanterie", "kavallerie", "artillerie"]:
        check(stats.has(kind), "Einheitenwerte fehlen für %s" % kind)
        if stats.has(kind):
            check(int(stats[kind].get("count", 0)) > 0, "Truppenstärke fehlt für %s" % kind)
            check(float(stats[kind].get("speed", 0.0)) > 0.0, "Tempo fehlt für %s" % kind)
    check(float(stats.get("artillerie", {}).get("blast_radius", 0.0)) > 0.0, "Explosionsradius fehlt")


func _collect(dir_path: String, found: Array) -> Array:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return found
    for file_name in dir.get_files():
        if file_name.ends_with(".gd"):
            found.append(dir_path.path_join(file_name))
    for sub in dir.get_directories():
        if sub.begins_with(".") or sub == "addons" or sub == "build":
            continue
        _collect(dir_path.path_join(sub), found)
    return found
