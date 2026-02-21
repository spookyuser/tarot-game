class_name VignetteEffect
extends ColorRect

var _tween: Tween = null


func fade_in() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(material, "shader_parameter/intensity", 0.7, 0.4)


func fade_out() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(material, "shader_parameter/intensity", 0.0, 0.3)


func reset() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	material.set_shader_parameter("intensity", 0.0)
