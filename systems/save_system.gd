extends Node
## Speichert und lädt Spielstände als JSON-Dateien im Benutzerordner.
## Jede Datei trägt eine Versionsnummer. Spätere Updates wandeln alte
## Spielstände in migrate() um, statt sie zu verlieren.
##
## Läuft als Autoload „SaveSystem“. Sobald die App in den Hintergrund geht
## oder geschlossen wird, meldet es „autosave_requested“ – wer etwas
## sichern will, hängt sich an dieses Signal.

signal autosave_requested

const SAVE_VERSION := 1

var base_dir := "user://saves"


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
            autosave_requested.emit()


## Schreibt erst in eine Zwischendatei und benennt sie dann um. So bleibt
## der alte Spielstand erhalten, falls das Schreiben abbricht.
func save_data(slot: String, data: Dictionary) -> Error:
    var dir_error := DirAccess.make_dir_recursive_absolute(base_dir)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        push_warning("Speicherordner nicht anlegbar: %s" % base_dir)
        return dir_error
    var envelope := {
        "version": SAVE_VERSION,
        "saved_at": int(Time.get_unix_time_from_system()),
        "data": data,
    }
    var final_path := _path_for(slot)
    var temp_path := final_path + ".tmp"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(envelope, "\t"))
    file.close()
    if FileAccess.file_exists(final_path):
        DirAccess.remove_absolute(final_path)
    return DirAccess.rename_absolute(temp_path, final_path)


## Liefert die gespeicherten Daten oder ein leeres Dictionary, wenn es den
## Spielstand nicht gibt oder er beschädigt ist.
func load_data(slot: String) -> Dictionary:
    var path := _path_for(slot)
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        push_warning("Spielstand „%s“ ist beschädigt und wird ignoriert." % slot)
        return {}
    var envelope: Dictionary = parsed
    var version: int = int(envelope.get("version", 0))
    var data: Variant = envelope.get("data", {})
    if not (data is Dictionary):
        return {}
    return migrate(version, data)


func has_save(slot: String) -> bool:
    return FileAccess.file_exists(_path_for(slot))


func delete_save(slot: String) -> void:
    var path := _path_for(slot)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)


## Wandelt ältere Spielstände Schritt für Schritt auf die aktuelle Version um.
## Neue Umwandlungen kommen als weitere „if version < X“-Blöcke dazu.
func migrate(version: int, data: Dictionary) -> Dictionary:
    var result: Dictionary = data.duplicate(true)
    if version > SAVE_VERSION:
        push_warning("Spielstand stammt aus einer neueren Version (%d)." % version)
    # Version 0 -> 1: Dateien ohne Versionsangabe bleiben inhaltlich gleich.
    return result


func _path_for(slot: String) -> String:
    return base_dir.path_join(slot.validate_filename() + ".json")
