extends "res://tests/test_case.gd"

const LabRatings := preload("res://core/lab/lab_ratings.gd")


func test_summary_averages_per_combination() -> void:
    var ratings: LabRatings = LabRatings.new()
    ratings.add("A", "schleuder", 2, 3)
    ratings.add("A", "schleuder", 4, 1)
    ratings.add("B", "timing", 1, 2)
    var summary: Array[Dictionary] = ratings.summary()
    check_eq(summary.size(), 2, "Zwei Kombinationen")
    if summary.size() != 2:
        return
    check_eq(str(summary[0]["scheme"]), "B", "Beste Spaß-Note zuerst")
    check_near(float(summary[1]["fun"]), 3.0, 0.0001, "Durchschnitt Spaß")
    check_near(float(summary[1]["accuracy"]), 2.0, 0.0001, "Durchschnitt Treffsicherheit")
    check_eq(int(summary[1]["count"]), 2, "Anzahl Runden")


func test_grades_are_clamped() -> void:
    var ratings: LabRatings = LabRatings.new()
    ratings.add("C", "timing", 0, 9)
    check_eq(int(ratings.entries[0]["fun"]), 1, "Untergrenze")
    check_eq(int(ratings.entries[0]["accuracy"]), 6, "Obergrenze")


func test_roundtrip_via_dict() -> void:
    var ratings: LabRatings = LabRatings.new()
    ratings.add("A", "timing", 2, 2)
    var restored: LabRatings = LabRatings.new()
    var data: Dictionary = JSON.parse_string(JSON.stringify(ratings.to_dict()))
    restored.load_from_dict(data)
    check_eq(restored.entries.size(), 1, "Ein Eintrag")
    if restored.entries.size() == 1:
        check_eq(int(restored.entries[0]["fun"]), 2, "Note bleibt erhalten")
        check_eq(str(restored.entries[0]["cannon"]), "timing", "Kanone bleibt erhalten")
