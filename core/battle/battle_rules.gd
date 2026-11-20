extends RefCounted
## Reine Gefechtsregeln ohne Grafik. Alle Funktionen sind statisch und
## liefern bei gleichem Zufallsgenerator-Seed immer dasselbe Ergebnis.
## Dadurch lassen sie sich automatisch testen.


## Trefferchance eines Schusses abhängig von der Entfernung.
## Bis 30 % der Reichweite gilt die volle Genauigkeit, danach fällt sie
## linear auf ein Viertel am Rand der Reichweite.
static func hit_chance(distance: float, max_range: float, accuracy: float) -> float:
    if max_range <= 0.0 or distance > max_range:
        return 0.0
    var near_limit: float = max_range * 0.3
    if distance <= near_limit:
        return clampf(accuracy, 0.0, 1.0)
    var t: float = (distance - near_limit) / (max_range - near_limit)
    return clampf(lerpf(accuracy, accuracy * 0.25, t), 0.0, 1.0)


## Würfelt für jeden Schützen einzeln und liefert die Zahl der Treffer.
static func roll_hits(shooters: int, chance: float, rng: RandomNumberGenerator) -> int:
    var hits: int = 0
    for _i in range(maxi(shooters, 0)):
        if rng.randf() < chance:
            hits += 1
    return hits


## Landepunkt einer Kanonenkugel: Richtung und Kraft (0 bis 1) ergeben die Weite.
static func cannon_landing(origin: Vector2, direction: Vector2, power: float, max_range: float) -> Vector2:
    if direction.length_squared() < 0.0001:
        return origin
    return origin + direction.normalized() * clampf(power, 0.0, 1.0) * max_range


## Flugzeit einer Kanonenkugel in Sekunden.
static func flight_time(distance: float) -> float:
    return 0.5 + distance / 900.0


## Höhe der Kugel über dem Boden bei Flugfortschritt t (0 bis 1): eine Parabel.
static func arc_height(distance: float, t: float) -> float:
    var peak: float = distance * 0.25
    return 4.0 * peak * t * (1.0 - t)


## Streuradius beim Timing-Schuss: schwingt zwischen max und min hin und her.
static func timing_spread(elapsed: float, period: float, min_radius: float, max_radius: float) -> float:
    if period <= 0.0:
        return max_radius
    var phase: float = fmod(elapsed, period) / period
    var wave: float = (cos(phase * TAU) + 1.0) * 0.5
    return lerpf(min_radius, max_radius, wave)


## Indizes aller Positionen innerhalb des Explosionsradius.
static func splash_indices(positions: Array[Vector2], center: Vector2, radius: float) -> Array[int]:
    var result: Array[int] = []
    for i in positions.size():
        if positions[i].distance_to(center) <= radius:
            result.append(i)
    return result
