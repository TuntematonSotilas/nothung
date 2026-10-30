class_name CardFrameBand
extends Control

## Double border of spells, artifacts and relics, drawn inside the card's own (outer) border: an inner
## line and, between the two, a motif that tells the type — zigzag (spell), diagonal hatching
## (artifact), beads (relic). Units have no band. See docs/functional/08-art-and-audio.md#card-frames.

enum Pattern { ZIGZAG, HATCH, BEADS }

## Band width (outer edge of the card to the inner edge of the inner line), at hand size.
const WIDTH: float = 16.0
const INNER_LINE: float = 3.0
## Motif period and line thickness, at hand size.
const PITCH: float = 8.0
const MOTIF_LINE: float = 1.5

var pattern: Pattern = Pattern.HATCH
var color: Color = Color.WHITE
## Card scale (CardView._face_k).
var k: float = 1.0
## Thickness of the card's own border (the outer line).
var outer_line: float = 3.0


static func pattern_for(data: CardData) -> Pattern:
	if data.is_relic():
		return Pattern.BEADS
	return Pattern.ZIGZAG if data.type == CardData.Type.SPELL else Pattern.HATCH


func _draw() -> void:
	var band: float = WIDTH * k
	var inner: float = maxf(1.0, roundf(INNER_LINE * k))
	var line: float = maxf(1.0, MOTIF_LINE * k)
	var pitch: float = PITCH * k
	var w: float = size.x
	var h: float = size.y
	var inset: float = band - inner / 2.0
	draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), color, false, inner, true)
	# The motif lives between the outer line (a) and the inner line (b).
	var a: float = outer_line
	var b: float = band - inner
	if pattern == Pattern.HATCH:
		# Global diagonals x + y = c, clipped to the four strips of the ring, so the corners line up.
		var strips: Array[Rect2] = [
			Rect2(a, a, w - 2.0 * a, b - a),
			Rect2(a, h - b, w - 2.0 * a, b - a),
			Rect2(a, b, b - a, h - 2.0 * b),
			Rect2(w - b, b, b - a, h - 2.0 * b),
		]
		var reach: float = w + h
		var c: float = 0.0
		while c <= reach:
			for strip: Rect2 in strips:
				_clipped_line(Vector2(c, 0.0), Vector2(0.0, c), strip, line)
			c += pitch
		return
	var mid: float = (a + b) / 2.0
	var half: float = (b - a) / 2.0
	for side: Array in [
		[Vector2(b, mid), Vector2(w - b, mid)],
		[Vector2(b, h - mid), Vector2(w - b, h - mid)],
		[Vector2(mid, b), Vector2(mid, h - b)],
		[Vector2(w - mid, b), Vector2(w - mid, h - b)],
	]:
		_side_motif(side[0], side[1], half, pitch, line)
	# A small diamond in each corner square.
	var r: float = half * 0.7
	for corner: Vector2 in [Vector2(mid, mid), Vector2(w - mid, mid), Vector2(mid, h - mid), Vector2(w - mid, h - mid)]:
		draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -r), corner + Vector2(r, 0), corner + Vector2(0, r), corner + Vector2(-r, 0)]), color)


## Zigzag or beads along one side, centred in the band (`half` = half its height).
func _side_motif(from: Vector2, to: Vector2, half: float, pitch: float, line: float) -> void:
	var length: float = from.distance_to(to)
	var direction: Vector2 = (to - from) / length
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var count: int = maxi(1, roundi(length / pitch))
	var step: float = length / count
	if pattern == Pattern.BEADS:
		for i: int in count:
			draw_circle(from + direction * step * (i + 0.5), half * 0.42, color, true, -1.0, true)
		return
	var amplitude: float = half - line
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in count + 1:
		points.append(from + direction * step * i + normal * (amplitude if i % 2 == 0 else -amplitude))
	draw_polyline(points, color, line, true)


## Draws the part of the segment p0→p1 inside `rect` (Liang–Barsky clipping).
func _clipped_line(p0: Vector2, p1: Vector2, rect: Rect2, line: float) -> void:
	var d: Vector2 = p1 - p0
	var t0: float = 0.0
	var t1: float = 1.0
	for edge: Vector2 in [
		Vector2(-d.x, p0.x - rect.position.x), Vector2(d.x, rect.end.x - p0.x),
		Vector2(-d.y, p0.y - rect.position.y), Vector2(d.y, rect.end.y - p0.y),
	]:
		if is_zero_approx(edge.x):
			if edge.y < 0.0:
				return
			continue
		var t: float = edge.y / edge.x
		if edge.x < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
	if t0 < t1:
		draw_line(p0 + d * t0, p0 + d * t1, color, line, true)
