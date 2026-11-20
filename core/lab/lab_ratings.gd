extends RefCounted
## Sammelt die Schulnoten aus dem Steuerungs-Labor
## (1 = sehr gut … 6 = ungenügend), getrennt nach Gefechtssteuerung und
## Kanonen-Variante. Daraus entsteht die Entscheidung für eine Steuerung.

var entries: Array[Dictionary] = []


func add(scheme: String, cannon: String, fun: int, accuracy: int) -> void:
    entries.append({
        "scheme": scheme,
        "cannon": cannon,
        "fun": clampi(fun, 1, 6),
        "accuracy": clampi(accuracy, 1, 6),
        "time": int(Time.get_unix_time_from_system()),
    })


## Liefert je Kombination die Durchschnittsnoten und die Zahl der Runden,
## die beste Spaß-Note zuerst.
func summary() -> Array[Dictionary]:
    var buckets := {}
    for entry in entries:
        var key: String = "%s|%s" % [entry["scheme"], entry["cannon"]]
        if not buckets.has(key):
            buckets[key] = {
                "scheme": entry["scheme"],
                "cannon": entry["cannon"],
                "fun_sum": 0,
                "accuracy_sum": 0,
                "count": 0,
            }
        var bucket: Dictionary = buckets[key]
        bucket["fun_sum"] = int(bucket["fun_sum"]) + int(entry["fun"])
        bucket["accuracy_sum"] = int(bucket["accuracy_sum"]) + int(entry["accuracy"])
        bucket["count"] = int(bucket["count"]) + 1
    var result: Array[Dictionary] = []
    for key in buckets:
        var bucket: Dictionary = buckets[key]
        var count: int = int(bucket["count"])
        result.append({
            "scheme": bucket["scheme"],
            "cannon": bucket["cannon"],
            "fun": float(bucket["fun_sum"]) / float(count),
            "accuracy": float(bucket["accuracy_sum"]) / float(count),
            "count": count,
        })
    result.sort_custom(_better_fun)
    return result


func to_dict() -> Dictionary:
    return {"entries": entries.duplicate(true)}


func load_from_dict(data: Dictionary) -> void:
    entries.clear()
    var raw: Variant = data.get("entries", [])
    if not (raw is Array):
        return
    for item in raw:
        if not (item is Dictionary):
            continue
        if not (item.has("scheme") and item.has("cannon")):
            continue
        entries.append({
            "scheme": str(item["scheme"]),
            "cannon": str(item["cannon"]),
            "fun": clampi(int(item.get("fun", 6)), 1, 6),
            "accuracy": clampi(int(item.get("accuracy", 6)), 1, 6),
            "time": int(item.get("time", 0)),
        })


func _better_fun(a: Dictionary, b: Dictionary) -> bool:
    return float(a["fun"]) < float(b["fun"])
