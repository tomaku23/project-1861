extends RefCounted
## Zentraler Spielzustand der Kampagne – Grundgerüst für Phase 2.
## Alles, was gespeichert werden muss, steht hier und sonst nirgends.
## Die Darstellung liest nur daraus und ändert ihn nie direkt.

const FACTIONS := ["blau", "grau"]

var round_number := 1
var active_faction := "blau"
var gold := {"blau": 0, "grau": 0}
## Region -> Fraktion, zum Beispiel {"richmond": "grau"}
var region_owner := {}


## Beendet den Zug der aktiven Fraktion. Nach Grau beginnt eine neue Runde.
func end_turn() -> void:
    var index: int = FACTIONS.find(active_faction)
    var next: int = (index + 1) % FACTIONS.size()
    if next == 0:
        round_number += 1
    active_faction = str(FACTIONS[next])


func set_owner(region_id: String, faction: String) -> void:
    if not (faction in FACTIONS):
        push_error("Unbekannte Fraktion: %s" % faction)
        return
    region_owner[region_id] = faction


func regions_of(faction: String) -> Array[String]:
    var result: Array[String] = []
    for region_id in region_owner:
        if region_owner[region_id] == faction:
            result.append(str(region_id))
    result.sort()
    return result


func to_dict() -> Dictionary:
    return {
        "round_number": round_number,
        "active_faction": active_faction,
        "gold": gold.duplicate(),
        "region_owner": region_owner.duplicate(),
    }


func load_from_dict(data: Dictionary) -> void:
    round_number = int(data.get("round_number", 1))
    active_faction = str(data.get("active_faction", "blau"))
    var gold_data: Variant = data.get("gold", {})
    if gold_data is Dictionary:
        for faction in FACTIONS:
            gold[faction] = int(gold_data.get(faction, 0))
    region_owner = {}
    var owners: Variant = data.get("region_owner", {})
    if owners is Dictionary:
        for region_id in owners:
            region_owner[str(region_id)] = str(owners[region_id])
