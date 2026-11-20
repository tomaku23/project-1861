extends RefCounted
## Kleine Testbasis ohne Zusatz-Plugin: sammelt Fehlermeldungen,
## statt beim ersten Fehler abzubrechen. Testmethoden beginnen mit „test_“.

var failures: Array = []


func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
    if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
        failures.append("%s: erwartet %s, erhalten %s" % [message, str(expected), str(actual)])
        return
    if actual != expected:
        failures.append("%s: erwartet %s, erhalten %s" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
    if absf(actual - expected) > tolerance:
        failures.append("%s: erwartet %.3f ± %.3f, erhalten %.3f" % [message, expected, tolerance, actual])


func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
