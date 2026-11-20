extends "res://tests/test_case.gd"

const BattleRules := preload("res://core/battle/battle_rules.gd")


func test_hit_chance_full_accuracy_up_close() -> void:
    check_near(BattleRules.hit_chance(10.0, 200.0, 0.4), 0.4, 0.0001, "Nahbereich")


func test_hit_chance_drops_towards_max_range() -> void:
    check_near(BattleRules.hit_chance(200.0, 200.0, 0.4), 0.1, 0.0001, "Maximalreichweite")
    check(BattleRules.hit_chance(120.0, 200.0, 0.4) < 0.4, "Mittlere Distanz sollte schwächer sein")


func test_hit_chance_zero_out_of_range() -> void:
    check_near(BattleRules.hit_chance(201.0, 200.0, 0.4), 0.0, 0.0001, "Außer Reichweite")


func test_roll_hits_is_deterministic_with_seed() -> void:
    var rng_a := RandomNumberGenerator.new()
    rng_a.seed = 42
    var rng_b := RandomNumberGenerator.new()
    rng_b.seed = 42
    var hits_a: int = BattleRules.roll_hits(20, 0.5, rng_a)
    var hits_b: int = BattleRules.roll_hits(20, 0.5, rng_b)
    check_eq(hits_a, hits_b, "Gleicher Seed, gleiches Ergebnis")


func test_roll_hits_bounds() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    check_eq(BattleRules.roll_hits(10, 1.0, rng), 10, "Sichere Treffer")
    check_eq(BattleRules.roll_hits(10, 0.0, rng), 0, "Keine Treffer")
    check_eq(BattleRules.roll_hits(-3, 1.0, rng), 0, "Negative Schützenzahl")


func test_cannon_landing_uses_power_and_range() -> void:
    var half: Vector2 = BattleRules.cannon_landing(Vector2(100, 100), Vector2(1, 0), 0.5, 400.0)
    check(half.is_equal_approx(Vector2(300, 100)), "Halbe Kraft landet bei halber Reichweite")
    var capped: Vector2 = BattleRules.cannon_landing(Vector2.ZERO, Vector2(0, 2), 2.0, 100.0)
    check(capped.is_equal_approx(Vector2(0, 100)), "Kraft über 1 wird begrenzt")
    var none: Vector2 = BattleRules.cannon_landing(Vector2(5, 5), Vector2.ZERO, 1.0, 100.0)
    check(none.is_equal_approx(Vector2(5, 5)), "Ohne Richtung kein Flug")


func test_arc_height_peaks_in_the_middle() -> void:
    check_near(BattleRules.arc_height(400.0, 0.0), 0.0, 0.0001, "Start")
    check_near(BattleRules.arc_height(400.0, 1.0), 0.0, 0.0001, "Landung")
    check_near(BattleRules.arc_height(400.0, 0.5), 100.0, 0.0001, "Scheitelpunkt")


func test_timing_spread_oscillates() -> void:
    check_near(BattleRules.timing_spread(0.0, 1.0, 5.0, 50.0), 50.0, 0.0001, "Start weit")
    check_near(BattleRules.timing_spread(0.5, 1.0, 5.0, 50.0), 5.0, 0.0001, "Mitte eng")
    check_near(BattleRules.timing_spread(1.0, 1.0, 5.0, 50.0), 50.0, 0.0001, "Nach einer Periode wieder weit")


func test_splash_indices() -> void:
    var positions: Array[Vector2] = [Vector2(0, 0), Vector2(10, 0), Vector2(100, 0)]
    var hit: Array[int] = BattleRules.splash_indices(positions, Vector2.ZERO, 20.0)
    check_eq(hit.size(), 2, "Zwei Soldaten im Radius")
    check(hit.has(0) and hit.has(1) and not hit.has(2), "Die richtigen Soldaten getroffen")
