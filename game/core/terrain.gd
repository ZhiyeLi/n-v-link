class_name NinjaTerrain
extends RefCounted
## Original 24 px tile coordinates; rendering and collision use the same geometry.
const SIZE := 24.0
const WIDTH := 792.0
const HEIGHT := 600.0
const COLS := 33
const ROWS := 25
const ARC_STEPS := 32
var tiles := PackedInt32Array()
var polygons: Array[PackedVector2Array] = []
var shapes: Array[PackedVector2Array] = []
var segments: Array = []
var segment_grid: Dictionary = {}

func _init() -> void:
	for id in range(34):
		shapes.append(make_shape(id))

func load_tiles(encoded: String) -> void:
	assert(encoded.length() == 713)
	tiles.resize(COLS * ROWS)
	polygons.clear()
	segments.clear()
	segment_grid.clear()
	for y in range(ROWS):
		for x in range(COLS):
			var id := 1 if x == 0 or x == 32 or y == 0 or y == 24 else encoded.unicode_at((x - 1) * 23 + y - 1) - 48
			tiles[y * COLS + x] = id
			if id == 0:
				continue
			var poly := PackedVector2Array()
			var center := Vector2(x * SIZE + 12, y * SIZE + 12)
			for point in shapes[id]:
				poly.append(point + center)
			polygons.append(poly)
	# Split axis-aligned boundaries at half-tile joins before discarding hidden edges.
	for poly in polygons:
		for i in range(poly.size()):
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var delta := b - a
			var normal := Vector2(delta.y, -delta.x).normalized()
			var count := 2 if absf(delta.x) < 0.001 or absf(delta.y) < 0.001 else 1
			for j in range(count):
				var p := a.lerp(b, float(j) / count)
				var q := a.lerp(b, float(j + 1) / count)
				if solid((p + q) * 0.5 + normal * 0.02):
					continue
				var index := segments.size()
				segments.append({"a": p, "b": q, "n": normal})
				var low := Vector2i((p.min(q) - Vector2.ONE * 11) / SIZE)
				var high := Vector2i((p.max(q) + Vector2.ONE * 11) / SIZE)
				for gy in range(low.y, high.y + 1):
					for gx in range(low.x, high.x + 1):
						var key := Vector2i(gx, gy)
						if not segment_grid.has(key):
							segment_grid[key] = []
						segment_grid[key].append(index)

func tile_id(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return 1
	return tiles[y * COLS + x]

func solid(point: Vector2) -> bool:
	if point.x < 24 or point.x > 768 or point.y < 24 or point.y > 576:
		return true
	var cell := Vector2i(floori(point.x / SIZE), floori(point.y / SIZE))
	var id := tile_id(cell.x, cell.y)
	if id == 0:
		return false
	if id == 1:
		return true
	return Geometry2D.is_point_in_polygon(point - Vector2(cell) * SIZE - Vector2(12, 12), shapes[id])

func contact(point: Vector2, radius: float) -> Dictionary:
	var key := Vector2i(floori(point.x / SIZE), floori(point.y / SIZE))
	var inside := solid(point)
	var nearest := INF
	var best: Dictionary = {}
	for index in segment_grid.get(key, []):
		var edge: Dictionary = segments[index]
		var q := Geometry2D.get_closest_point_to_segment(point, edge.a, edge.b)
		var offset := point - q
		var distance := offset.length()
		if distance >= nearest:
			continue
		if not inside and (distance >= radius or offset.dot(edge.n) < -0.01):
			continue
		var normal: Vector2 = edge.n if inside or distance < 0.00001 else offset / distance
		nearest = distance
		best = {"normal": normal, "depth": radius + distance if inside else radius - distance}
	return best

func ray_distance(origin: Vector2, direction: Vector2, maximum: float = 1200.0) -> float:
	var end := origin + direction * maximum
	var best := maximum
	for edge in segments:
		var hit = Geometry2D.segment_intersects_segment(origin, end, edge.a, edge.b)
		if hit is Vector2:
			var distance := origin.distance_to(hit)
			if distance > 0.01:
				best = minf(best, distance)
	return best

func can_see(a: Vector2, b: Vector2) -> bool:
	var delta := b - a
	return delta.length() < 0.01 or ray_distance(a, delta.normalized(), delta.length()) >= delta.length() - 0.1

static func make_shape(id: int) -> PackedVector2Array:
	var square := PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)])
	if id == 0:
		return PackedVector2Array()
	if id == 1:
		return square
	if id >= 30:
		var normals := [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
		return clip_polygon(square, normals[id - 30], 0.0)
	var signs := [Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var signv: Vector2 = signs[(id - 2) % 4]
	if id < 6:
		return clip_polygon(square, signv.normalized(), 0.0)
	if id < 14:
		var convex := id >= 10
		var center := -signv * 12 if convex else signv * 12
		var arc := PackedVector2Array()
		var start := atan2(signv.y if convex else -signv.y, 0.0)
		var finish := atan2(0.0, signv.x if convex else -signv.x)
		var difference := wrapf(finish - start, -PI, PI)
		arc.append(center if convex else -center)
		for i in range(ARC_STEPS + 1):
			arc.append(center + Vector2.from_angle(start + difference * i / ARC_STEPS) * 24.0)
		if signed_area(arc) < 0:
			arc.reverse()
		return arc
	var normal := Vector2(signv.x, signv.y * 2).normalized() if id < 22 else Vector2(signv.x * 2, signv.y).normalized()
	var small := id < 18 or (id >= 22 and id < 26)
	return clip_polygon(square, normal, (-1 if small else 1) * 12.0 / sqrt(5.0))

static func signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(poly.size()):
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	return area * 0.5

static func clip_polygon(poly: PackedVector2Array, normal: Vector2, offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := a.dot(normal) - offset
		var db := b.dot(normal) - offset
		if da <= 0:
			result.append(a)
		if (da < 0 and db > 0) or (da > 0 and db < 0):
			result.append(a.lerp(b, da / (da - db)))
	return result
