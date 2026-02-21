extends Node2D

@export var star_count := 200
@export var min_speed := 10.0
@export var max_speed := 60.0
@export var star_colors := [
	Color.WHITE,
	Color(0.8, 0.8, 1.0),
	Color(1.0, 0.9, 0.7)
]

var stars := []
var screen_size : Vector2

func _ready():
	screen_size = get_viewport_rect().size
	randomize()

	for i in star_count:
		stars.append(_make_star())

func _make_star() -> Dictionary:
	return {
		"pos": Vector2(
			randi_range(0, screen_size.x),
			randi_range(0, screen_size.y)
		),
		"speed": randf_range(min_speed, max_speed),
		"color": star_colors.pick_random()
	}

func _process(delta):
	for star in stars:
		star.pos.y += star.speed * delta
		if star.pos.y >= screen_size.y:
			star.pos.y = 0
			star.pos.x = randi_range(0, screen_size.x)

	queue_redraw()

func _draw():
	for star in stars:
		draw_rect(
			Rect2(star.pos.floor(), Vector2.ONE),
			star.color
		)
