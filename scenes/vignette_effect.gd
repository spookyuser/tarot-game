class_name VignetteEffect
extends ColorRect

var _tween: Tween = null
var _spotlight_tween: Tween = null


func fade_in() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_shader_material(), "shader_parameter/intensity", 0.7, 0.4)


func fade_out() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_shader_material(), "shader_parameter/intensity", 0.0, 0.3)


func reset() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	if _spotlight_tween != null and _spotlight_tween.is_running():
		_spotlight_tween.kill()
	var shader_mat := _shader_material()
	shader_mat.set_shader_parameter("intensity", 0.0)
	shader_mat.set_shader_parameter("spotlight_enabled", false)
	shader_mat.set_shader_parameter("spotlight_strength", 0.0)


func focus_control(target: Control, padding: float = 56.0) -> void:
	if target == null:
		return
	var spotlight: Dictionary = _target_spotlight(target, padding)
	var center: Vector2 = spotlight.get("center", target.get_global_rect().position + target.get_global_rect().size * 0.5)
	var radius: float = float(spotlight.get("radius", (target.get_global_rect().size.length() * 0.5) + padding))
	set_spotlight(center, radius)


func set_spotlight(center_px: Vector2, radius_px: float, strength: float = 0.88, feather_px: float = 120.0) -> void:
	var shader_mat := _shader_material()
	shader_mat.set_shader_parameter("spotlight_enabled", true)
	shader_mat.set_shader_parameter("viewport_size", get_viewport_rect().size)
	shader_mat.set_shader_parameter("spotlight_center_px", center_px)
	shader_mat.set_shader_parameter("spotlight_radius_px", maxf(radius_px, 1.0))
	shader_mat.set_shader_parameter("spotlight_feather_px", maxf(feather_px, 1.0))
	shader_mat.set_shader_parameter("spotlight_strength", clampf(strength, 0.0, 1.0))


func clear_spotlight() -> void:
	_shader_material().set_shader_parameter("spotlight_enabled", false)


func fade_spotlight_to_control(
	target: Control,
	padding: float = 56.0,
	duration: float = 0.26,
	strength: float = 0.88,
	feather_px: float = 136.0
) -> void:
	if target == null:
		return

	var spotlight: Dictionary = _target_spotlight(target, padding)
	var center: Vector2 = spotlight.get("center", target.get_global_rect().position + target.get_global_rect().size * 0.5)
	var radius: float = float(spotlight.get("radius", (target.get_global_rect().size.length() * 0.5) + padding))
	var shader_mat := _shader_material()
	var was_enabled: bool = shader_mat.get_shader_parameter("spotlight_enabled") == true
	shader_mat.set_shader_parameter("spotlight_enabled", true)
	shader_mat.set_shader_parameter("viewport_size", get_viewport_rect().size)
	if not was_enabled:
		shader_mat.set_shader_parameter("spotlight_strength", 0.0)
		shader_mat.set_shader_parameter("spotlight_center_px", center)
		shader_mat.set_shader_parameter("spotlight_radius_px", maxf(radius, 1.0))
		shader_mat.set_shader_parameter("spotlight_feather_px", maxf(feather_px, 1.0))

	if _spotlight_tween != null and _spotlight_tween.is_running():
		_spotlight_tween.kill()

	_spotlight_tween = create_tween()
	_spotlight_tween.set_parallel(true)
	_spotlight_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_spotlight_tween.tween_property(shader_mat, "shader_parameter/spotlight_center_px", center, duration)
	_spotlight_tween.tween_property(shader_mat, "shader_parameter/spotlight_radius_px", maxf(radius, 1.0), duration)
	_spotlight_tween.tween_property(shader_mat, "shader_parameter/spotlight_feather_px", maxf(feather_px, 1.0), duration)
	_spotlight_tween.tween_property(shader_mat, "shader_parameter/spotlight_strength", clampf(strength, 0.0, 1.0), duration)


func fade_out_spotlight(duration: float = 0.18) -> void:
	var shader_mat := _shader_material()
	if _spotlight_tween != null and _spotlight_tween.is_running():
		_spotlight_tween.kill()
	if shader_mat.get_shader_parameter("spotlight_enabled") != true:
		return

	_spotlight_tween = create_tween()
	_spotlight_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_spotlight_tween.tween_property(shader_mat, "shader_parameter/spotlight_strength", 0.0, duration)
	_spotlight_tween.tween_callback(clear_spotlight)


func _shader_material() -> ShaderMaterial:
	if material is ShaderMaterial:
		return material as ShaderMaterial
	push_warning("VignetteEffect requires a ShaderMaterial.")
	return ShaderMaterial.new()


func _target_spotlight(target: Control, padding: float) -> Dictionary:
	# Card visuals are driven by card_size, so use it for true visual center/radius.
	if target is Card:
		var card := target as Card
		var card_size: Vector2 = card.card_size
		if card_size == Vector2.ZERO:
			card_size = card.get_global_rect().size
		var card_center: Vector2 = card.global_position + card_size * 0.5
		var card_radius: float = (maxf(card_size.x, card_size.y) * 0.68) + padding
		return {
			"center": card_center,
			"radius": card_radius,
		}

	var rect: Rect2 = target.get_global_rect()
	return {
		"center": rect.position + rect.size * 0.5,
		"radius": (rect.size.length() * 0.5) + padding,
	}
