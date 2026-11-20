extends RefCounted
## Lädt die Einheitenwerte aus data/units.json.
## Balancing heißt: Zahlen in der JSON-Datei ändern, keinen Code.

const DATA_PATH := "res://data/units.json"
const KINDS := ["infanterie", "kavallerie", "artillerie"]


static func load_all(path: String = DATA_PATH) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Einheitenwerte fehlen: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("Einheitenwerte sind kein gültiges JSON: %s" % path)
    return {}
